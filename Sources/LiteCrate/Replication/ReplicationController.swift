//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrateCore

class ReplicationController: LiteCrateDelegate {
  private var liteCrate: LiteCrate!

  var tables = [String: any ReplicatingModel.Type]()
  var nodeID: UUID
  var time: Int64!
  var transactionTime: Int64!

  var userInfo: [CodingUserInfoKey: Any] {
    [.init(rawValue: "tables")!: tables]
  }

  init(location: String, nodeID: UUID, @MigrationBuilder migrations: () -> Migration) throws {
    self.nodeID = nodeID
    liteCrate = try LiteCrate(location, delegate: self, migrations: migrations)
  }

  @discardableResult
  public func inTransaction<T>(block: @escaping (TransactionProxy) throws -> T) throws -> T {
    try liteCrate.inTransaction(block: block)
  }

  func migration(didInitializeIn proxy: TransactionProxy) throws {
    try proxy.execute("CREATE TABLE Node (id TEXT PRIMARY KEY, time INT NOT NULL, minTime INT NOT NULL)")
    try proxy
      .execute(SchemaEncoder(EmptyRange.exampleInstance).creationStatement)
    try proxy.execute("INSERT INTO Node VALUES (?, 0, 0)", [nodeID])
  }

  func migration<A>(willRun action: A) where A: MigrationAction {
    if let action = action as? ReplicatingTableMigrationAction {
      action.modifyReplicatingTables(&tables)
    }
  }

  func transaction(didBeginIn proxy: TransactionProxy) throws {
    try proxy.execute("PRAGMA defer_foreign_keys = TRUE")
    let cursor = try proxy.query("SELECT time FROM Node WHERE id = ?", [nodeID])
    guard cursor.step() else { fatalError("Corrupt database.") }
    time = cursor.int(for: 0)
    transactionTime = time
  }

  func transaction(willCommitIn proxy: TransactionProxy) throws {
    try proxy.execute("UPDATE Node SET time = ? WHERE id = ?", [time, nodeID])
  }

  class ForeignKeyDotCollector<T: ReplicatingModel>: ForeignKeyVisitor {
    private let proxy: TransactionProxy
    var dots = [ForeignKeyDot]()
    var model: T

    init(_ proxy: TransactionProxy, model: T) {
      self.proxy = proxy
      self.model = model
      self.model.foreignKeyConstraints.visit(by: self)
    }

    func visit<Destination: DatabaseCodable>(_ element: ForeignKey<T, Destination>) {
      // TODO: Error handling
      let cursor = try! proxy.query(
        "SELECT creator, createdTime FROM \(Destination.exampleInstance.tableName) WHERE \(Destination.primaryKeyColumn) = ?",
        [element.path(model)]
      )
      guard cursor.step() else { fatalError() }

      let creator = cursor.uuid(for: 0)
      let createdTime = cursor.int(for: 1)

      dots.append(.init(parentCreator: creator, parentCreatedTime: createdTime, prefix: element.columnName))
    }
  }

  private func handleReplicatingModel<T: ReplicatingModel>(_ proxy: TransactionProxy,
                                                           model: T) throws -> any DatabaseCodable
  {
    var dot = model.dot
    dot.update(modifiedBy: nodeID, at: time, transactionTime: transactionTime)
    time += 1
    let collector = ForeignKeyDotCollector(proxy, model: model)
    return model.toErasedModelDot(dot: dot, fkDots: collector.dots)
  }

  func proxy<T: DatabaseCodable>(_ proxy: TransactionProxy, willSave model: T) throws -> any DatabaseCodable {
    if let model = model as? any ReplicatingModel {
      return try handleReplicatingModel(proxy, model: model)
    }
    return model
  }

  func proxy<T: DatabaseCodable>(_ proxy: TransactionProxy,
                                 willDelete model: T) throws -> (any DatabaseCodable)?
  {
    if let model = model as? (any ReplicatingModel) {
      let emptyRange = EmptyRange(
        node: model.dot.creator,
        start: model.dot.createdTime,
        end: model.dot.createdTime,
        lastModifier: nodeID,
        sequenceNumber: transactionTime
      )

      // This will delete the model, so the transactionProxy won't need to do any work after this.
      try addAndMerge(proxy, range: emptyRange, deleteModels: model.isParent)

      // Deletions increment time, which necessitates adding an EmptyRange at the old time.
      let placeholderRange = EmptyRange(
        node: nodeID,
        start: time,
        end: time,
        lastModifier: nodeID,
        sequenceNumber: transactionTime
      )
      try addAndMerge(proxy, range: placeholderRange)

      time += 1
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

extension ReplicationController {
  func addAndMerge(_ proxy: TransactionProxy, range: EmptyRange, deleteModels: Bool = false) throws {
    var range = range
    let conflictingRanges = try proxy.fetch(
      EmptyRange.self,
      allWhere: "node = ? AND start <= ? AND end >= ?",
      [range.node, range.end + 1, range.start - 1]
    )

    for conflictingRange in conflictingRanges {
      range.start = min(range.start, conflictingRange.start)
      range.end = max(range.end, conflictingRange.end)
      try proxy.deleteIgnoringDelegate(conflictingRange)
    }

    if deleteModels {
      for table in tables.values {
        try deleteAll(proxy, type: table, in: range)
      }
    }
    try proxy.save(range)
  }

  private func deleteAll<T: ReplicatingModel>(_ proxy: TransactionProxy, type _: T.Type,
                                              in range: EmptyRange) throws
  {
    for fkDot in ModelDotPair<T>.exampleInstance.foreignKeyDots {
      let childModels = try proxy.fetch(
        T.self,
        allWhere: "\(fkDot.prefix)Creator = ? AND ? <= \(fkDot.prefix)CreatedTime AND \(fkDot.prefix)CreatedTime <= ?",
        [range.node, range.start, range.end]
      )

      for model in childModels {
        try proxy.delete(model) // Actual delete so we mark the child dot as deleted.
      }
    }

    let models = try proxy.fetch(
      T.self,
      allWhere: "creator = ? AND ? <= createdTime AND createdTime <= ?",
      [range.node, range.start, range.end]
    )

    for model in models {
      // TODO: Recursive foreign keys?
      try proxy.deleteIgnoringDelegate(model)
    }
  }
}
