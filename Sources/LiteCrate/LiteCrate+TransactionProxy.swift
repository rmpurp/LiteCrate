//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import LiteCrateCore

public extension LiteCrate {
  final class TransactionProxy {
    public func fetch<T: DatabaseCodable, U: SqliteRepresentable>(_ type: T.Type, with primaryKey: U) throws -> T? {
      try fetch(type, allWhere: "\(T.primaryKeyColumn) = ?", [primaryKey]).first
    }

    public func fetchIgnoringDelegate<T: DatabaseCodable, U: SqliteRepresentable>(_ type: T.Type,
                                                                                  with primaryKey: U) throws -> T?
    {
      try fetchIgnoringDelegate(type, allWhere: "\(T.primaryKeyColumn) = ?", [primaryKey]).first
    }

    public func fetch<T: DatabaseCodable>(_: T.Type, allWhere sqlWhereClause: String? = nil,
                                          _ values: [SqliteRepresentable?] = []) throws -> [T]
    {
      let sqlWhereClause = sqlWhereClause ?? "TRUE"

      let cursor = try db.query("\(selectStatement(T.self)) WHERE \(sqlWhereClause)", values)
      let decoder = DatabaseDecoder(cursor: cursor)
      var models = [T]()
      while cursor.step() {
        let model = try T(from: decoder)
        if let delegate {
          if try delegate.filter(model: model) {
            models.append(model)
          }
        } else {
          models.append(model)
        }
      }
      return models
    }

    public func fetchIgnoringDelegate<T: DatabaseCodable>(_: T.Type, allWhere sqlWhereClause: String? = nil,
                                                          _ values: [SqliteRepresentable?] = []) throws -> [T]
    {
      let sqlWhereClause = sqlWhereClause ?? "TRUE"
      let cursor = try db.query("\(selectStatement(T.self)) WHERE \(sqlWhereClause)", values)
      let decoder = DatabaseDecoder(cursor: cursor)
      var models = [T]()
      while cursor.step() {
        models.append(try T(from: decoder))
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

    public func save<T: DatabaseCodable>(_ model: T) throws {
      let model = try delegate?.proxy(self, willSave: model) ?? model
      try saveIgnoringDelegate(model)
    }

    /// Save the given model, bypassing any processing by the delegate.
    public func saveIgnoringDelegate<T: DatabaseCodable>(_ model: T) throws {
      let encoder = DatabaseEncoder(tableName: T.exampleInstance.tableName)
      try model.encode(to: encoder)
      let (insertStatement, values) = encoder.insertStatement
      try db.execute(insertStatement, values)
    }

    public func delete<T: DatabaseCodable>(_ model: T) throws {
      if let model = try delegate?.proxy(self, willDelete: model) {
        try saveIgnoringDelegate(model)
      } else {
        try deleteIgnoringDelegate(model)
      }
    }

    public func deleteIgnoringDelegate<T: DatabaseCodable>(_ model: T) throws {
      try db.execute(
        "DELETE FROM \(T.exampleInstance.tableName) WHERE \(T.primaryKeyColumn) = ?",
        [model.primaryKeyValue]
      )
    }

    public func delete<T: DatabaseCodable, U: SqliteRepresentable>(_: T.Type, with primaryKey: U) throws {
      guard let model = try fetch(T.self, with: primaryKey) else { return }
      try delete(model)
    }

    public func deleteIgnoringDelegate<T: DatabaseCodable>(_: T.Type, allWhere sqlWhereClause: String? = nil,
                                                           _ values: [SqliteRepresentable?] = []) throws
    {
      let sqlWhereClause = sqlWhereClause.flatMap { "WHERE \($0)" } ?? ""
      try db.execute("DELETE FROM \(T.exampleInstance.tableName) \(sqlWhereClause)", values)
    }

    public func delete<T: DatabaseCodable>(_: T.Type, allWhere sqlWhereClause: String? = nil,
                                           _ values: [SqliteRepresentable?] = []) throws
    {
      let models = try fetch(T.self, allWhere: sqlWhereClause, values)
      for model in models {
        try delete(model)
      }
    }

    internal var db: Database
    internal var isEnabled = true

    private var delegate: (any LiteCrateDelegate)?
    internal init(db: Database, delegate: (any LiteCrateDelegate)?) {
      self.db = db
      self.delegate = delegate
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

internal extension LiteCrate.TransactionProxy {
  /// For the given table, get a String of the format `SELECT col1 AS col1,col2 AS col2,... FROM tableName`
  private func selectStatement<T: DatabaseCodable>(_: T.Type) throws -> String {
    let encoder = SchemaEncoder(T.exampleInstance)
    try T.exampleInstance.encode(to: encoder)
    return encoder.selectStatement
  }
}
