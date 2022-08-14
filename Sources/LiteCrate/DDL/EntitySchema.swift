//
//  File.swift
//  
//
//  Created by Ryan Purpura on 8/11/22.
//

import Foundation
import LiteCrateCore

/// A property, corresponding to a column that is not a foreign key.
fileprivate struct SchemaProperty {
  var name: String
  var type: ExtendedSqliteType
  
  enum Subcolumn: String, CaseIterable {
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
  
  func columnDefinitions() -> [String] {
    var definitions = [String]()
    definitions.append("\(name) \(type.sqliteType.rawValue)")
    for subcolumn in Subcolumn.allCases {
      definitions.append("\(subcolumn.columnName(from: name)) \(subcolumn.type.sqliteType.rawValue)")
    }
    return definitions
  }
  
  func insertColumns() -> [String] {
    var columns = [String]()
    columns.append("\(name)")
    columns.append(contentsOf: Subcolumn.allCases.map {$0.columnName(from: name)})
    return columns
  }
}

/// The definition of an Entity.
public struct EntitySchema {
  enum SchemaError: Error {
    case nameAlreadyUsed
  }
  
  public private(set) var name: String
  fileprivate var properties: [String: SchemaProperty] = [:]
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
      
    schema.properties[propertyName] = SchemaProperty(name: propertyName, type: type)
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
    schema.properties[relationshipName] = SchemaProperty(name: relationshipName, type: nullable ? .nullableUUID : .uuid)
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
    let columns = properties.values.flatMap { $0.insertColumns () } + ["id"]
    let insertColumns = columns.joined(separator: ",")
    let valueColumns = columns.map{ ":\($0)" }.joined(separator: ",")
    
    return "INSERT INTO \(name)(\(insertColumns)) VALUES (\(valueColumns))"
  }
  
  func selectStatement(predicate: String = "TRUE") -> String {
    let columns = (properties.values.map(\.name) + ["id"]).map {"\($0) AS \($0)"}.joined(separator: ",")
    

    return "SELECT \(columns) FROM \(name) WHERE \(predicate)"
  }
}
