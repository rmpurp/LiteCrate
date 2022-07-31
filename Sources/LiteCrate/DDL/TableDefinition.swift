//
//  File.swift
//  
//
//  Created by Ryan Purpura on 7/18/22.
//

import Foundation
import LiteCrateCore

/// Allowable types for columns.
public enum SqliteType: String {
  case integer = "INTEGER NOT NULL"
  case real = "REAL NOT NULL"
  case text = "TEXT NOT NULL"
  case blob = "BLOB NOT NULL"
  case nullableInteger = "INTEGER"
  case nullableReal = "REAL"
  case nullableText = "TEXT"
  case nullableBlob = "BLOB"
}

/// This protocol represents a clause in a create-table statement, along with
/// constraints that may be associated with taht column.
protocol ColumnProtocol {
  /// The definition clause of the column.
  func columnDefinition() -> String
  /// The constraints for that column.
  func constraintDefinitions() -> [String]
  /// The constraints for the column in a replicating context.
  /// This typically includes additional foreign keys to metadata tables.
  func replicatingConstraintDefinitions(primaryKeyColumnName: String) -> [String]
  /// The name of the column.
  func isPrimaryKeyColumn() -> Bool
  /// The name of the column.
  func isForeignKeyColumn() -> Bool
  var name: String { get }
}

extension ColumnProtocol {
  /// Use this modifier to mark this column as a primary key.
  func primaryKey() -> PrimaryKeyColumn<Self> {
    PrimaryKeyColumn(column: self)
  }
  
  /// Use this modifier to mark this column as a ForeignKey
  func foreignKey(foreignTable: String, foreignColumn: String = "id") -> ForeignKeyColumn<Self> {
    ForeignKeyColumn(baseColumn: self, foreignTable: foreignTable, foreignColumn: foreignColumn )
  }
}

/// A normal column of a table, with no constraints.
struct Column: ColumnProtocol {
  func replicatingConstraintDefinitions(primaryKeyColumnName: String) -> [String] {
    []
  }
  
  func columnDefinition() -> String {
    "\(name) \(type.rawValue)"
  }
  
  func constraintDefinitions() -> [String] {
    []
  }
  
  func replicatingConstraintDefinitions() -> [String] {
    []
  }
  
  func primaryKeyColumnNameIfPrimaryKeyColumn() -> String? {
    return nil
  }

  func isPrimaryKeyColumn() -> Bool {
    false
  }
  
  func isForeignKeyColumn() -> Bool {
    false
  }
  
  let name: String
  let type: SqliteType
  
  init(name: String, type: SqliteType) {
    self.name = name
    self.type = type
  }
  
  init<C: CodingKey>(_ codingKey: C, type: SqliteType) {
    self.name = codingKey.stringValue
    self.type = type
  }
}

/// A primary key column.
struct PrimaryKeyColumn<C: ColumnProtocol>: ColumnProtocol {
  func replicatingConstraintDefinitions(primaryKeyColumnName: String) -> [String] {
    var constraints = baseColumn.replicatingConstraintDefinitions(primaryKeyColumnName: primaryKeyColumnName)
    constraints.append("FOREIGN KEY (\(name)) REFERENCES ObjectRecord ON DELETE CASCADE")
    return constraints
  }
  
  func isPrimaryKeyColumn() -> Bool {
    true
  }
  
  func isForeignKeyColumn() -> Bool {
    baseColumn.isForeignKeyColumn()
  }
  
  let baseColumn: C
  
  func columnDefinition() -> String {
    baseColumn.columnDefinition()
  }
  
  func constraintDefinitions() -> [String] {
    var constraints = baseColumn.constraintDefinitions()
    constraints.append("PRIMARY KEY (\(name))")
    return constraints
  }
  
  var name: String { baseColumn.name }

  init(column: C) {
    baseColumn = column
  }
}

/// A column that is a foreign key.
struct ForeignKeyColumn<C: ColumnProtocol>: ColumnProtocol {
  func isPrimaryKeyColumn() -> Bool {
    baseColumn.isPrimaryKeyColumn()
  }
  
  func isForeignKeyColumn() -> Bool {
    true
  }
  
  func columnDefinition() -> String {
    return baseColumn.columnDefinition()
  }
  
  func constraintDefinitions() -> [String] {
    var constraints = baseColumn.constraintDefinitions()
    constraints.append("FOREIGN KEY (\(name)) REFERENCES \(foreignTable)(\(foreignColumn)) \(onDeleteAction.clause)")
    return constraints
  }
  
  func replicatingConstraintDefinitions(primaryKeyColumnName: String) -> [String] {
    var constraints = baseColumn.replicatingConstraintDefinitions(primaryKeyColumnName: primaryKeyColumnName)
    constraints.append("FOREIGN KEY (primaryKeyColumnName, \(name)) REFERENCES ForeignKeyField ON DELETE RESTRICT")
    return constraints
  }

  
  var name: String { baseColumn.name }
  
  let baseColumn: C
  let foreignTable: String
  let foreignColumn: String
  var onDeleteAction: OnDeleteAction
  
  /// What to do when the referenced row is deleted.
  enum OnDeleteAction {
    case noAction
    case restrict
    case setNull
    case setDefault
    case cascade
    
    var clause: String {
      switch self {
      case .noAction: return "ON DELETE NO ACTION"
      case .restrict: return "ON DELETE RESTRICT"
      case .setNull: return "ON DELETE SET NULL"
      case .setDefault: return "ON DELETE SET DEFAULT"
      case .cascade: return "ON DELETE CASCADE"
      }
    }
  }
  
  init(baseColumn: C, foreignTable: String, foreignColumn: String, onDelete onDeleteAction: OnDeleteAction = .noAction) {
    self.baseColumn = baseColumn
    self.foreignTable = foreignTable
    self.foreignColumn = foreignColumn
    self.onDeleteAction = onDeleteAction
  }
}

@resultBuilder
struct TableBuilder {
  static func buildBlock(_ components: any ColumnProtocol...) ->  [any ColumnProtocol] {
    components
  }
}

/// Represents the columns and constraints of a Table, and provides convenient ways to access the
/// table creation statement and interact with its foreign keys.
public struct Table {
  let tableName: String
  let columns: [any ColumnProtocol]
  let primaryKeyColumn: String
  
  init(_ tableName: String, @TableBuilder _ builder: () -> [any ColumnProtocol]) {
    self.tableName = tableName
    self.columns = builder()
    self.primaryKeyColumn = Table.primaryKeyColumn(from: self.columns)
  }
  
  func createTableStatement() -> String {
    var columnDefinitions = [String]()
    var columnConstraints = [String]()
    for column in columns {
      columnDefinitions.append(column.columnDefinition())
      columnConstraints.append(contentsOf: column.constraintDefinitions())
    }
    
    let combined = (columnDefinitions + columnConstraints).joined(separator: ",\n    ")
    return "CREATE TABLE \(tableName) (\n    \(combined)\n)"
  }
  
  func createReplicatingTableStatement() -> String {
    var columnDefinitions = [String]()
    var columnConstraints = [String]()
    for column in columns {
      columnDefinitions.append(column.columnDefinition())
      columnConstraints.append(contentsOf: column.replicatingConstraintDefinitions(primaryKeyColumnName: primaryKeyColumn))
    }
    
    let combined = (columnDefinitions + columnConstraints).joined(separator: ",\n    ")
    return "CREATE TABLE \(tableName) (\n    \(combined)\n)"
  }
  
  static func primaryKeyColumn(from columns: [any ColumnProtocol]) -> String {
    for column in columns {
      if column.isPrimaryKeyColumn() {
        return column.name
      }
    }
    fatalError("No primary key column defined.")
  }
  
  func forEachForeignKey(_ block: (String) -> Void) {
    for column in columns {
      if column.isForeignKeyColumn() {
        block(column.name)
      }
    }
  }
  
  func selectStatement(where whereClause: String = "TRUE") -> String {
    let selectColumns = columns.lazy
      .map { "\($0.name) AS \($0.name)"}
      .joined(separator: ", ")
    return "SELECT \(selectColumns) FROM \(tableName) WHERE \(whereClause)"
  }
  
  func insertStatement() -> String {
    #warning("FIX ME")
    fatalError()
  }
}
