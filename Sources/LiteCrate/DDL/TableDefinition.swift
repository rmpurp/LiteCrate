//
//  File.swift
//  
//
//  Created by Ryan Purpura on 7/18/22.
//

import Foundation
import LiteCrateCore

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

protocol ColumnProtocol {
  func columnDefinition() -> String
  func constraintDefinitions() -> [String]
  
  var name: String { get }
}

extension ColumnProtocol {
  func primaryKey() -> PrimaryKeyColumn<Self> {
    PrimaryKeyColumn(column: self)
  }
  
  func foreignKey(foreignTable: String, foreignColumn: String = "id") -> ForeignKeyColumn<Self> {
    ForeignKeyColumn(baseColumn: self, foreignTable: foreignTable, foreignColumn: foreignColumn )
  }
}

struct Column: ColumnProtocol {
  func columnDefinition() -> String {
    "\(name) \(type.rawValue)"
  }
  
  func constraintDefinitions() -> [String] {
    []
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

struct PrimaryKeyColumn<C: ColumnProtocol>: ColumnProtocol {
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

struct ForeignKeyColumn<C: ColumnProtocol>: ColumnProtocol {
  func columnDefinition() -> String {
    return baseColumn.columnDefinition()
  }
  
  func constraintDefinitions() -> [String] {
    var constraints = baseColumn.constraintDefinitions()
    constraints.append("FOREIGN KEY (\(name)) REFERENCES \(foreignTable)(\(foreignColumn)) \(onDeleteAction.clause)")
    return constraints
    
  }
  
  var name: String { baseColumn.name }
  
  let baseColumn: C
  let foreignTable: String
  let foreignColumn: String
  var onDeleteAction: OnDeleteAction
  
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

struct Table {
  let tableName: String
  let columns: [any ColumnProtocol]
  
  init(_ tableName: String, @TableBuilder _ builder: () -> [any ColumnProtocol]) {
    self.tableName = tableName
    self.columns = builder()
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
  
  func selectStatement(where whereClause: String = "TRUE") -> String {
    let selectColumns = columns.lazy
      .map { "\($0.name) AS \($0.name)"}
      .joined(separator: ", ")
    return "SELECT \(selectColumns) FROM \(tableName) WHERE \(whereClause)"
  }
}
