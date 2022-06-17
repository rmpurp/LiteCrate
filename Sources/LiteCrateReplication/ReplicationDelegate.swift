//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrate

class ReplicationDelegate: LiteCrateDelegate {
  private var needToIncrementTime = false
  var replicatingTables = Set<ReplicatingTable>()
  var nodeID: UUID
  var time: Int64!
  
  init(nodeID: UUID) {
    self.nodeID = nodeID
  }
  
  func migrationDidInitialize(_ proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute("CREATE TABLE Node(id TEXT PRIMARY KEY, time INT NOT NULL)")
    try proxy.execute("INSERT INTO Node VALUES (?, ?)", [nodeID, 0])
  }
  
  func migrationActionWillRun<A>(_ action: A) where A : MigrationAction {
    if let action = action as? ReplicatingTableMigrationAction {
      action.modifyReplicatingTables(&replicatingTables)
    }
  }
  
  func transactionDidBegin(_ proxy: LiteCrate.TransactionProxy) throws {
    needToIncrementTime = false
    let cursor = try proxy.query("SELECT time FROM Node WHERE id = ?", [nodeID])
    guard cursor.step() else { fatalError("Corrupt database.") }
    time = cursor.int(for: 0)
  }
  
  func transactionWillCommit(_ proxy: LiteCrate.TransactionProxy) throws {
    
  }
  
  func model<T>(_ model: T, willSaveIn proxy: LiteCrate.TransactionProxy) throws where T : DatabaseCodable {
    if let model = model as? (any ReplicatingModel) {
      needToIncrementTime = true
      try updateDotForSave(model, in: proxy)
    }
  }
  
  private func updateDotForSave<T: ReplicatingModel>(_ model: T, in proxy: LiteCrate.TransactionProxy) throws {
    if var dot = try proxy.fetch(Dot<T>.self,
                                 allWhere: "modelID = ? AND timeLastModified IS NOT NULL",
                                 [model.primaryKeyValue]).first {
      
      dot.timeLastModified = time
      dot.lastModifier = nodeID
      dot.timeLastWitnessed = time
      dot.witness = nodeID
      try proxy.save(dot)
    } else {
      let dot = Dot<T>(modelID: model.primaryKeyValue, time: time, creator: nodeID)
      try proxy.save(dot)
    }
  }
  
  
  private func updateDotForDelete<T: ReplicatingModel>(_ model: T, in proxy: LiteCrate.TransactionProxy) throws {
    needToIncrementTime = true
    if var dot = try proxy.fetch(Dot<T>.self,
                                 allWhere: "modelID = ? ORDER BY timeCreated DESC LIMIT 1",
                                 [model.primaryKeyValue]).first {
      dot.timeLastModified = nil
      dot.lastModifier = nil
      dot.timeLastWitnessed = time
      dot.witness = nodeID
      try proxy.save(dot)
    } else {
      let dot = Dot<T>(modelID: model.primaryKeyValue, time: time, creator: nodeID)
      try proxy.save(dot)
    }
  }
  
  func model<T>(_ model: T, willDeleteIn proxy: LiteCrate.TransactionProxy) throws where T : DatabaseCodable {
    if let model = model as? any ReplicatingModel {
      try updateDotForDelete(model, in: proxy)
    }
  }
  
}
