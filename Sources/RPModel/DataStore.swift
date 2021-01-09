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

public class DataStore {
  private var db: FMDatabase!
  

  internal let tableChangedPublisher = PassthroughSubject<String, Never>()
  internal let queue: DispatchQueue = DispatchQueue(
    label: "RPModelDispatchQueue",
    qos: .userInteractive,
    attributes: [],
    autoreleaseFrequency: .workItem,
    target: nil)

  public init(url: URL?, migration: (FMDatabase, inout Int64) throws -> Void) {

    db = FMDatabase(url: url)
    db.open()

    let raw = Unmanaged.passUnretained(self).toOpaque()

    sqlite3_update_hook(
      OpaquePointer(db.sqliteHandle),
      { (aux, type, cDatabaseName, cTableName, rowid) in
        guard let cTableName = cTableName, let aux = aux else { return }

        let dataStore = Unmanaged<DataStore>.fromOpaque(aux).takeUnretainedValue()

        let tableName = String(cString: cTableName)
        dataStore.queue.async {
          dataStore.tableChangedPublisher.send(tableName)
        }
      }, raw)

    inTransactionSync { db in
        var currentVersion = try getCurrentSchemaVersion()
        try migration(db, &currentVersion)
        try setCurrentSchemaVersion(version: currentVersion)
      }
  }

  public func closeDatabase() {
    queue.sync {
      _ = db?.close()
    }
    db = nil
  }
  
  private var isInTransaction = false
  
  internal func inTransactionSync(operation: (FMDatabase) throws -> Void) {
    queue.sync {
      isInTransaction = true
      defer { isInTransaction = false }
      do {
      try operation(db)
      } catch {
        db.rollback()
      }
    }
  }

  internal func inTransaction(operation: @escaping (FMDatabase) throws -> Void) {
    queue.async { [db] in
      guard let db = db else { return }
      db.beginTransaction()
      do {
      try operation(db)
        db.commit()
      } catch {
        db.rollback()
      }
    }
  }

  private func getCurrentSchemaVersion() throws -> Int64 {
    dispatchPrecondition(condition: .onQueue(queue))

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

  private func setCurrentSchemaVersion(version: Int64) throws {
    dispatchPrecondition(condition: .onQueue(queue))
    try db.executeUpdate("DELETE FROM schema", values: nil)
    try db.executeUpdate("INSERT INTO schema VALUES (?)", values: [version])
  }

}
