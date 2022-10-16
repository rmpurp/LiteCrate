//
//  File.swift
//
//
//  Created by Ryan Purpura on 8/11/22.
//

import Foundation
import LiteCrateCore

protocol ColumnVisitor {
  func visit<V: SqliteRepresentable>(_ column: SchemaColumn<V>)
}

protocol ColumnSchemaProtocol: Hashable {
  var name: String { get }

  func accept<V: ColumnVisitor>(visitor: V)
}

public protocol TableSchema {
  var tableName: String { get }
}

public struct SchemaColumn<V: SqliteRepresentable>: ColumnSchemaProtocol {
  let name: String
  let referenceTable: String?
  
  init(_ name: String) {
    self.name = name
    self.referenceTable = nil
  }
  
  init(_ name: String, references referenceTable: String) where V == UUID {
    self.name = name
    self.referenceTable = referenceTable
  }

  func accept<V: ColumnVisitor>(visitor: V) {
    visitor.visit(self)
  }
}

class CreateStatementGenerator: ColumnVisitor {
  private var tableName: String
  private var columns: [String] = []
  
  init<T: TableSchema>(schema: T) {
    tableName = schema.tableName
    let mirror = Mirror(reflecting: schema)
    columns.append("id TEXT NOT NULL PRIMARY KEY")
    for (_, column) in mirror.children {
      if let column = column as? any ColumnSchemaProtocol {
        column.accept(visitor: self)
      }
    }
  }
  
  func makeCreationStatement() -> String {
    let whitespace = "\n    "
    
    let columnDefinitions = columns.joined(separator: ",\(whitespace)")
    return "CREATE TABLE \(tableName) (\(whitespace)\(columnDefinitions)\n)"
  }
  
  func visit<V: SqliteRepresentable>(_ column: SchemaColumn<V>) {
    let foreignKeyClause = column.referenceTable.flatMap { " REFERENCES \($0)(id)" } ?? ""
    
    columns.append("\(column.name) \(V.sqliteType.typeDefinition)\(foreignKeyClause)")
    columns.append("\(column.name)__lamport \(Int64.sqliteType.typeDefinition)")
    columns.append("\(column.name)__sequenceNumber \(Int64.sqliteType.typeDefinition)")
    columns.append("\(column.name)__sequencer \(UUID.sqliteType.typeDefinition)")
  }
}

enum SubcolumnSchema: String, CaseIterable {
  case lamport
  case sequencer
  case sequenceNumber

  var type: SQLiteType {
    switch self {
    case .lamport: return .integer
    case .sequencer: return .text
    case .sequenceNumber: return .integer
    }
  }

  func columnName(from baseName: String) -> String {
    "\(baseName)__\(rawValue)"
  }
}

/// A property, corresponding to a column that is not a foreign key.
private struct PropertySchema {
  var name: String
  var type: SQLiteType

  func columnDefinitions() -> [String] {
    var definitions = [String]()
    definitions.append("\(name) \(type.typeDefinition)")
    for subcolumn in SubcolumnSchema.allCases {
      definitions.append("\(subcolumn.columnName(from: name)) \(subcolumn.type.typeDefinition)")
    }
    return definitions
  }

  func columnNames() -> [String] {
    var columns = [String]()
    columns.append("\(name)")
    columns.append(contentsOf: SubcolumnSchema.allCases.map { $0.columnName(from: name) })
    return columns
  }
}

/// The definition of an Entity.
public struct EntitySchema {
  enum SchemaError: Error {
    case nameAlreadyUsed
  }

  public private(set) var name: String
  fileprivate var properties: [String: PropertySchema] = [:]
  private var relationships: [String: String] = [:]
  private var usedNames: Set<String>

  public init(name: String) {
    self.name = name
    usedNames = []
  }

  /// For the first version, start at 1.
  func withProperty(_ propertyName: String, type: SQLiteType) -> EntitySchema {
    var schema = self
    do {
      guard schema.properties[propertyName] == nil else { throw SchemaError.nameAlreadyUsed }
    } catch {
      preconditionFailure()
    }

    schema.properties[propertyName] = PropertySchema(name: propertyName, type: type)
    return schema
  }

  /// Ignored if version is not the first version. May be changed in the future.
  /// For the first version, start at 1.
  func withRelationship(_ relationshipName: String, reference: String, nullable: Bool = false) -> EntitySchema {
    var schema = self
    do {
      guard schema.properties[relationshipName] == nil else { throw SchemaError.nameAlreadyUsed }
    } catch {
      preconditionFailure()
    }
//    schema.properties[relationshipName] = PropertySchema(name: relationshipName, type: nullable ? .nullableUUID : .uuid)
    schema.relationships[relationshipName] = reference
    return schema
  }

  public func createTableStatement() -> String {
    var columnDefinitions = properties.values.flatMap { $0.columnDefinitions() }
    var columnConstraints = [String]()
    columnDefinitions.append("id TEXT NOT NULL PRIMARY KEY")

    for (column, reference) in relationships {
      columnConstraints.append("FOREIGN KEY (\(column)) REFERENCES \(reference)(id)")
    }

    return "CREATE TABLE \(name)(\((columnDefinitions + columnConstraints).joined(separator: ",\n    "))) STRICT"
  }

  func insertStatement() -> String {
    let columns = properties.values.flatMap { $0.columnNames() } + ["id"]
    let insertColumns = columns.joined(separator: ",")
    let valueColumns = columns.map { ":\($0)" }.joined(separator: ",")

    return "INSERT INTO \(name)(\(insertColumns)) VALUES (\(valueColumns))"
  }

  func completeSelectStatement(predicate: String = "TRUE") -> String {
    // TODO: Fix me.
    let columns = (properties.values.map(\.name) + ["id"]).map { "\($0) AS \($0)" }.joined(separator: ",")

    return "SELECT \(columns) FROM \(name) WHERE \(predicate)"
  }

  func fieldsOnlySelectStatement(predicate: String = "TRUE") -> String {
    let columns = (properties.values.map(\.name) + ["id"]).map { "\($0) AS \($0)" }.joined(separator: ",")

    return "SELECT \(columns) FROM \(name) WHERE \(predicate)"
  }
}

extension Cursor {
  func entity(with schema: EntitySchema) -> ReplicatingEntity {
    var entity = ReplicatingEntity(entityType: schema.name, id: uuid(for: "id"))
    for property in schema.properties.values {
      entity[property.name] = SQLiteValue.integer(val: 0)
    }
    return entity
  }

  func entityWithMetadata(with schema: EntitySchema) -> ReplicatingEntityWithMetadata {
    let id = uuid(for: "id")
    var fields: [String: CompleteFieldData] = [:]
    for property in schema.properties.values {
//      let value = fetch(name: property.name, type: property.type)
      let value = SQLiteValue.integer(val: 0)
      let lamport = int(for: "\(property.name)__lamport")
      let sequencer = uuid(for: "\(property.name)__sequencer")
      let sequenceNumber = int(for: "\(property.name)__sequenceNumber")
      fields[property.name] = CompleteFieldData(
        lamport: lamport,
        sequencer: sequencer,
        sequenceNumber: sequenceNumber,
        value: value
      )
    }
    return ReplicatingEntityWithMetadata(entityType: schema.name, id: id, fields: fields)
  }
}
