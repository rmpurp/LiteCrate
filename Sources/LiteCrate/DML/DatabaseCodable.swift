//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrateCore

public protocol DatabaseCodable<Key>: Codable {
  associatedtype Key: SqliteRepresentable
  var tableName: String { get }
  static var primaryKeyColumn: String { get }
  var primaryKeyValue: Key { get }
  static var exampleInstance: Self { get }
  @ConstraintBuilder<Self> var foreignKeyConstraints: FKConstraints<Self> { get }
}

public extension DatabaseCodable {
  var tableName: String { String(describing: Self.self) }
  var foreignKeyConstraints: FKConstraints<Self> { FKConstraints() }
}

public extension DatabaseCodable where Self: Identifiable, ID == Key {
  static var primaryKeyColumn: String { "id" }
  var primaryKeyValue: Key { id }
}
