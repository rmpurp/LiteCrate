//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrate

public protocol ReplicatingTableMigrationAction: MigrationAction {
  func modifyReplicatingTables(
    _ tables: inout [any ReplicatingModel.Type]
  )
}

public struct CreateReplicatingTable<T: ReplicatingModel>: ReplicatingTableMigrationAction {
  let creationStatement: String
  init(_: T.Type) {
    creationStatement = SchemaEncoder(T.exampleInstance).creationStatement
  }

  public func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }

  public func modifyReplicatingTables(
    _ tables: inout [any ReplicatingModel.Type]
  ) {
    tables.append(T.self)
  }
}
