//
//  File.swift
//  
//
//  Created by Ryan Purpura on 8/11/22.
//

import Foundation

/// A property, corresponding to a column that is not a foreign key.
fileprivate struct SchemaProperty: Codable {
  var name: String
  var type: SqliteType
  var version: Int64
}

/// A relationship between Entities, corresponding to a column that is a foreign Key
fileprivate struct SchemaRelationship: Codable {
  var name: String
  var reference: String
  var version: Int64
}

/// The properties and relationships added to an Entity at a particular version.
fileprivate struct Version: Codable {
  var properties: [SchemaProperty] = []
  var relationships: [SchemaRelationship] = []
}

/// The definition of an Entity.
public struct EntitySchema: Codable {
  enum SchemaError: Error {
    case nameAlreadyUsed
  }
  
  public private(set) var name: String
  private var versions: [Int64: Version]
  private var usedNames: Set<String>
  
  public init(name: String) {
    self.name = name
    self.versions = [:]
    self.usedNames = []
  }
  
  private mutating func insertAndCheck(name: String) throws {
    if self.usedNames.contains(name) {
      throw SchemaError.nameAlreadyUsed
    }
    usedNames.insert(name)
  }
  
  enum CodingKeys: CodingKey {
    case name
    case versions
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.name, forKey: .name)
    try container.encode(self.versions, forKey: .versions)
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
    self.versions = try container.decode([Int64 : Version].self, forKey: .versions)
    self.usedNames = []
    for (_, version) in versions {
      for property in version.properties {
        try insertAndCheck(name: property.name)
      }
      
      for relationship in version.relationships {
        try insertAndCheck(name: relationship.name)
      }
    }
  }
  
  /// For the first version, start at 1.
  func withProperty(_ propertyName: String, type: SqliteType, version: Int64) -> EntitySchema {
    var schema = self
    do {
      try schema.insertAndCheck(name: propertyName)
    } catch {
      preconditionFailure()
    }
    
    schema.versions[version, default: Version()].properties.append(SchemaProperty(name: propertyName, type: type, version: version))
    return schema
  }
  
  /// Ignored if version is not the first version. May be changed in the future.
  /// For the first version, start at 1.
  func withRelationship(_ relationshipName: String, reference: String, version: Int64) -> EntitySchema {
    var schema = self
    do {
      try schema.insertAndCheck(name: relationshipName)
    } catch {
      preconditionFailure()
    }
    
    schema.versions[version, default: Version()].relationships.append(SchemaRelationship(name: relationshipName, reference: reference, version: version))
    
    return schema
  }
  
  private func statement(for version: Version, isFirstVersion: Bool) -> [String] {
    var columnDefinitions = [String]()
    
    if isFirstVersion {
      columnDefinitions.append("id TEXT NOT NULL PRIMARY KEY")
    }
    
    for property in version.properties {
      columnDefinitions.append("\(property.name) \(property.type.rawValue)")
    }
    
    if isFirstVersion {
      for relationship in version.relationships {
        columnDefinitions.append("\(relationship.name) TEXT REFERENCES \(relationship.reference)(id)")
      }
    }
    
    if isFirstVersion {
      return ["CREATE TABLE \(name)(\(columnDefinitions.joined(separator: ",\n    ")))"]
    } else {
      return columnDefinitions.map {
        "ALTER TABLE \(name) ADD COLUMN \($0)"
      }
    }
  }
  
  func matchesSchema(_ entity: ReplicatingEntity) -> Bool {
    Set(entity.fields.keys) == self.usedNames
  }
  
  func statementsToRun(currentVersion: Int64 = 0) -> [String] {
    var statements = [String]()
    let sortedVersions = versions.sorted { item0, item1 in
      item0.key < item1.key
    }
    
    var isFirstVersion = true
    for (versionNumber, version) in sortedVersions {
      if versionNumber > currentVersion {
        statements.append(contentsOf: statement(for: version, isFirstVersion: isFirstVersion))
      }
      isFirstVersion = false
    }
    
    return statements
  }
  
  func insertStatement() -> String {
    let columns = versions.values.flatMap { version in
      version.properties.map { $0.name } + version.relationships.map { $0.name }
    }
    
    let insertColumns = columns.joined(separator: ",")
    let valueColumns = columns.map{ ":\($0)" }.joined(separator: ",")
    
    return "INSERT INTO \(name)(\(insertColumns)) VALUES (\(valueColumns))"
  }
}
