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
  
  func fetch(proxy: LiteCrate.TransactionProxy, mergedNodes: [Node]) throws -> any Codable {
    fatalError("Abstract Method")
  }
  
  func populate(proxy: LiteCrate.TransactionProxy, decodingContainer: KeyedDecodingContainer<TableNameCodingKey>) throws {
    fatalError("Abstract Method")
  }
  
  func merge(nodeID: UUID, time: Int64, localProxy: LiteCrate.TransactionProxy, remoteProxy: LiteCrate.TransactionProxy) throws {
    fatalError("Abstract Method")
  }
}

// TODO Change DatabaseCodable
class ReplicatingTableImpl<T: ReplicatingModel>: ReplicatingTable {
  init(_ type: T.Type) {
    super.init(tableName: T.tableName)
  }
  
  override func populate(proxy: LiteCrate.TransactionProxy, decodingContainer: KeyedDecodingContainer<TableNameCodingKey>) throws {
    let instances = try decodingContainer.decode([T].self, forKey: codingKey)
    for instance in instances {
      try proxy.saveIgnoringDelegate(instance)
    }
  }
  
  override func fetch(proxy: LiteCrate.TransactionProxy, mergedNodes: [Node]) throws -> any Codable {
    var models = [T]()
    for node in mergedNodes {
      models.append(contentsOf: try proxy.fetchIgnoringDelegate(
        T.self,
        allWhere: "witness = ? AND timeLastWitnessed >= ?",
        [node.id, node.time])
      )
    }
    return models
  }
  
  /// If it exists, get the dot corresponding to the model with the same id and not null.
  func getActiveWithSameID(proxy: LiteCrate.TransactionProxy, dot: Dot) throws -> T? {
    return try proxy.fetch(T.self, allWhere: "timeLastModified IS NOT NULL AND id = ?", [dot.id]).first
  }
  
  func getWithSameVersion(proxy: LiteCrate.TransactionProxy, dot: Dot) throws -> T? {
    return try proxy.fetch(T.self, with: dot.version)
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
      
      // If new version, just insert it.
      // If existing version, replace with remote model if remote is newer.
      // Get the version created most recently and delete competing versions.
      guard let localModel = try getActiveWithSameID(proxy: localProxy, dot: remoteModel.dot) else {
        try localProxy.saveIgnoringDelegate(remoteModel)
        continue
      }
      
      if let sameVersionLocalModel = try getWithSameVersion(proxy: localProxy, dot: remoteModel.dot) {
        if sameVersionLocalModel.dot < remoteModel.dot {
          try localProxy.saveIgnoringDelegate(remoteModel)
        }
      } else {
        // LocalModel with different id exists, but this is a new version.
        try localProxy.saveIgnoringDelegate(remoteModel)
      }
      
      if localModel.dot < remoteModel.dot {
        try remoteModel.deleteCompetingModels(localProxy, time: time, node: nodeID)
      } else {
        try localModel.deleteCompetingModels(localProxy, time: time, node: nodeID)
      }
    }
  }
}
