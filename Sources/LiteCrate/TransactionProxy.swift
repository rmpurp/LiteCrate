//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import LiteCrateCore

public final class TransactionProxy {
  let nodeID = UUID() // TODO: Fix me.

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

  public func save() throws {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }

  }

  public func fetch<T>(_ entityType: String, type: T.Type, with id: UUID) throws -> T?
    where T: Codable & Identifiable, T.ID == UUID
  {
    try fetch(entityType, type: type, predicate: "id = ?", [id]).first
  }


  public func fetch<T>(_ entityType: String, type _: T.Type, predicate: String = "TRUE",
                       _ values: [SqliteRepresentable?] = []) throws -> [T]
    where T: Codable & Identifiable, T.ID == UUID
  {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }
    return []
  }

  public func fetch(_ entityType: String, predicate: String = "TRUE",
                    _ values: [SqliteRepresentable?] = []) throws -> [String]
  {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }
    return []
  }

  public func delete<T: Codable>(_: T) throws {
  }


  public func delete<T: Codable>(_: T, where sqlWhereClause: String = "TRUE",
                                         _ values: [SqliteRepresentable?] = []) throws
  {
//    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(sqlWhereClause)", values)
  }

  public func delete<T: Codable, U: SqliteRepresentable>(_: T.Type, with primaryKey: U) throws {
//    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(T.table.primaryKeyColumn) = ?", [primaryKey])
  }

  internal var liteCrate: LiteCrate
  internal var TEMPsequenceNumber: Int64 = 0
  internal var db: Database
  internal var isEnabled = true

  internal init(liteCrate: LiteCrate, database: Database) {
    self.liteCrate = liteCrate
    db = database
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
