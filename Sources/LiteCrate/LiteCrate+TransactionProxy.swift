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
    public func createTable<T: DatabaseCodable>(_ modelInstance: T) throws {
      try self.execute(modelInstance.creationStatement)
    }

    public func fetch<T: DatabaseCodable, U: SqliteRepresentable>(_ type: T.Type, with primaryKey: U) throws -> T? {
      return try fetch(type, allWhere: "\(T.primaryKeyColumn) = ?", [primaryKey]).first
    }

    public func fetch<T: DatabaseCodable>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, _ values: [SqliteRepresentable?] = []) throws -> [T] {
      let sqlWhereClause = sqlWhereClause ?? "TRUE"
      let cursor = try db.query("SELECT * FROM \(T.tableName) WHERE \(sqlWhereClause)", values)
      let decoder = DatabaseDecoder(cursor: cursor)
      var models = [T]()
      while cursor.step() {
        try models.append(T(from: decoder))
      }
      return models
    }

    public func fetch<T: DatabaseCodable>(_ type: T.Type, joining joinTable: String, on joinClause: String, allWhere sqlWhereClause: String? = nil, _ values: [SqliteRepresentable?] = []) throws -> [T] {
      let sqlWhereClause = sqlWhereClause ?? "TRUE"
      let cursor = try db.query("SELECT \(T.tableName).* FROM \(T.tableName) INNER JOIN \(joinTable) ON \(joinClause) WHERE \(sqlWhereClause)", values)
      let decoder = DatabaseDecoder(cursor: cursor)
      var models = [T]()
      while cursor.step() {
        try models.append(T(from: decoder))
      }
      return models
    }

    public func execute(_ sql: String, _ values: [SqliteRepresentable?] = []) throws {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      try db.execute(sql, values)
    }

    public func query(_ sql: String, _ values: [SqliteRepresentable?] = []) throws -> Cursor {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      return try db.query(sql, values)
    }
    
    func beginTransaction() throws {
      try db.beginTransaction()
      try fetchTime()
    }
    
    private func updateDot<T: ReplicatingModel>(_ model: T) throws {
      needToIncrementTime = true
      
      if var dot = try fetch(Dot<T>.self,
                               allWhere: "modelID = ? ORDER BY timeCreated DESC LIMIT 1",
                             [model.primaryKeyValue]).first {
        dot.timeLastModified = time
        dot.lastModifier = node
        dot.timeLastWitnessed = time
        dot.witness = node
        try save(dot)
      } else {
        let dot = Dot<T>(modelID: model.primaryKeyValue, time: time, creator: node)
        try save(dot)
      }
    }

    public func save<T: DatabaseCodable>(_ model: T) throws {
      if let model = model as? any ReplicatingModel {
        try updateDot(model)
      }

      let encoder = DatabaseEncoder(tableName: T.tableName)
      try model.encode(to: encoder)
      let (insertStatement, values) = encoder.insertStatement
      try db.execute(insertStatement, values)
    }

    public func delete<T: DatabaseCodable, U: SqliteRepresentable>(_ type: T.Type, with primaryKey: U) throws {
      try db.execute("DELETE FROM \(T.tableName) WHERE id = ?", [primaryKey])
    }

    public func delete<T: DatabaseCodable>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, _ values: [SqliteRepresentable?] = []) throws {
      let sqlWhereClause = sqlWhereClause.flatMap { "WHERE \($0)" } ?? ""
      try db.execute("DELETE FROM \(T.tableName) \(sqlWhereClause)", values)
    }

    internal var db: Database
    internal var isEnabled = true

    private var time: Int64!
    private var needToIncrementTime = false
    
    private func fetchTime() throws {
      var cursor = try query("SELECT time FROM Node WHERE id = ?", [node])
      if cursor.step() {
        time = cursor.int(for: 0)
      }
      
      cursor = try query("SELECT COALESCE(max(time), 0) FROM Node")
      guard cursor.step() else { fatalError() } // Should be impossible. Though TODO: change this to a throw LOL
      time = cursor.int(for: 0)
    }
    
    func incrementTimeIfNeeded() throws  {
      if needToIncrementTime {
        try execute("INSERT OR REPLACE INTO Node(id, time) VALUES (?, ?)", [node, time + 1])
      }
    }
    
    internal var node: UUID

    internal init(db: Database, node: UUID) {
      self.db = db
      self.node = node
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
    try execute(String(format: "PRAGMA user_version = %lld", version), [])
    // Being very careful to avoid injection vulnerability; ? is not valid here.
  }
}