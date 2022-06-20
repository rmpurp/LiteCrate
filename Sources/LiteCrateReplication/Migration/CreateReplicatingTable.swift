//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrate

public protocol ReplicatingTableMigrationAction: MigrationAction {
  func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>)
}

public struct CreateReplicatingTable<T: ReplicatingModel>: ReplicatingTableMigrationAction {
  let creationStatement: String
  
  init(_ instance: T) {
    creationStatement = instance.creationStatement
  }
  
  public func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }
  
  public func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>) {
    replicatingTables.insert(ReplicatingTableImpl(T.self))
  }
}
