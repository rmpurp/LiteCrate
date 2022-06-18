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
  private var liteCrate: LiteCrate! = nil
  private var needToIncrementTime = false
  var replicatingTables = Set<ReplicatingTable>()
  var nodeID: UUID
  var time: Int64!
  
  init(location: String, nodeID: UUID, @MigrationBuilder migrations: () -> Migration) throws {
    self.nodeID = nodeID
    self.liteCrate = try LiteCrate(location, delegate: self, migrations: migrations)
  }
  
  @discardableResult
  public func inTransaction<T>(block: @escaping (LiteCrate.TransactionProxy) throws -> T) throws -> T {
    return try liteCrate.inTransaction(block: block)
  }
  
  func migration(didInitializeIn proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute("CREATE TABLE Node (id TEXT PRIMARY KEY, time INT NOT NULL)")
    try proxy.execute("INSERT INTO Node VALUES (?, ?)", [nodeID, 0])
  }
  
  func migration<A>(willRun action: A) where A : MigrationAction {
    if let action = action as? ReplicatingTableMigrationAction {
      action.modifyReplicatingTables(&replicatingTables)
    }
  }
  
  func transaction(didBeginIn proxy: LiteCrate.TransactionProxy) throws {
    needToIncrementTime = false
    let cursor = try proxy.query("SELECT time FROM Node WHERE id = ?", [nodeID])
    guard cursor.step() else { fatalError("Corrupt database.") }
    time = cursor.int(for: 0)
  }
  
  func transaction(willCommitIn proxy: LiteCrate.TransactionProxy) throws {
    if needToIncrementTime {
      try proxy.execute("UPDATE Node SET time = time + 1 WHERE id = ?", [nodeID])
      needToIncrementTime = false
    }
  }
  
  func proxy<T>(_ proxy: LiteCrate.TransactionProxy, willSave model: T) throws -> T where T : DatabaseCodable {
    if var model = model as? (any ReplicatingModel) {
      needToIncrementTime = true
      model.dot.update(modifiedBy: nodeID, at: time)
    }
    return model
  }

  func proxy<T: DatabaseCodable>(_ proxy: LiteCrate.TransactionProxy, willDelete model: T) throws -> T? {
    if let model = model as? (any ReplicatingModel) {
      // TODO: Logic
//      try updateDot(in: proxy, deleting: model)
    }
    return nil
  }
  
//  private func updateDot<T: ReplicatingModel>(in proxy: LiteCrate.TransactionProxy, deleting model: T) throws {
//    needToIncrementTime = true
//    if var dot = try proxy.fetch(Dot<T>.self,
//                                 allWhere: "modelID = ? ORDER BY timeCreated DESC LIMIT 1",
//                                 [model.primaryKeyValue]).first {
//      dot.timeLastModified = nil
//      dot.lastModifier = nil
//      dot.timeLastWitnessed = time
//      dot.witness = nodeID
//      try proxy.save(dot)
//    } else {
//      let dot = Dot<T>(modelID: model.primaryKeyValue, time: time, creator: nodeID)
//      try proxy.save(dot)
//    }
//  }
  
  func encode(clocks: [Node]) throws -> String {
    let encoder = JSONEncoder()
    encoder.userInfo[CodingUserInfoKey(rawValue: "replicator")!] = self
    return try String(data: encoder.encode(CodableProxy()), encoding: .utf8)!
  }
  
  func decode(from json: String) throws {
    let decoder = JSONDecoder()
    decoder.userInfo[CodingUserInfoKey(rawValue: "replicator")!] = self
    _ = try decoder.decode(CodableProxy.self, from: json.data(using: .utf8)!)
  }
}
