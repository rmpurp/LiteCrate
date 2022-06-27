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
  var time: Int64!
  var transactionTime: Int64!

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

  func filter<T>(model: T) throws -> Bool where T: DatabaseCodable {
    guard let model = model as? any ReplicatingModel else { return true }
    return !model.dot.isDeleted
  }

  func migration(didInitializeIn proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute("CREATE TABLE Node (id TEXT PRIMARY KEY, time INT NOT NULL, minTime INT NOT NULL)")
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
      if !model.dot.isDeleted {
        try model.deleteCompetingModels(proxy, time: time, node: nodeID)
      }
      model.dot.update(modifiedBy: nodeID, at: time, transactionTime: transactionTime)
      time += 1
      return model as! T
    }
    return model
  }

  func proxy<T: DatabaseCodable>(_: LiteCrate.TransactionProxy, willDelete model: T) throws -> T? {
    if var model = model as? (any ReplicatingModel) {
      model.dot.delete(modifiedBy: nodeID, at: time, transactionTime: transactionTime)
      time += 1
      return (model as! T)
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
        SET isDeleted = TRUE,
            sequenceNumber = ?,
            lastModifier = ?
        WHERE id = ? AND version <> ?
    """
    try proxy.execute(query, [time, node, dot.id, dot.version])
  }
}
