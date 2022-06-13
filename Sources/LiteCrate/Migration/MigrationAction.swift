//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

protocol MigrationAction {
  func perform(in proxy: LiteCrate.TransactionProxy) throws
  func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>)
}

extension MigrationAction {
}

struct CreateReplicatingTable<T: LCModel>: MigrationAction {
  let creationStatement: String
  init(_ instance: T) {
    creationStatement = instance.creationStatement
  }
  
  func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
    // TODO: Create CRDT Metadata table.
  }
  
  func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>) {
    replicatingTables.insert(ReplicatingTableImpl(T.self))
  }
}

struct CreateTable<T: LCModel>: MigrationAction {
  let creationStatement: String
  init(_ instance: T) {
    creationStatement = instance.creationStatement
  }
  
  func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }
  
  func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>) {
    print("I'm called.")
  }

}

struct Execute: MigrationAction {
  let statement: String
  
  init(_ statement: String) {
    self.statement = statement
  }
  
  func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(statement)
  }
  
  func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>) {
    print("I'm called.")
  }

}
