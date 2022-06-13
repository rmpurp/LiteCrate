//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public protocol DatabaseCodable: Codable {
  static var tableName: String { get }
  var tableName: String { get }
  static var primaryKeyColumn: String { get }
  static var foreignKeys: [ForeignKey] { get }
}

public extension DatabaseCodable {
  static var tableName: String { String(describing: Self.self) }
  static var primaryKeyColumn: String { "id" }
  static var foreignKeys: [ForeignKey] { [] }

  var tableName: String { Self.tableName }
  
  internal var creationStatement: String {
    let encoder = SchemaEncoder()
    try! self.encode(to: encoder)
    
    let opening = "CREATE TABLE \(Self.tableName) (\n"
    var components = [String]()
    let ending = "\n);"
    
    let sortedColumns = encoder.columns.sorted {
      if $0.key == Self.primaryKeyColumn { return true }
      if $1.key == Self.primaryKeyColumn { return false }
      return $0.key < $1.key
    }
    
    components.append(contentsOf: sortedColumns.map{ "\($0) \($1.rawValue)" })
    components.append("PRIMARY KEY (\(Self.primaryKeyColumn))")
    components.append(contentsOf: Self.foreignKeys.map(\.creationStatement))
    return opening + components.map {"    " + $0}.joined(separator: ",\n") + ending
  }
}

public struct ForeignKey {
  public var columnName: String
  public var targetTable: String
  public var targetColumn: String
  public var onDeleteCascade: Bool
  
  public init(_ columnName: String, references targetTable: String, targetColumn: String, onDeleteCascade: Bool = false) {
    self.columnName = columnName
    self.targetColumn = targetColumn
    self.targetTable = targetTable
    self.onDeleteCascade = onDeleteCascade
  }
  
  fileprivate var creationStatement: String {
    return "FOREIGN KEY (\(columnName)) REFERENCES \(targetTable)(\(targetColumn)" + (self.onDeleteCascade ? " ON DELETE CASCADE" : "")
  }
}
