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
  func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>) {}
}

struct CreateReplicatingTable<T: ReplicatingModel>: MigrationAction {
  let creationStatement: String
  let metadataCreationStatement: String

  init(_ instance: T) {
    creationStatement = instance.creationStatement
    let metadata = Metadata<T>(version: UUID(), modelID: UUID(), lamport: 0, sequenceLamport: 0)
    metadataCreationStatement = metadata.creationStatement
  }
  
  func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(metadataCreationStatement)
    try proxy.execute(creationStatement)
  }
  
  func modifyReplicatingTables(_ replicatingTables: inout Set<ReplicatingTable>) {
    replicatingTables.insert(ReplicatingTableImpl(T.self))
  }
}

struct CreateTable<T: DatabaseCodable>: MigrationAction {
  let creationStatement: String
  init(_ instance: T) {
    creationStatement = instance.creationStatement
  }
  
  func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
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
}
