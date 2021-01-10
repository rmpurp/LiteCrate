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
  var db: FMDatabase!

  internal let tableChangedPublisher = PassthroughSubject<String, Never>()
  
  internal let queue: DispatchQueue = DispatchQueue(
    label: "RPModelDispatchQueue",
    qos: .userInteractive,
    attributes: [],
    autoreleaseFrequency: .workItem,
    target: nil)

  let testQueueKey = DispatchSpecificKey<Void>()
  
  var isOnQueue: Bool { DispatchQueue.getSpecific(key: testQueueKey) != nil }
  var tablesToSignal = Set<String>()
  
  public init(url: URL?, migration: (FMDatabase, inout Int64) throws -> Void) rethrows {
    queue.setSpecific(key: testQueueKey, value: ())

    db = FMDatabase(url: url)
    db.open()
    
    let raw = Unmanaged.passUnretained(self).toOpaque()

    sqlite3_update_hook(
      OpaquePointer(db.sqliteHandle),
      { (aux, type, cDatabaseName, cTableName, rowid) in
        guard let cTableName = cTableName, let aux = aux else { return }

        let dataStore = Unmanaged<DataStore>.fromOpaque(aux).takeUnretainedValue()

        let tableName = String(cString: cTableName)
        dataStore.tablesToSignal.insert(tableName)
      }, raw)

    try transact { db in
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
  
  public func inTransaction(operation: (FMDatabase) throws -> Void) rethrows {
    do {
      db.beginTransaction()
      try operation(db)
      db.commit()
      // Copy so they don't get wiped out by race condition
      let tablesToSignal = self.tablesToSignal
      queue.async { [weak self] in
        guard let self = self else { return }
        tablesToSignal.forEach {
          self.tableChangedPublisher.send($0)
        }
      }
    } catch {
      db.rollback()
    }
    tablesToSignal = []
  }
    
  public func transact(operation: (FMDatabase) throws -> Void) rethrows {
    if isOnQueue {
      try inTransaction(operation: operation)
    } else {
      try queue.sync { try inTransaction(operation: operation) }
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
