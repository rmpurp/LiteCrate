//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import FMDB

extension LiteCrate {
  public final class TransactionProxy {
    public func fetch<T>(_ type: T.Type, with id: T.ID) throws -> T? where T : LCModel {
      return try fetch(type, allWhere: "id = ?", values: [id]).first
    }
    
    public func fetch<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws  -> [T] where T : LCModel {
      let sqlWhereClause = sqlWhereClause ?? "1=1"
      let resultSet = try db.executeQuery("SELECT * FROM \(T.tableName) WHERE \(sqlWhereClause)", values: values)
      let decoder = DatabaseDecoder(resultSet: resultSet)
      var models = [T]()
      while resultSet.next() {
        try models.append(T(from: decoder))
      }
      return models
    }
    
    public func executeUpdate(_ sql: String, values: [Any]? = nil) throws {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      try db.executeUpdate(sql, values: values)
    }
    
    public func executeQuery<T>(_ sql: String, values: [Any]? = nil, transformOutput: (FMResultSet) throws -> T) throws -> T {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      let rs = try db.executeQuery(sql, values: values)
      defer { rs.close() }
      return try transformOutput(rs)
    }
    
    public func executeQuery(_ sql: String, values: [Any]? = nil) throws -> FMResultSet {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      return try db.executeQuery(sql, values: values)
    }
    
    
    public func save<T>(_ model: T) throws where T : LCModel {
      let (columnString, placeholders, values) = model.insertValues
      try db.executeUpdate(
        "INSERT OR REPLACE INTO \(T.tableName)(\(columnString)) VALUES (\(placeholders)) ",
        values: values)
    }
    
    public func delete<T>(_ model: T) throws where T : LCModel {
      try db.executeUpdate("DELETE FROM \(T.tableName) WHERE id = ?", values: [model.id])
    }
    
    public func delete<T: LCModel>(_ type: T.Type, with id: T.ID) throws {
      try db.executeUpdate("DELETE FROM \(T.tableName) WHERE id = ?", values: [id])
    }
    
    public func delete<T: LCModel>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws {
      let sqlWhereClause = sqlWhereClause.flatMap { "WHERE \($0)" } ?? ""
      try db.executeUpdate("DELETE FROM \(T.tableName) \(sqlWhereClause)", values: values)
    }
    
    internal var db: FMDatabase
    internal var isEnabled = true
    
    internal init(db: FMDatabase) {
      self.db = db
    }
  }
}

internal extension LiteCrate.TransactionProxy {
  func getCurrentSchemaVersion() throws -> Int64 {
    let rs = try executeQuery("PRAGMA user_version", values: nil)
    
    if rs.next() {
      let currentVersion = rs.longLongInt(forColumnIndex: 0)
      NSLog("DB at version %d", currentVersion)
      return currentVersion
    } else {
      fatalError("TODO: Change this to reasonable error")
    }
  }
  
  func setCurrentSchemaVersion(version: Int64) throws {
    try executeUpdate(String(format: "PRAGMA user_version = %lld", version), values: [])
    // Being very careful to avoid injection vulnerability; ? is not valid here.
  }
}
