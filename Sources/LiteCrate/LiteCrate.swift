//
//  RPModelDatabase.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import FMDB
import Foundation
import SQLite3

public protocol CrateProxy {
  func executeUpdate(_ sql: String, values: [Any]?) throws
  func executeQuery(_ sql: String, values: [Any]?) throws -> FMResultSet
  func executeQuery<T>(_ sql: String, values: [Any]?, transformOutput: (FMResultSet) throws -> T) throws -> T
  func save<T: LCModel>(_ model: T) throws
  func delete<T: LCModel>(_ model: T) throws
  func delete<T: LCModel>(_ type: T.Type) throws
  func delete<T: LCModel>(_ type: T.Type, with id: T.ID) throws
  func delete<T: LCModel>(_ type: T.Type, allWhere sqlWhereClause: String?) throws
  func delete<T: LCModel>(_ type: T.Type, allWhere sqlWhereClause: String?, values: [Any]?) throws
  
  //  var lastInsertRowId: Int64 { get }
}

fileprivate extension CrateProxy {
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

enum LiteCrateError: Error {
  case commitError
}

@available(macOS 12.0, *)
public actor LiteCrate {

  private final class TablesToSignalWrapper {
    private var _tablesToSignal: Set<String> = []
    private var lock = NSLock()
    
    var tablesToSignal: Set<String> {
      let tables: Set<String>
      lock.lock()
      tables = _tablesToSignal
      lock.unlock()
      return tables
    }
    
    func insert(_ table: String) {
      lock.lock()
      _tablesToSignal.insert(table)
      lock.unlock()
    }
    
    func clear() {
      lock.lock()
      _tablesToSignal.removeAll()
      lock.unlock()
    }
  }
  
  private var db: FMDatabase
  private var tablesToSignalWrapper = TablesToSignalWrapper()
  private var notifier = Notifier()
  
  init(url: URL, migration: (CrateProxy, inout Int64) throws -> Void) throws {
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
        
        lc_log("TABLE NAME: %@", tableName)
        notifier.insert(tableName)
      }, raw)
  }
  
  func stream<T: LCModel>(for type: T.Type, where sqlWhereClause: String, values: [Any]? = nil) -> AsyncStream<[T]> {
    let statement = db.prepare(sqlWhereClause)
    guard values.flatMap(statement.bind(with:)) == true else { fatalError() }

    let localNotifier = notifier // Notifier has internal synchronization

    return AsyncStream { continuation in
      let subscription = notifier.subscribe(for: type.tableName, preparedStatement: statement)
      subscription.myAction = {
        statement.step()
        var models = [T]()
        let decoder = DatabaseDecoder(resultSet: statement)
        while statement.next() {
          try! models.append(T(from: decoder))
        }
        
        continuation.yield(models)
      }
      
      continuation.onTermination = { @Sendable termination in
        localNotifier.unsubscribe(subscription)
        statement.close()
      }
    }
  }
  
  func inTransaction<T>(block: (CrateProxy) throws -> T) throws -> T {
    let proxy = TransactionProxy(db: db)

    defer { proxy.isEnabled = false }
    
    do {
      proxy.db.beginTransaction()
      
      let returnValue = try block(proxy)
      let success = proxy.db.commit()
      if !success { throw LiteCrateError.commitError }
      
      for table in tablesToSignalWrapper.tablesToSignal {
        notifier.notify(table)
      }
      
      return returnValue
    } catch {
      proxy.db.rollback()
      throw error
    }
  }
  
}
//
//public final class LiteCrate {
//  public var lastInsertRowId: Int64 { db.lastInsertRowId }
//
//  private var db: FMDatabase!
//
//  private final class TransactionCrateProxy {
//    var db: FMDatabase
//    var isEnabled = true
//
//    init(db: FMDatabase) {
//      self.db = db
//    }
//
//    func executeUpdate(_ sql: String, values: [Any]?) throws {
//      guard isEnabled else {
//        fatalError("Do not use this proxy outside of the transaction closure")
//      }
//      try db.executeUpdate(sql, values: values)
//    }
//
//    func executeQuery<T>(_ sql: String, values: [Any]?, transformOutput: (FMResultSet) throws -> T) throws -> T {
//      guard isEnabled else {
//        fatalError("Do not use this proxy outside of the transaction closure")
//      }
//      let rs = try db.executeQuery(sql, values: values)
//      defer { rs.close() }
//      return try transformOutput(rs)
//    }
//
//    var lastInsertRowId: Int64 {
//      db.lastInsertRowId
//    }
//
//  }
//
//  internal let tableChangedPublisher = PassthroughSubject<String, Never>()
//
//  internal let queue: DispatchQueue = DispatchQueue(
//    label: "RPModelDispatchQueue",
//    qos: .userInteractive,
//    attributes: [],
//    autoreleaseFrequency: .workItem,
//    target: nil)
//
//  let testQueueKey = DispatchSpecificKey<Void>()
//  var isOnQueue: Bool { DispatchQueue.getSpecific(key: testQueueKey) != nil }
//  var tablesToSignal = Set<String>()
//
//  public func executeUpdate(_ sql: String, values: [Any]?) throws {
//    if isOnQueue { fatalError("Do not use the LiteCrate object in a transaction. Use the CrateProxy instead.") }
//    return try self.queue.sync {
//      try db.executeUpdate(sql, values: values)
//      notifyUpdates()
//    }
//  }
//
//  public func executeQuery<T>(_ sql: String, values: [Any]?, transformOutput: (FMResultSet) throws -> T) throws -> T {
//    if isOnQueue { fatalError("Do not use the LiteCrate object in a transaction. Use the CrateProxy instead.") }
//    return try self.queue.sync {
//      let rs = try db.executeQuery(sql, values: values)
//      defer { rs.close() }
//      return try transformOutput(rs)
//    }
//  }
//
//  let updateQueue: DispatchQueue
//
//  public init(
//    url: URL?, updateQueue: DispatchQueue = DispatchQueue.main,
//    migration: (CrateProxy, inout Int64) throws -> Void
//  ) rethrows {
//    queue.setSpecific(key: testQueueKey, value: ())
//    self.updateQueue = updateQueue
//    db = FMDatabase(url: url)
//    db.open()
//
//    let raw = Unmanaged.passUnretained(self).toOpaque()
//
//    sqlite3_update_hook(
//      OpaquePointer(db.sqliteHandle),
//      { (aux, type, cDatabaseName, cTableName, rowid) in
//      guard let cTableName = cTableName, let aux = aux else { return }
//
//      let liteCrate = Unmanaged<LiteCrate>.fromOpaque(aux).takeUnretainedValue()
//
//      let tableName = String(cString: cTableName)
//
//      //        NSLog("TABLE NAME: %@", tableName)
//
//      liteCrate.tablesToSignal.insert(tableName)
//    }, raw)
//
//    try inTransaction(operation: { db in
//      var currentVersion = try getCurrentSchemaVersion()
//      try migration(db, &currentVersion)
//      try setCurrentSchemaVersion(version: currentVersion)
//    })
//  }
//
//  public func closeDatabase() {
//    queue.sync {
//      _ = db?.close()
//    }
//    db = nil
//  }
//
//  public func inTransaction(operation: (CrateProxy) throws -> Void) rethrows {
//    do {
//      try queue.sync {
//        db.beginTransaction()
//
//        let crateProxy = TransactionCrateProxy(db: db)
//        defer { crateProxy.isEnabled = false }
//
//        try operation(crateProxy)
//        guard db.commit() else { throw NSError() }
//        notifyUpdates()
//      }
//    } catch {
//      db.rollback()
//    }
//  }
//
//  private func notifyUpdates() {
//    // Copy so they don't get wiped out by race condition
//    let tablesToSignal = self.tablesToSignal
//    defer { self.tablesToSignal = [] }
//
//    updateQueue.async { [weak self] in
//      guard let self = self else { return }
//      tablesToSignal.forEach {
//        self.tableChangedPublisher.send($0)
//      }
//    }
//  }
//

//}
