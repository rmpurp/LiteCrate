//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import LiteCrateCore

extension LiteCrate {
  public final class TransactionProxy {
    public func createTable<T>(_ modelInstance: T) throws where T : LCModel {
      try self.execute(modelInstance.creationStatement)
    }
    
    public func fetch<T>(_ type: T.Type, with id: T.ID) throws -> T? where T : LCModel {
      return try fetch(type, allWhere: "id = ?", [id]).first
    }
    
    public func fetch<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, _ values: [SqliteRepresentable?] = []) throws  -> [T] where T : LCModel {
      let sqlWhereClause = sqlWhereClause ?? "TRUE"
      let cursor = try db.query("SELECT * FROM \(T.tableName) WHERE \(sqlWhereClause)", values)
      let decoder = DatabaseDecoder(cursor: cursor)
      var models = [T]()
      while cursor.step() {
        try models.append(T(from: decoder))
      }
      return models
    }

    public func fetch<T>(_ type: T.Type, joining joinTable: String, on joinClause: String, allWhere sqlWhereClause: String? = nil, values: [SqliteRepresentable?] = []) throws  -> [T] where T : LCModel {
      let sqlWhereClause = sqlWhereClause ?? "TRUE"
      let cursor = try db.query("SELECT \(T.tableName).* FROM \(T.tableName) INNER JOIN \(joinTable) ON \(joinClause) WHERE \(sqlWhereClause)", values)
      let decoder = DatabaseDecoder(cursor: cursor)
      var models = [T]()
      while cursor.step() {
        try models.append(T(from: decoder))
      }
      return models

    }
      
    public func execute(_ sql: String, values: [SqliteRepresentable?] = []) throws {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      try db.execute(sql, values)
    }
    
    public func query(_ sql: String, values: [SqliteRepresentable?] = []) throws -> Cursor {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      return try db.query(sql, values)
    }
    
    
    public func save<T>(_ model: T) throws where T : LCModel {
      let encoder = DatabaseEncoder(tableName: T.tableName)
      try model.encode(to: encoder)
      let (insertStatement, values) = encoder.insertStatement
      try db.execute(insertStatement, values)
    }
    
    public func delete<T>(_ model: T) throws where T : LCModel {
      try db.execute("DELETE FROM \(T.tableName) WHERE id = ?", [model.id])
    }
    
    public func delete<T: LCModel>(_ type: T.Type, with id: T.ID) throws {
      try db.execute("DELETE FROM \(T.tableName) WHERE id = ?", [id])
    }
    
    public func delete<T: LCModel>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [SqliteRepresentable?] = []) throws {
      let sqlWhereClause = sqlWhereClause.flatMap { "WHERE \($0)" } ?? ""
      try db.execute("DELETE FROM \(T.tableName) \(sqlWhereClause)", values)
    }
    
    internal var db: Database
    internal var isEnabled = true
    
    internal init(db: Database) {
      self.db = db
    }
  }
}

internal extension LiteCrate.TransactionProxy {
  func getCurrentSchemaVersion() throws -> Int64 {
    let cursor = try query("PRAGMA user_version")
    
    if cursor.step() {
      let currentVersion = cursor.int(for: 0)
      NSLog("DB at version %d", currentVersion)
      return currentVersion
    } else {
      fatalError("TODO: Change this to reasonable error")
    }
  }
  
  func setCurrentSchemaVersion(version: Int64) throws {
    try execute(String(format: "PRAGMA user_version = %lld", version), values: [])
    // Being very careful to avoid injection vulnerability; ? is not valid here.
  }
}
