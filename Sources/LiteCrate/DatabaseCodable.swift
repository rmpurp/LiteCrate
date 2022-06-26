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
  static var tableName: String { get }
  var tableName: String { get }
  static var foreignKeys: [ForeignKey] { get }
  static var primaryKeyColumn: String { get }
  var primaryKeyValue: Key { get }
}

public extension DatabaseCodable {
  static var tableName: String { String(describing: Self.self) }
  static var foreignKeys: [ForeignKey] { [] }

  var tableName: String { Self.tableName }

  var creationStatement: String {
    let encoder = SchemaEncoder()
    try! encode(to: encoder)

    let opening = "CREATE TABLE \(Self.tableName) (\n"
    var components = [String]()
    let ending = "\n);"

    let sortedColumns = encoder.columns.sorted {
      if $0.key == Self.primaryKeyColumn { return true }
      if $1.key == Self.primaryKeyColumn { return false }
      return $0.key < $1.key
    }

    components.append(contentsOf: sortedColumns.map { "\($0) \($1.rawValue)" })
    if !(primaryKeyValue is Void) {
      components.append("PRIMARY KEY (\(Self.primaryKeyColumn))")
    }
    components.append(contentsOf: Self.foreignKeys.map(\.creationStatement))
    return opening + components.map { "    " + $0 }.joined(separator: ",\n") + ending
  }
}

extension Never: SqliteRepresentable {
  public var asSqliteType: LiteCrateCore.SqliteType {
    switch self {}
  }

  public func encode(to _: Encoder) throws {
    switch self {}
  }

  public init(from _: Decoder) throws {
    switch self {}
  }
}

public extension DatabaseCodable where Key == Never {
  static var primaryKeyColumn: String { "" }
  var primaryKeyValue: Key { fatalError() }
}

public extension DatabaseCodable where Self: Identifiable, ID == Key {
  static var primaryKeyColumn: String { "id" }
  var primaryKeyValue: Key { id }
}

public struct ForeignKey {
  public enum OnDelete {
    case cascade
    case setNull
    case setDefault
    case restrict
    case noAction

    var clause: String {
      switch self {
      case .noAction: return "NO ACTION"
      case .restrict: return "RESTRICT"
      case .setNull: return "SET NULL"
      case .setDefault: return "SET DEFAULT"
      case .cascade: return "CASCADE"
      }
    }
  }

  public var columnName: String
  public var targetTable: String
  public var targetColumn: String
  public var onDelete: OnDelete

  public init(
    _ columnName: String,
    references targetTable: String,
    targetColumn: String,
    onDelete: OnDelete = .noAction
  ) {
    self.columnName = columnName
    self.targetColumn = targetColumn
    self.targetTable = targetTable
    self.onDelete = onDelete
  }

  fileprivate var creationStatement: String {
    "FOREIGN KEY (\(columnName)) REFERENCES \(targetTable)(\(targetColumn)) ON DELETE \(onDelete.clause)"
  }
}
