//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import LiteCrateCore

public final class TransactionProxy {
  public func fetch<T: DatabaseCodable, U: SqliteRepresentable>(_ type: T.Type, with primaryKey: U) throws -> T? {
    try fetch(type, where: "\(T.table.primaryKeyColumn) = ?", [primaryKey]).first
  }

  public func fetchIgnoringDelegate<T: DatabaseCodable, U: SqliteRepresentable>(_ type: T.Type,
                                                                                with primaryKey: U) throws -> T?
  {
    try fetchIgnoringDelegate(type, where: "\(T.table.primaryKeyColumn) = ?", [primaryKey]).first
  }

  public func fetch<T: DatabaseCodable>(_: T.Type, where sqlWhereClause: String? = nil,
                                        _ values: [SqliteRepresentable?] = []) throws -> [T]
  {
    let sqlWhereClause = sqlWhereClause ?? "TRUE"

    let cursor = try db.query(T.table.selectStatement(where: sqlWhereClause), values)
    let decoder = DatabaseDecoder(cursor: cursor)
    var models = [T]()
    while cursor.step() {
      let model = try T(from: decoder)
      models.append(model)
    }
    return models
  }

  public func fetchIgnoringDelegate<T: DatabaseCodable>(_: T.Type, where _: String? = nil,
                                                        _: [SqliteRepresentable?] = []) throws -> [T]
  {
    fatalError()
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
    let encoder = DatabaseEncoder(tableName: T.table.tableName)
    try model.encode(to: encoder)
    let (insertStatement, values) = encoder.insertStatement
    try db.execute(insertStatement, values)
  }

  public func delete<T: DatabaseCodable>(_: T) throws {
    fatalError()
    #warning("fix me")
  }

  public func delete<T: DatabaseCodable, U: SqliteRepresentable>(_: T.Type, with primaryKey: U) throws {
    guard let model = try fetch(T.self, with: primaryKey) else { return }
    try delete(model)
  }

  public func deleteIgnoringDelegate<T: DatabaseCodable>(_: T.Type, where sqlWhereClause: String? = nil,
                                                         _ values: [SqliteRepresentable?] = []) throws
  {
    let sqlWhereClause = sqlWhereClause.flatMap { "WHERE \($0)" } ?? ""
    try db.execute("DELETE FROM \(T.table.tableName) \(sqlWhereClause)", values)
  }

  internal var db: Database
  internal var isEnabled = true

  internal init(db: Database) {
    self.db = db
  }
}

internal extension TransactionProxy {
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
