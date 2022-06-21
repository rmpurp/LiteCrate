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
  
  init() {}
  
  required init(from decoder: Decoder) throws {
    guard let replicator = decoder.userInfo[CodingUserInfoKey(rawValue: "replicator")!] as? ReplicationController else {
      preconditionFailure()
    }
    
    let container = try decoder.container(keyedBy: TableNameCodingKey.self)
    
    try replicator.inTransaction { proxy in
      for instance in replicator.replicatingTables {
        try instance.populate(proxy: proxy, container: container)
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
        try exampleModel.fetchAndEncode(proxy: proxy, nodes: nodes, container: &container)
      }
      try container.encode(localNodes, forKey: TableNameCodingKey(stringValue: Node.tableName))
    }
  }
}

// Generics workaround
fileprivate extension ReplicatingModel {
  func fetchAndEncode(proxy: LiteCrate.TransactionProxy, nodes: [Node], container: inout KeyedEncodingContainer<TableNameCodingKey>) throws {
    var models: [Self] = []
    for node in nodes {
      models.append(contentsOf: try proxy.fetchIgnoringDelegate(
        Self.self,
        allWhere: "witness = ? AND timeLastWitnessed >= ?",
        [node.id, node.time])
      )
    }
    try container.encode(models, forKey: .init(stringValue: Self.tableName))
  }
  
  func populate(proxy: LiteCrate.TransactionProxy, container: KeyedDecodingContainer<TableNameCodingKey>) throws {
    let instances = try container.decode([Self].self, forKey: TableNameCodingKey(stringValue: Self.tableName))
    for instance in instances {
      try proxy.saveIgnoringDelegate(instance)
    }
  }
}
