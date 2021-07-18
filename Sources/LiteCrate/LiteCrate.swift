//
//  RPModelDatabase.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import FMDB
import Foundation
import SQLite3


enum LiteCrateError: Error {
  case commitError
}

public actor LiteCrate {
  
  private var db: FMDatabase
  private var tablesToSignalWrapper = TablesToSignalWrapper()
  private var notifier = Notifier()
  
  init(url: URL?, migration: (TransactionProxy, inout Int64) throws -> Void) throws {
    db = FMDatabase(url: url)
    db.open()
    
    try inTransaction { db in
      var currentVersion = try db.getCurrentSchemaVersion()
      try migration(db, &currentVersion)
      try db.setCurrentSchemaVersion(version: currentVersion)
    }
    
    self.tablesToSignalWrapper = TablesToSignalWrapper()
    let raw = Unmanaged.passUnretained(self.tablesToSignalWrapper).toOpaque()
    
    sqlite3_update_hook(
      OpaquePointer(db.sqliteHandle),
      { (aux, type, cDatabaseName, cTableName, rowid) in
        guard let cTableName = cTableName, let aux = aux else { return }
        
        let notifier = Unmanaged<TablesToSignalWrapper>.fromOpaque(aux).takeUnretainedValue()
        
        let tableName = String(cString: cTableName)
        
        notifier.insert(tableName)
      }, raw)
  }
  
  func close() {
    db.close()
  }
  
  func stream<T: LCModel>(for type: T.Type, where sqlWhereClause: String? = nil, values: [Any]? = nil) -> AsyncThrowingStream<[T], Error> {
    let sqlWhereClause = sqlWhereClause ?? "1=1"
    
    let localNotifier = notifier // Notifier has internal synchronization
    
    // Force a fetch immediately
    defer { notifier.notify(type.tableName) }
    
    return AsyncThrowingStream { continuation in
      let subscription = notifier.subscribe(for: type.tableName)
      subscription.myAction = {
        do {
          try continuation.yield(self.fetch(T.self, allWhere: sqlWhereClause, values: values))
        } catch {
          continuation.finish(throwing: error)
        }
      }
      
      continuation.onTermination = { @Sendable termination in
        localNotifier.unsubscribe(subscription)
      }
    }
  }
  
  func inTransaction<T>(block: (TransactionProxy) throws -> T) throws -> T {
    let proxy = TransactionProxy(db: db)
    
    defer { proxy.isEnabled = false }
    
    tablesToSignalWrapper.clear()
    
    do {
      proxy.db.beginTransaction()
      
      let returnValue = try block(proxy)
      let success = proxy.db.commit()
      proxy.isEnabled = false
      if !success { throw LiteCrateError.commitError }
      
      for table in tablesToSignalWrapper.tablesToSignal {
        lc_log("Notifying changes in \(table)")
        notifier.notify(table)
      }
      
      return returnValue
    } catch {
      proxy.db.rollback()
      throw error
    }
  }
}

// MARK: - CRUD
extension LiteCrate {
  public func executeUpdate(_ sql: String, values: [Any]? = nil) throws {
    try inTransaction { proxy in
      try proxy.executeUpdate(sql, values: values)
    }
  }
  
  public func executeQuery(_ sql: String, values: [Any]? = nil) throws -> FMResultSet {
    try inTransaction { proxy in
      try proxy.executeQuery(sql, values: values)
    }
  }
  
  public func executeQuery<T>(_ sql: String, values: [Any]? = nil, transformOutput: (FMResultSet) throws -> T) throws -> T {
    try inTransaction { proxy in
      try proxy.executeQuery(sql, values: values, transformOutput: transformOutput)
    }
  }
  
  public func save<T>(_ model: T) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.save(model)
    }
  }
  
  
  public func fetch<T>(_ type: T.Type, with id: T.ID) throws -> T? where T : LCModel {
    try inTransaction { proxy in
      try proxy.fetch(type, with: id)
    }
  }
  
  public func fetch<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws -> [T] where T : LCModel {
    try inTransaction { proxy in
      try proxy.fetch(type, allWhere: sqlWhereClause, values: values)
    }
  }
  
  public func delete<T>(_ model: T) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.delete(model)
    }
  }
  
  
  public func delete<T>(_ type: T.Type, with id: T.ID) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.delete(type, with: id)
    }
  }
  
  public func delete<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.delete(type, allWhere: sqlWhereClause, values: values)
    }
  }
}
