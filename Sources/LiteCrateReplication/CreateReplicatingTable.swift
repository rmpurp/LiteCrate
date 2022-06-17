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
  let dotCreationStatement: String
  
  init(_ instance: T) {
    creationStatement = instance.creationStatement
    let dot = Dot<T>(modelID: UUID(), time: 0, creator: UUID())
    dotCreationStatement = dot.creationStatement
  }
  
  public func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(dotCreationStatement)
    try proxy.execute(creationStatement)
  }
  
  public func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>) {
    replicatingTables.insert(ReplicatingTableImpl(T.self))
  }
}
