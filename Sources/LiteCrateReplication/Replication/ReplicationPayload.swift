//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/17/22.
//

import Foundation 
import LiteCrate

class ReplicationPayload: Codable {
  var models = [String: [any ReplicatingModel]]()
  var nodes = [Node]()
  
  init(models: [String: [any ReplicatingModel]], nodes: [Node]) {
    self.models = models
    self.nodes = nodes
  }
  
  required init(from decoder: Decoder) throws {
    guard let replicator = decoder.userInfo[CodingUserInfoKey(rawValue: "replicator")!] as? ReplicationController else {
      preconditionFailure()
    }
    
    let container = try decoder.container(keyedBy: TableNameCodingKey.self)
    
    try replicator.inTransaction { proxy in
      for instance in replicator.replicatingTables {
        try populate(instance: instance, proxy: proxy, container: container)
      }
      
      let localNodes = try proxy.fetch(Node.self)
      let nodes = try container.decode([Node].self, forKey: .init(stringValue: Node.tableName))
      let mergedNodes = Node.mergeForDecoding(nodeID: replicator.nodeID,
                                              localNodes: localNodes,
                                              remoteNodes: nodes)
      for node in mergedNodes {
        try proxy.save(node)
      }
    }
  }
  
  func encode2(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TableNameCodingKey.self)
    for (tableName, instances) in models {
      var arrayContainer = container.nestedUnkeyedContainer(forKey: .init(stringValue: tableName))
      for instance in instances {
        try arrayContainer.encode(instance)
      }
    }
    try container.encode(nodes, forKey: .init(stringValue: Node.tableName))
  }

  
  func encode(to encoder: Encoder) throws {
    guard let db = encoder.userInfo[CodingUserInfoKey(rawValue: "replicator")!] as? ReplicationController else {
      preconditionFailure()
    }
    
    guard let remoteNodes = encoder.userInfo[CodingUserInfoKey(rawValue: "nodes")!] as? [Node] else {
      preconditionFailure()
    }
    
    var container = encoder.container(keyedBy: TableNameCodingKey.self)
    
    try db.inTransaction { proxy in
      let localNodes = try proxy.fetchIgnoringDelegate(Node.self)
      
      let nodes = Node.mergeForEncoding(localNodes: localNodes, remoteNodes: remoteNodes)
      
      for exampleModel in db.replicatingTables {
        try fetchAndEncode(instance: exampleModel, proxy: proxy, nodes: nodes, container: &container)
      }
      try container.encode(localNodes, forKey: TableNameCodingKey(stringValue: Node.tableName))
    }
  }
}

func fetchAndEncode<T: ReplicatingModel>(instance: T, proxy: LiteCrate.TransactionProxy, nodes: [Node], container: inout KeyedEncodingContainer<TableNameCodingKey>) throws {
  var models: [T] = []
  for node in nodes {
    models.append(contentsOf: try proxy.fetchIgnoringDelegate(
      T.self,
      allWhere: "witness = ? AND timeLastWitnessed >= ?",
      [node.id, node.time])
    )
  }
  try container.encode(models, forKey: .init(stringValue: T.tableName))
}

func fetch<T: ReplicatingModel>(instance: T, proxy: LiteCrate.TransactionProxy, nodes: [Node]) throws -> [any ReplicatingModel] {
  var models: [T] = []
  for node in nodes {
    models.append(contentsOf: try proxy.fetchIgnoringDelegate(
      T.self,
      allWhere: "witness = ? AND timeLastWitnessed >= ?",
      [node.id, node.time])
    )
  }
  return models
}

func populate<T: ReplicatingModel>(instance: T, proxy: LiteCrate.TransactionProxy, container: KeyedDecodingContainer<TableNameCodingKey>) throws {
  let instances = try container.decode([T].self, forKey: TableNameCodingKey(stringValue: T.tableName))
  for instance in instances {
    try proxy.saveIgnoringDelegate(instance)
  }
}
