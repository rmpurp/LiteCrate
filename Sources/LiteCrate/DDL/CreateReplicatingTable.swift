//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation

public protocol ReplicatingTableMigrationAction: MigrationAction {
  func modifyReplicatingTables(
    _ tables: inout [String: any ReplicatingModel.Type]
  )
}

public struct CreateReplicatingTable<T: ReplicatingModel>: ReplicatingTableMigrationAction {
  let creationStatement: String
  init(_: T.Type) {
    creationStatement = T.table.createTableStatement()
  }

  public func perform(in proxy: TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }

  public func modifyReplicatingTables(
    _ tables: inout [String: any ReplicatingModel.Type]
  ) {
    tables[T.table.tableName] = T.self
  }
}
