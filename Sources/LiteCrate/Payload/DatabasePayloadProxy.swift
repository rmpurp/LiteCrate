//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrateCore

struct DatabasePayloadProxy: Codable {
  static let databaseUserInfoKey = CodingUserInfoKey(rawValue: "Database")!

  struct TableNameCodingKey: CodingKey {
    var stringValue: String
    
    init(stringValue: String) {
      self.stringValue = stringValue
    }
    
    var intValue: Int? = nil
    
    init?(intValue: Int) {
      return nil
    }
    
    
  }
  init() {}
  
  init(from decoder: Decoder) throws {
    guard let database = decoder.userInfo[DatabasePayloadProxy.databaseUserInfoKey] as? LiteCrate else {
      fatalError("Insert the database into the UserInfo dictionary.")
    }
    
    let container = try decoder.container(keyedBy: TableNameCodingKey.self)
    
    try database.inTransaction { proxy in
      for replicatingTable in database.replicatingTables {
        try replicatingTable.populate(proxy: proxy, decodingContainer: container)
      }
    }
  }
  
  func encode(to encoder: Encoder) throws {
    guard let database = encoder.userInfo[DatabasePayloadProxy.databaseUserInfoKey] as? LiteCrate else {
      fatalError("Insert the database into the UserInfo dictionary.")
    }
    var container = encoder.container(keyedBy: TableNameCodingKey.self)
    
    try database.inTransaction { proxy in
      for replicatingTable in database.replicatingTables {
        try container.encode(replicatingTable.fetch(proxy: proxy), forKey: TableNameCodingKey(stringValue: replicatingTable.tableName))
      }
    }
  }
}

