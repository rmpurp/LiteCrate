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
    let modelDot = ModelDotPair<T>.exampleInstance
    let encoder = SchemaEncoder(modelDot)
//    encoder.columns["creator"] = .text
//    encoder.columns["createdTime"] = .integer
//    encoder.columns["lastModifier"] = .text
//    encoder.columns["sequenceNumber"] = .integer
//    encoder.columns["lamportClock"] = .integer
    creationStatement = encoder.creationStatement
  }

  public func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }

  public func modifyReplicatingTables(
    _ tables: inout [String: any ReplicatingModel.Type]
  ) {
    tables[T.exampleInstance.tableName] = T.self
  }
}
