//
//  File.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import Combine
import FMDB
import Foundation

public protocol LCModel: Identifiable, Equatable, Codable where ID == UUID {
  
  override var id: ID { get set }
  //  var everSynced: Bool { get set }
  //  var isDirty: Bool { get set }
  static var foreignKeys: [ForeignKey] { get }
}

extension LCModel {
  internal var insertValues: (columnString: String, placeholders: String, values: [Any]) {
    let encoder = DatabaseEncoder()
    try! self.encode(to: encoder)
    let columnsToValue = encoder.columnToKey
    // If there is an error here, it will be caught and resolved during developement
    
    let columns = [String](columnsToValue.keys)
    let columnString = columns.joined(separator: ",")
    let placeholders = String(String(repeating: "?,", count: columnsToValue.count).dropLast())
    let values = columns.map { columnsToValue[$0]! }
    return (columnString, placeholders, values)
  }
  
  internal var creationStatement: String {
    let encoder = SchemaEncoder()
    try! self.encode(to: encoder)
    
    let opening = "CREATE TABLE \(Self.tableName) (\n"
    var components = [String]()
    let ending = "\n);"
    
    components.append(contentsOf: encoder.columns.map{ "\($0.key) \($0.value.rawValue)" })
    components.append("PRIMARY KEY (id)")
    components.append(contentsOf: Self.foreignKeys.map(\.creationStatement))
    return opening + components.map {"    " + $0}.joined(separator: ",\n") + ending
  }
  
  public static var tableName: String { String(describing: Self.self) }
  public static var foreignKeys: [ForeignKey] { [] }
}

public struct ForeignKey {
  public var columnNames: [String]
  public var targetTable: String
  public var targetColumns: [String]
  public var onCascadeDelete: Bool
  
  public init(_ columnNames: [String], references targetTable: String, targetColumns: [String], onCascadeDelete: Bool = false) {
    self.columnNames = columnNames
    self.targetColumns = targetColumns
    self.targetTable = targetTable
    self.onCascadeDelete = onCascadeDelete
  }

  public init(_ columnName: String, references targetTable: String, targetColumn: String, onCascadeDelete: Bool = false) {
    self.columnNames = [columnName]
    self.targetColumns = [targetColumn]
    self.targetTable = targetTable
    self.onCascadeDelete = onCascadeDelete
  }
  
  fileprivate var creationStatement: String {
    return "FOREIGN KEY (\(columnNames.joined(separator: ", "))) REFERENCES \(targetTable)(\(targetColumns.joined(separator: ", ")))" + (self.onCascadeDelete ? " ON CASCADE DELETE" : "")
  }
}
