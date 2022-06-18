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
    }
  }
  
  func encode(to encoder: Encoder) throws {
    guard let replicator = encoder.userInfo[CodingUserInfoKey(rawValue: "replicator")!] as? ReplicationController else {
      preconditionFailure()
    }
    
//    guard let nodes = encoder.userInfo[CodingUserInfoKey(rawValue: "nodes")!] as? [Node] else {
//      preconditionFailure()
//    }
    
    var nodeDict = [UUID : Node]()
    nodeDict[replicator.nodeID] = Node(id: replicator.nodeID, time: 0)
//
//    for node in nodes {
//      nodeDict[node.id] = node
//    }
    
    var container = encoder.container(keyedBy: TableNameCodingKey.self)
    
    try replicator.inTransaction { proxy in
      for var node in try proxy.fetch(Node.self) {
        if nodeDict[node.id] == nil {
          node.time = 0
          nodeDict[node.id] = node
        }
      }
      
      for replicatingTable in replicator.replicatingTables {
        try container.encode(replicatingTable.fetch(proxy: proxy), forKey: TableNameCodingKey(stringValue: replicatingTable.tableName))
      }
    }
  }
}
