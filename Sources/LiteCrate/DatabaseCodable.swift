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
  static var foreignKeys: [ForeignKey] { get }
  static var primaryKeyColumn: String { get }
  var primaryKeyValue: Key { get }
  static var exampleInstance: Self { get }
}

public extension DatabaseCodable {
  var tableName: String { String(describing: Self.self) }
  static var foreignKeys: [ForeignKey] { [] }
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

  internal var creationStatement: String {
    "FOREIGN KEY (\(columnName)) REFERENCES \(targetTable)(\(targetColumn)) ON DELETE \(onDelete.clause)"
  }
}
