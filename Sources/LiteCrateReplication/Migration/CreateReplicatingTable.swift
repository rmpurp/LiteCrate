//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrate

public protocol ReplicatingTableMigrationAction: MigrationAction {
  func modifyReplicatingTables(_ replicatingTables: inout [any ReplicatingModel])
}

public struct CreateReplicatingTable<T: ReplicatingModel>: ReplicatingTableMigrationAction {
  let creationStatement: String
  let instance: any ReplicatingModel
  init(_ instance: T) {
    creationStatement = instance.creationStatement
    self.instance = instance
  }
  
  public func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }
  
  public func modifyReplicatingTables(_ replicatingTables: inout [any ReplicatingModel]) {
    replicatingTables.append(instance)
  }
}
