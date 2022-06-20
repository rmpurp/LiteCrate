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
  
  func merge(localProxy: LiteCrate.TransactionProxy, remoteProxy: LiteCrate.TransactionProxy) throws {
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
      models.append(contentsOf: try proxy.fetch(
        T.self,
        allWhere: "witness = ? AND timeLastWitnessed >= ?",
        [node.id, node.time])
      )
    }
    return models
  }
  
  /// If it exists, get the dot corresponding to the model with the same id and not null.
  func getCorrespondingDot(proxy: LiteCrate.TransactionProxy, dot: Dot) throws -> Dot? {
    if let localExactVersion = try proxy.fetch(T.self, with: dot.version) {
      return localExactVersion.dot
    } else if let activeLocalVersion = try proxy.fetch(T.self, allWhere: "timeLastModified IS NOT NULL AND id = ?", [dot.id]).first {
      return activeLocalVersion.dot
    }
    return nil
  }
  
  
  override func merge(localProxy: LiteCrate.TransactionProxy, remoteProxy: LiteCrate.TransactionProxy) throws {
    let nodes = try localProxy.fetch(Node.self)
    let nodeDict = [UUID: Node](uniqueKeysWithValues: nodes.lazy.map { ($0.id, $0) })

    let remoteModels = try remoteProxy.fetch(T.self)
    for remoteModel in remoteModels {
      if let localWitness = nodeDict[remoteModel.dot.witness],
         localWitness.minTime > remoteModel.dot.timeLastWitnessed {
        // This has been deleted.
        continue
      }
      
      guard let localDot = try getCorrespondingDot(proxy: localProxy, dot: remoteModel.dot) else {
        try localProxy.save(remoteModel)
        continue
      }
      
      if localDot < remoteModel.dot {
        try localProxy.save(remoteModel)
      }
    }
  }
}
