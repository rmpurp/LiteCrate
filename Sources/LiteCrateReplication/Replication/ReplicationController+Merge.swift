//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/22/22.
//

import Foundation
import LiteCrate

extension ReplicationController {
  public func payload(remoteNodes: [Node]) throws -> ReplicationPayload {
    var models = [String: [any ReplicatingModel]]()
    var localNodes = [Node]()
    try inTransaction { [unowned self] proxy in
      localNodes.append(contentsOf: try proxy.fetch(Node.self))
      let nodesForFetching = Node.mergeForEncoding(localNodes: localNodes, remoteNodes: remoteNodes)
      
      for exampleInstance in replicatingTables {
        models[exampleInstance.tableName] = try fetch(instance: exampleInstance, proxy: proxy, nodes: nodesForFetching)
      }
    }
    return ReplicationPayload(models: models, nodes: localNodes)
  }

  public func merge(_ payload: ReplicationPayload) throws {
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
  private func getActiveWithSameID<T: ReplicatingModel>(proxy: LiteCrate.TransactionProxy, model: T) throws -> T? {
    return try proxy.fetchIgnoringDelegate(T.self, allWhere: "timeLastModified IS NOT NULL AND id = ?", [model.dot.id]).first
  }
  
  private func getWithSameVersion<T: ReplicatingModel>(proxy: LiteCrate.TransactionProxy, model: T) throws -> T? {
    return try proxy.fetchIgnoringDelegate(T.self, with: model.dot.version)
  }
  
  private func knownToHaveBeenDeleted(localNodes: [UUID: Node], dot: Dot) -> Bool {
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
