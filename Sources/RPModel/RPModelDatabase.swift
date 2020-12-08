//
//  RPModelDatabase.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import Combine
import FMDB
import Foundation
import SQLite3

public class RPModelDatabase {
  private static var db: FMDatabase!

  internal static let tableChangedPublisher = PassthroughSubject<String, Never>()
  internal static let queue: DispatchQueue = DispatchQueue(
    label: "RPModelDispatchQueue",
    qos: .userInteractive,
    attributes: [],
    autoreleaseFrequency: .workItem,
    target: nil)

  public static func openDatabase(
    at url: URL?, migration: @escaping (FMDatabase, inout Int64) throws -> Void
  ) {

    db = FMDatabase(url: url)
    db.open()

    sqlite3_update_hook(
      OpaquePointer(db.sqliteHandle),
      { (aux, type, cDatabaseName, cTableName, rowid) in
        guard let cTableName = cTableName else { return }
        let tableName = String(cString: cTableName)
        RPModelDatabase.queue.async {
          RPModelDatabase.tableChangedPublisher.send(tableName)
        }
      }, nil)

    inTransaction(
      operation: { db in
        var currentVersion = try getCurrentSchemaVersion(db: db)
        try migration(db, &currentVersion)
        try setCurrentSchemaVersion(version: currentVersion, database: db)
      }, waitUntilComplete: true)
  }

  public static func closeDatabase() {
    queue.sync {
      _ = db?.close()
    }
    db = nil
  }

  internal static func inTransaction(
    operation: @escaping (FMDatabase) throws -> Void, waitUntilComplete: Bool = false
  ) {
    inDatabase(
      operation: { db in
        db.beginDeferredTransaction()
        do {
          try operation(db)
        } catch {
          db.rollback()
        }
        db.commit()
      }, waitUntilComplete: waitUntilComplete)
  }

  /// Runs the given closure on the DB queue.
  /// If you are already on the queue, this is always synchronous regardless of waitUntilComplete.
  /// - Parameters:
  ///   - operation: operation to perform
  ///   - waitUntilComplete: whether to wait until the operation is complete
  internal static func inDatabase(
    operation: @escaping (FMDatabase) -> Void, waitUntilComplete: Bool = false
  ) {
    if Thread.isMainThread {
      if waitUntilComplete {
        queue.sync {
          operation(db)
        }
      } else {
        queue.async {
          operation(db)
        }
      }
    } else {
      operation(db)
    }
  }

  private static func getCurrentSchemaVersion(db: FMDatabase) throws -> Int64 {
    try db.executeUpdate(
      "CREATE TABLE IF NOT EXISTS schema(version INTEGER)", values: nil)

    let rs = try db.executeQuery(
      "SELECT version AS dbVersion FROM schema",
      values: nil)

    var currentVersion: Int64 = -1
    while rs.next() {
      currentVersion = rs.longLongInt(forColumn: "dbVersion")
    }

    NSLog("DB at version %d", currentVersion)
    return currentVersion
  }

  private static func setCurrentSchemaVersion(version: Int64, database: FMDatabase) throws {
    try database.executeUpdate("DELETE FROM schema", values: nil)
    try database.executeUpdate("INSERT INTO schema VALUES (?)", values: [version])
  }

}
