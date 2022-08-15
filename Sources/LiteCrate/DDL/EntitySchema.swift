//
//  File.swift
//  
//
//  Created by Ryan Purpura on 8/11/22.
//

import Foundation
import LiteCrateCore

enum SubcolumnSchema: String, CaseIterable {
  case lamport
  case sequencer
  case sequenceNumber
  
  var type: ExtendedSqliteType {
    switch self {
    case .lamport: return .integer
    case .sequencer: return .uuid
    case .sequenceNumber: return .integer
    }
  }
  
  func columnName(from baseName: String) -> String {
    "\(baseName)__\(rawValue)"
  }
}

/// A property, corresponding to a column that is not a foreign key.
fileprivate struct PropertySchema {
  var name: String
  var type: ExtendedSqliteType
  
  func columnDefinitions() -> [String] {
    var definitions = [String]()
    definitions.append("\(name) \(type.sqliteType.rawValue)")
    for subcolumn in SubcolumnSchema.allCases {
      definitions.append("\(subcolumn.columnName(from: name)) \(subcolumn.type.sqliteType.rawValue)")
    }
    return definitions
  }
  
  func columnNames() -> [String] {
    var columns = [String]()
    columns.append("\(name)")
    columns.append(contentsOf: SubcolumnSchema.allCases.map {$0.columnName(from: name)})
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
  fileprivate var relationships: [String: String] = [:]
  private var usedNames: Set<String>
  
  public init(name: String) {
    self.name = name
    self.usedNames = []
  }
  
  /// For the first version, start at 1.
  func withProperty(_ propertyName: String, type: ExtendedSqliteType) -> EntitySchema {
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
    schema.properties[relationshipName] = PropertySchema(name: relationshipName, type: nullable ? .nullableUUID : .uuid)
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
    
    return "CREATE TABLE \(name)(\((columnDefinitions + columnConstraints).joined(separator: ",\n    ")))"
  }
  
  func insertStatement() -> String {
    let columns = properties.values.flatMap { $0.columnNames () } + ["id"]
    let insertColumns = columns.joined(separator: ",")
    let valueColumns = columns.map{ ":\($0)" }.joined(separator: ",")
    
    return "INSERT INTO \(name)(\(insertColumns)) VALUES (\(valueColumns))"
  }
  
  func completeSelectStatement(predicate: String = "TRUE") -> String {
    // TODO: Fix me.
    let columns = (properties.values.map(\.name) + ["id"]).map {"\($0) AS \($0)"}.joined(separator: ",")

    return "SELECT \(columns) FROM \(name) WHERE \(predicate)"
  }
  
  func fieldsOnlySelectStatement(predicate: String = "TRUE") -> String {
    let columns = (properties.values.map(\.name) + ["id"]).map {"\($0) AS \($0)"}.joined(separator: ",")
    
    return "SELECT \(columns) FROM \(name) WHERE \(predicate)"
  }
}

extension EntitySchema {
  func fetch(cursor: Cursor, _ name: String, type: ExtendedSqliteType) -> ExtendedSqliteValue? {
    switch type {
    case .nullableInteger:
      guard !cursor.isNull(for: name) else { return nil }
        fallthrough
    case .integer:
      return .integer(val: cursor.int(for: name))
    case .nullableReal:
      guard !cursor.isNull(for: name) else { return nil }
      fallthrough
    case .real:
      return .real(val: cursor.double(for: name))
    case .nullableText:
      guard !cursor.isNull(for: name) else { return nil }
      fallthrough
    case .text:
      return .text(val: cursor.string(for: name))
    case .nullableBlob:
      guard !cursor.isNull(for: name) else { return nil }
      fallthrough
    case .blob:
      return .blob(val: cursor.data(for: name))
    case .nullableBool:
      guard !cursor.isNull(for: name) else { return nil }
      fallthrough
    case .bool:
      return .bool(val: cursor.bool(for: name))
    case .nullableUUID:
      guard !cursor.isNull(for: name) else { return nil }
      fallthrough
    case .uuid:
      return .uuid(val: cursor.uuid(for: name))
    case .nullableDate:
      guard !cursor.isNull(for: name) else { return nil }
      fallthrough
    case .date:
      return .date(val: cursor.date(for: name))
    }
  }
  
  // TODO: Move to extension on Cursor
  func entityWithMetadata(cursor: Cursor) -> ReplicatingEntityWithMetadata {
    let id = cursor.uuid(for: "id")
    var fields: [String: CompleteFieldData] = [:]
    for property in properties.values {
      let value = fetch(cursor: cursor, property.name, type: property.type)
      let lamport = cursor.int(for: "\(property.name)__lamport")
      let sequencer = cursor.uuid(for: "\(property.name)__sequencer")
      let sequenceNumber = cursor.int(for: "\(property.name)__sequenceNumber")
      fields[property.name] = CompleteFieldData(lamport: lamport, sequencer: sequencer, sequenceNumber: sequenceNumber, value: value)
    }
    return ReplicatingEntityWithMetadata(id: id, fields: fields)
  }
  
  func entity(cursor: Cursor) -> ReplicatingEntity {
    var entity = ReplicatingEntity(entityType: name, id: cursor.uuid(for: "id"))
    for property in properties.values {
      entity[property.name] = fetch(cursor: cursor, property.name, type: property.type)
    }
    return entity
  }
}
