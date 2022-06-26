//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrate
import LiteCrateCore

class ReplicationController: LiteCrateDelegate {
  private var liteCrate: LiteCrate!

  var exampleInstances = [any ReplicatingModel]()
  var nodeID: UUID
  var transactionTime: Int64!
  var time: Int64!

  var userInfo: [CodingUserInfoKey: Any] {
    [.init(rawValue: "instances")!: exampleInstances]
  }

  init(location: String, nodeID: UUID, @MigrationBuilder migrations: () -> Migration) throws {
    self.nodeID = nodeID
    liteCrate = try LiteCrate(location, delegate: self, migrations: migrations)
  }

  @discardableResult
  public func inTransaction<T>(block: @escaping (LiteCrate.TransactionProxy) throws -> T) throws -> T {
    try liteCrate.inTransaction(block: block)
  }

  func migration(didInitializeIn proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute("CREATE TABLE Node (id TEXT PRIMARY KEY, time INT NOT NULL, minTime INT NOT NULL)")
    try proxy
      .execute(EmptyRange(node: UUID(), start: 0, end: 0, modifiedNode: UUID(), modifiedTime: 0).creationStatement)
    try proxy.execute("INSERT INTO Node VALUES (?, 0, 0)", [nodeID])
  }

  func migration<A>(willRun action: A) where A: MigrationAction {
    if let action = action as? ReplicatingTableMigrationAction {
      action.modifyReplicatingTables(&exampleInstances)
    }
  }

  func transaction(didBeginIn proxy: LiteCrate.TransactionProxy) throws {
    let cursor = try proxy.query("SELECT time FROM Node WHERE id = ?", [nodeID])
    guard cursor.step() else { fatalError("Corrupt database.") }
    time = cursor.int(for: 0)
    transactionTime = time
  }

  func transaction(willCommitIn proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute("UPDATE Node SET time = ? WHERE id = ?", [time, nodeID])
  }

  func proxy<T>(_ proxy: LiteCrate.TransactionProxy, willSave model: T) throws -> T where T: DatabaseCodable {
    if var model = model as? any ReplicatingModel {
      try model.deleteCompetingModels(proxy, time: time, node: nodeID)
      time += 1
      model.dot.update(modifiedBy: nodeID, at: time, transactionTime: transactionTime)

      return model as! T
    }
    return model
  }

  // MARK: - Range CRUD

  private func fetchOverlappingRanges(_ proxy: LiteCrate.TransactionProxy, range: EmptyRange) throws -> [EmptyRange] {
    try proxy.fetch(EmptyRange.self, allWhere: "start <= ? AND end >= ?", [range.end + 1, range.start - 1])
  }

  private func saveAndResolve(_ proxy: LiteCrate.TransactionProxy, range: EmptyRange) throws {
    var range = range
    for overlappingRange in try fetchOverlappingRanges(proxy, range: range) {
      range.start = min(range.start, overlappingRange.start)
      range.end = max(range.end, overlappingRange.end)
      try proxy.deleteIgnoringDelegate(overlappingRange)
    }
    try proxy.saveIgnoringDelegate(range)
  }

  func proxy<T: DatabaseCodable>(_ proxy: LiteCrate.TransactionProxy, willDelete model: T) throws -> T? {
    if let model = model as? (any ReplicatingModel) {
      let range = EmptyRange(
        node: model.dot.creator,
        start: model.dot.createdTime,
        end: model.dot.createdTime,
        modifiedNode: nodeID,
        modifiedTime: transactionTime
      )
      try saveAndResolve(proxy, range: range)
    }
    return nil
  }

  func clocks() throws -> [Node] {
    var clocks = [Node]()
    try inTransaction { proxy in
      clocks = try proxy.fetch(Node.self)
    }
    return clocks
  }
}

// Extension because generic sadness
extension ReplicatingModel {
  /// Delete models with the same id but a different version.
  /// time: the current time to update the time witnessed to
  /// node: the witness
  func deleteCompetingModels(_ proxy: LiteCrate.TransactionProxy, time: Int64, node: UUID) throws {
    // Avoid recursively calling delegate methods by updating rows directly
    let query = """
    UPDATE \(Self.tableName)
        SET modifiedTime = NULL,
            modifiedNode = NULL,
            witnessedTime = ?,
            witnessedNode = ?
        WHERE id = ? AND version <> ?
    """
    try proxy.execute(query, [time, node, dot.id, dot.version])
  }
}
