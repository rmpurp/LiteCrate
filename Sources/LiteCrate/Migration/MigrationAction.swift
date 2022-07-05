//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public protocol MigrationAction: MigrationStep {
  func perform(in proxy: TransactionProxy) throws
}

public extension MigrationAction {
  var asGroup: MigrationGroup {
    MigrationGroup {
      self
    }
  }
}

public struct CreateTable<T: DatabaseCodable>: MigrationAction {
  let creationStatement: String
  init(_: T.Type) {
    creationStatement = SchemaEncoder(T.exampleInstance).creationStatement
  }

  public func perform(in proxy: TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }
}

public struct Execute: MigrationAction {
  let statement: String

  init(_ statement: String) {
    self.statement = statement
  }

  public func perform(in proxy: TransactionProxy) throws {
    try proxy.execute(statement)
  }
}
