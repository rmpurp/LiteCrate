//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/17/22.
//

import Foundation

class CodableProxy: Codable {
  init() {}
  
  required init(from decoder: Decoder) throws {
    guard let replicator = decoder.userInfo[CodingUserInfoKey(rawValue: "replicator")!] as? ReplicationController else {
      preconditionFailure()
    }
 
    let container = try decoder.container(keyedBy: TableNameCodingKey.self)

    try replicator.inTransaction { proxy in
      for replicationTable in replicator.replicatingTables {
        try replicationTable.populate(proxy: proxy, decodingContainer: container)
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
      db.fetchDeletedModels = true
      let localNodes = try proxy.fetch(Node.self)

      let nodes = Node.mergeForEncoding(localNodes: localNodes, remoteNodes: remoteNodes)
      // TODO: Optimized fetching.
      
      for replicatingTable in db.replicatingTables {
        try container.encode(replicatingTable.fetch(proxy: proxy, mergedNodes: nodes),
                             forKey: replicatingTable.codingKey)
      }
      try container.encode(localNodes, forKey: TableNameCodingKey(stringValue: Node.tableName))
    }
  }
}
