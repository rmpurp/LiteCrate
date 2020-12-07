//
//  File.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import Foundation
import FMDB

public protocol RPModel: Identifiable {
  init()
  override var id: ID { get set }
}

private func extract (propertyName: String, as sqlType: SQLType, resultSet: FMResultSet) -> Any {
  let column = propertyName
  
  switch sqlType {
  case .bool: return resultSet.bool(forColumn: column)
  case .string: return resultSet.string(forColumn: column) as Any
  case .double: return resultSet.double(forColumn: column)
  case .int: return resultSet.long(forColumn: column)
  case .int32: return resultSet.int(forColumn: column)
  case .int64: return resultSet.longLongInt(forColumn: column)
  case .uint64: return resultSet.unsignedLongLongInt(forColumn: column)
  case .date: return resultSet.date(forColumn: column) as Any
  case .uuid:
    guard let fetchedUUIDString = resultSet.string(forColumn: column) else {
      return UUID?.none as Any
    }
    guard let uuid = UUID(uuidString: fetchedUUIDString) else {
      fatalError("Malformed database: incorrect UUID")
      // TODO: Change to some sort of exception.
    }
    return uuid
  }
}

public extension RPModel {
  static var tableName: String { String(describing: Self.self) }
  
  static func fetch(with primaryKey: ID) -> Self? {
    return Self.fetchAll(forAllWhere: "id = ?", values: [primaryKey]).first
  }
  
  
  
  
  fileprivate mutating func populate(resultSet: FMResultSet) {
    for (name, column) in namedColumns {
      let val = extract(propertyName: name, as: column.sqlType, resultSet: resultSet)
      column.unsafeSetRefValue(to: val)
    }
  }
  
  private var namedColumns: AnyIterator<(name: String, column: ColumnProtocol)> {
    let mirror = Mirror(reflecting: self)
    let columnIterator = mirror.children.lazy
      .map { child -> (name: String, column: ColumnProtocol)? in
        guard let column = child.value as? ColumnProtocol,
              let name = child.label?.dropFirst()
        else { return nil }
        return (column.key ?? String(name), column)
      }
      .compactMap { $0 }
      .makeIterator()
    return AnyIterator(columnIterator)
  }
  
  /// Blocking call to fetch
  static func fetchAll(forAllWhere sqlWhereClause: String? = nil, values: [Any]? = nil)
  -> [Self]
  {
    // TODO: Properly rewrite query if where clause is null
    let sqlWhereClause = sqlWhereClause ?? "1=1"
    var returnValue = [Self]()
    
    
    RPModelDatabase.inDatabase(
      operation: { db in
        guard
          let rs = try? db.executeQuery(
            "SELECT * FROM \(Self.tableName) WHERE \(sqlWhereClause)",
            values: values)
        else {
          return
        }
        
        while rs.next() {
          var model = Self()
          model.populate(resultSet: rs)
          returnValue.append(model)
        }
      }
      , waitUntilComplete: true)
    return returnValue
  }
}

public extension RPModel {
  func save(waitUntilComplete: Bool = false) where ID == Any? {
    fatalError("Only Int64? is allowed as optional id type")
  }
  
  mutating func save() where ID == Int64? {
    let (columnString, placeholders, values) = insertValues
    var insertedID: Int64? = nil
    RPModelDatabase.inDatabase(
      operation: { [id] (db) in
        try! db.executeUpdate(
          "INSERT OR REPLACE INTO \(Self.tableName)(\(columnString)) VALUES (\(placeholders)) ",
          values: values)
        if id == nil {
          insertedID = db.lastInsertRowId
        }
      }, waitUntilComplete: true)
    self.id = insertedID
  }
  
  private var insertValues: (columnString: String, placeholders: String, values: [Any]) {
    var columnsToValue = [String: Any]()
    for (name, column) in namedColumns {
      columnsToValue[name] = column.typeErasedValue()
    }
    
    let columns = [String](columnsToValue.keys)
    let columnString = columns.joined(separator: ",")
    let placeholders = String(String(repeating: "?,", count: columnsToValue.count).dropLast())
    let values = columns.map { columnsToValue[$0]! }
    return (columnString, placeholders, values)
  }
  
  func save() {
    let (columnString, placeholders, values) = insertValues

    RPModelDatabase.inDatabase(
      operation: { (db) in
        try! db.executeUpdate(
          "INSERT OR REPLACE INTO \(Self.tableName)(\(columnString)) VALUES (\(placeholders)) ",
          values: values)
        
      }, waitUntilComplete: true)
  }
  
  func delete() {
    RPModelDatabase.inDatabase(
      operation: { [id] db in
        try! db.executeUpdate("DELETE FROM \(Self.tableName) WHERE id = ?", values: [id])
        
      }, waitUntilComplete: true)
  }
}
