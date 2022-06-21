//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrate

struct TableNameCodingKey: CodingKey {
  var stringValue: String
  
  init(stringValue: String) {
    self.stringValue = stringValue
  }
  
  var intValue: Int?
  
  init?(intValue: Int) {
    return nil
  }
}

public class ReplicatingTable: Hashable {
  let tableName: String
  
  init(tableName: String) {
    self.tableName = tableName
  }
  
  var codingKey: TableNameCodingKey {
    .init(stringValue: tableName)
  }
  
public static func == (lhs: ReplicatingTable, rhs: ReplicatingTable) -> Bool {
    return lhs.tableName == rhs.tableName
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(tableName)
  }

  
  func merge(nodeID: UUID, time: Int64, localProxy: LiteCrate.TransactionProxy, remoteProxy: LiteCrate.TransactionProxy) throws {
    fatalError("Abstract Method")
  }
}

// TODO Change DatabaseCodable
class ReplicatingTableImpl<T: ReplicatingModel>: ReplicatingTable {
  init(_ instance: T) {
    super.init(tableName: T.tableName)
  }
  
  /// If it exists, get the dot corresponding to the model with the same id and not null.
  func getActiveWithSameID(proxy: LiteCrate.TransactionProxy, dot: Dot) throws -> T? {
    return try proxy.fetchIgnoringDelegate(T.self, allWhere: "timeLastModified IS NOT NULL AND id = ?", [dot.id]).first
  }
  
  func getWithSameVersion(proxy: LiteCrate.TransactionProxy, dot: Dot) throws -> T? {
    return try proxy.fetchIgnoringDelegate(T.self, with: dot.version)
  }
  
  func knownToHaveBeenDeleted(localNodes: [UUID: Node], dot: Dot) -> Bool {
    if let creator = localNodes[dot.creator] {
      return dot.timeCreated < creator.minTime
    }
    
    return false
  }
  
  
  override func merge(nodeID: UUID, time: Int64, localProxy: LiteCrate.TransactionProxy, remoteProxy: LiteCrate.TransactionProxy) throws {
    let nodes = try localProxy.fetchIgnoringDelegate(Node.self)
    let nodeDict = [UUID: Node](uniqueKeysWithValues: nodes.lazy.map { ($0.id, $0) })

    let remoteModels = try remoteProxy.fetchIgnoringDelegate(T.self)
    for remoteModel in remoteModels {
      if let localWitness = nodeDict[remoteModel.dot.witness],
         localWitness.minTime > remoteModel.dot.timeLastWitnessed {
        // This has been deleted.
        continue
      }

      // If exact version exists locally, replace with remote model iff remote is newer.
      //    Recall that deletions are always "newer"
      if let sameVersionLocalModel = try getWithSameVersion(proxy: localProxy, dot: remoteModel.dot) {
        if sameVersionLocalModel.dot < remoteModel.dot {
          try localProxy.saveIgnoringDelegate(remoteModel)
        }
        continue
      }


      // Get the version created most recently and delete competing versions.
      guard let localModel = try getActiveWithSameID(proxy: localProxy, dot: remoteModel.dot) else {
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

extension ReplicatingModel {
  func replicatingTable() -> ReplicatingTable {
    return ReplicatingTableImpl(self)
  }
}
