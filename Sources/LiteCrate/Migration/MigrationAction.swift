//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public protocol MigrationAction {
  func perform(in proxy: LiteCrate.TransactionProxy) throws
}

public struct CreateTable<T: DatabaseCodable>: MigrationAction {
  let creationStatement: String
  init(_ instance: T) {
    creationStatement = instance.creationStatement
  }

  public func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(creationStatement)
  }
}

public struct Execute: MigrationAction {
  let statement: String

  init(_ statement: String) {
    self.statement = statement
  }

  public func perform(in proxy: LiteCrate.TransactionProxy) throws {
    try proxy.execute(statement)
  }
}
