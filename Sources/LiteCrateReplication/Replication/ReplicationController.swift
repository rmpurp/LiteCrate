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
  
  var replicatingTables = [any ReplicatingModel]()
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
  
  func filter<T>(model: T) throws -> Bool where T : DatabaseCodable {
    guard let model = model as? any ReplicatingModel else { return true }
    return !model.dot.isDeleted
  }
  
  func migration(didInitializeIn proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute("CREATE TABLE Node (id TEXT PRIMARY KEY, time INT NOT NULL, minTime INT NOT NULL)")
    try proxy.execute("INSERT INTO Node VALUES (?, 0, 0)", [nodeID])
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
  
  func transactionDidEnd() {
    needToIncrementTime = false
  }
  
  func transaction(willCommitIn proxy: LiteCrate.TransactionProxy) throws {
    if needToIncrementTime {
      try proxy.execute("UPDATE Node SET time = time + 1 WHERE id = ?", [nodeID])
    }
  }
  
  func proxy<T>(_ proxy: LiteCrate.TransactionProxy, willSave model: T) throws -> T where T : DatabaseCodable {
    if var model = model as? any ReplicatingModel {
      if !model.dot.isDeleted {
        try model.deleteCompetingModels(proxy, time: time, node: nodeID)
      }
      needToIncrementTime = true
      model.dot.update(modifiedBy: nodeID, at: time)
      
      return model as! T
    }
    return model
  }
  
  func proxy<T: DatabaseCodable>(_ proxy: LiteCrate.TransactionProxy, willDelete model: T) throws -> T? {
    if var model = model as? (any ReplicatingModel) {
      model.dot.delete(modifiedBy: nodeID, at: time)
      needToIncrementTime = true
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
  
  func encode(clocks: [Node]) throws -> ReplicationPayload {
    var models = [String: [any ReplicatingModel]]()
    var localNodes = [Node]()
    try inTransaction { [unowned self] proxy in
      localNodes.append(contentsOf: try proxy.fetch(Node.self))
      let nodesForFetching = Node.mergeForEncoding(localNodes: localNodes, remoteNodes: clocks)
      
      for exampleInstance in replicatingTables {
        models[exampleInstance.tableName] = try fetch(instance: exampleInstance, proxy: proxy, nodes: nodesForFetching)
      }
    }
    return ReplicationPayload(models: models, nodes: localNodes)
  }
  
  func merge(_ payload: ReplicationPayload) throws {
    try inTransaction { [unowned self] localProxy in
      for instance in replicatingTables {
        try merge(model: instance, nodeID: nodeID, time: time, localProxy: localProxy, payload: payload)
      }
      
      let localNodes = try localProxy.fetch(Node.self)
      for node in Node.mergeForDecoding(nodeID: nodeID, localNodes: localNodes, remoteNodes: payload.nodes) {
        try localProxy.saveIgnoringDelegate(node)
      }
    }
  }
  
  /// If it exists, get the dot corresponding to the model with the same id and not null.
  func getActiveWithSameID<T: ReplicatingModel>(proxy: LiteCrate.TransactionProxy, model: T) throws -> T? {
    return try proxy.fetchIgnoringDelegate(T.self, allWhere: "timeLastModified IS NOT NULL AND id = ?", [model.dot.id]).first
  }
  
  func getWithSameVersion<T: ReplicatingModel>(proxy: LiteCrate.TransactionProxy, model: T) throws -> T? {
    return try proxy.fetchIgnoringDelegate(T.self, with: model.dot.version)
  }
  
  func knownToHaveBeenDeleted(localNodes: [UUID: Node], dot: Dot) -> Bool {
    if let creator = localNodes[dot.creator] {
      return dot.timeCreated < creator.minTime
    }
    
    return false
  }
  
  
  private func merge<T: ReplicatingModel>(model: T,
                                          nodeID: UUID,
                                          time: Int64,
                                          localProxy: LiteCrate.TransactionProxy,
                                          payload: ReplicationPayload) throws {
    
    let nodes = try localProxy.fetchIgnoringDelegate(Node.self)
    let nodeDict = [UUID: Node](uniqueKeysWithValues: nodes.lazy.map { ($0.id, $0) })
    
    let remoteModels = payload.models[T.tableName]! // TODO: Throw error.
    
    for remoteModel in remoteModels {
      if let localWitness = nodeDict[remoteModel.dot.witness],
         localWitness.minTime > remoteModel.dot.timeLastWitnessed {
        // This has been deleted.
        continue
      }
      
      // If exact version exists locally, replace with remote model iff remote is newer.
      //    Recall that deletions are always "newer"
      if let sameVersionLocalModel = try getWithSameVersion(proxy: localProxy, model: remoteModel) {
        if sameVersionLocalModel.dot < remoteModel.dot {
          try localProxy.saveIgnoringDelegate(remoteModel)
        }
        continue
      }
      
      
      // Get the version created most recently and delete competing versions.
      guard let localModel = try getActiveWithSameID(proxy: localProxy, model: remoteModel) else {
        // TODO: If local dot does not exist, but we "would have known about it", then
        // consider it deleted.
        if !knownToHaveBeenDeleted(localNodes: nodeDict, dot: remoteModel.dot) {
          try localProxy.saveIgnoringDelegate(remoteModel)
        }
        
        continue
      }
      
      // This is a new version.
      try localProxy.saveIgnoringDelegate(remoteModel)
      
      
      if localModel.dot < remoteModel.dot {
        try remoteModel.deleteCompetingModels(localProxy, time: time, node: nodeID)
      } else {
        try localModel.deleteCompetingModels(localProxy, time: time, node: nodeID)
      }
    }
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
        SET timeLastModified = NULL,
            lastModifier = NULL,
            timeLastWitnessed = ?,
            witness = ?
        WHERE id = ? AND version <> ?
    """
    try proxy.execute(query, [time, node, dot.id, dot.version])
  }
}
