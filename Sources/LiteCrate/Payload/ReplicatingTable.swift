//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public class ReplicatingTable: Hashable {
  let tableName: String
  init(tableName: String) {
    self.tableName = tableName
  }
  public static func == (lhs: ReplicatingTable, rhs: ReplicatingTable) -> Bool {
    return lhs.tableName == rhs.tableName
  }
    
  public func hash(into hasher: inout Hasher) {
    hasher.combine(tableName)
  }
  
  func fetch(proxy: LiteCrate.TransactionProxy) throws -> any Codable {
    fatalError("Abstract Method")
  }

}

class ReplicatingTableImpl<T: LCModel>: ReplicatingTable {
  init(_ type: T.Type) {
    super.init(tableName: T.tableName)
  }
  
  override func fetch(proxy: LiteCrate.TransactionProxy) throws -> any Codable {
    try proxy.fetch(T.self)
  }
}


