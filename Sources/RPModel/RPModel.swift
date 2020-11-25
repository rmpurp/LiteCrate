//
//  RPModel.swift
//
//
//  Created by Ryan Purpura on 11/23/20.
//

import Foundation
import Combine
import FMDB
import SQLite3


/// Disgusting hack in order to have more flexibility in returning Self-related return values.
/// Everything declared here is minimum-viable implementations to implement methods in the protocol extension.
protocol DatabaseFetcher {
  init()
}

// MARK: - CRUD operations
extension DatabaseFetcher {
  /// Blocking call to fetch
  public static func fetchAll(forAllWhere sqlWhereClause: String? = nil, values: [Any]? = nil) -> [Self] where Self: RPModel {
    let sqlWhereClause = sqlWhereClause ?? "1=1"
    var returnValue = [Self]()
    let semaphore = DispatchSemaphore(value: 0)
    
    Self.inDatabase { db in
      guard let rs = try? db.executeQuery("SELECT * FROM \(Self.tableName) WHERE \(sqlWhereClause)",
                                          values: values) else {
        semaphore.signal()
        return
      }
      
      while rs.next() {
        let primaryKey = rs.longLongInt(forColumn: "id")
        
        if let dict = Self.instances[Self.tableName],
           let model = dict.object(forKey: primaryKey as NSNumber) as? Self {
          returnValue.append(model)
        } else {
          let model = Self()
          model.populate(resultSet: rs)
          returnValue.append(model)
          Self.storeInstance(model: model, tableName: Self.tableName)
        }
      }
      semaphore.signal()
    }
    semaphore.wait()
    return returnValue
  }
  
  /// Fetches the instance with the given primary key. Although the database access is done on a separate thread, this method
  /// blocks until the database operation is complete.
  /// - Parameter primaryKey: database primary key
  /// - Returns: instance, or nil if cannot be found
  public static func fetch(with primaryKey: Int64) -> Self? where Self: RPModel {
    return Self.fetchAll(forAllWhere: "id = ?", values: [primaryKey]).first
  }
  
  internal static func tableUpdatedPublisher() -> AnyPublisher<Void, Never> where Self: RPModel {
    RPModel.tableChangedPublisher
      .filter({ (str) -> Bool in
        str == Self.tableName
      })
      .map { _ in () }
      .assertNoFailure()
      .eraseToAnyPublisher()
  }
  
  
  /// Creates a publisher that fetches all items that match the where condition given.
  /// - Parameter sqlWhereClause: SQL WHERE clause. If null, fetches all.
  /// - Returns: publisher that publishes the stuff.
  public static func publisher(forAllWhere sqlWhereClause: String? = nil, values: [Any]? = nil) -> AnyPublisher<[Self], Never> where Self: RPModel {
    Just(())
      .append(Self.tableUpdatedPublisher())
      .subscribe(on: Self.queue)
      .map { _ in
        Self.fetchAll(forAllWhere: sqlWhereClause, values: values)
      }
      .eraseToAnyPublisher()
  }
}

fileprivate let tableDidChangeNotification = Notification.Name("TableDidChange")

open class RPModel: ObservableObject, DatabaseFetcher, Identifiable {
  public enum ChangeType {
    case insert, delete, update
  }
    
  private static var db: FMDatabase!
  fileprivate static let queue: DispatchQueue = DispatchQueue(label: "RPModelDispatchQueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: nil)

  static var instances: [String: NSMapTable<NSNumber, RPModel>] = [String: NSMapTable<NSNumber, RPModel>]()
  
  public static func inTransaction(operation: @escaping (FMDatabase) throws -> Void, waitUntilComplete: Bool = false) {
    let semaphore = DispatchSemaphore(value: 0)
    inDatabase { (db) in
      db.beginDeferredTransaction()
      do {
        try operation(db)
      } catch {
        db.rollback()
      }
      db.commit()
      
      semaphore.signal()
    }
    if waitUntilComplete { semaphore.wait() }
  }
  
  public static func inDatabase(operation: @escaping (FMDatabase) -> Void) {
    if Thread.isMainThread {
      queue.async {
        operation(db)

      }
    } else {
      operation(db)
    }
  }
  
  @Column public var id: Int64!
  
  open class var tableName: String { "" }
  
  public static var tableToClass: Dictionary<String, RPModel.Type> = [:]
  
  static func storeInstance(model: RPModel?, tableName: String) {
    guard let model = model, let primaryKey = model.id else { return }
    let dict: NSMapTable<NSNumber, RPModel>
    
    if let activeDict = instances[Self.tableName] {
      dict = activeDict
    } else {
      dict = NSMapTable<NSNumber, RPModel>.strongToWeakObjects()
      instances[Self.tableName] = dict
    }
    dict.setObject(model, forKey: primaryKey as NSNumber)
  }

  private static func assertTableName<T: RPModel>(type: T.Type) {
    assert(T.tableName != "", "You haven't set the table name for \(T.self)")
  }
  
  public class func tableDidChange(type: ChangeType, row: Int64) { }
  
  private var subscriptions: Set<AnyCancellable> = []
  
  fileprivate static var tableChangedPublisher = PassthroughSubject<String, Never>()
  
  fileprivate func populate(resultSet: FMResultSet) {
    var mirror: Mirror? = Mirror(reflecting: self)
    repeat {
      guard let children = mirror?.children else { break }
      
      for child in children {
        guard let column = child.value as? DatabaseFetchable else { continue }
        let propertyName = String((child.label ?? "").dropFirst())
        
        column.fetch(propertyName: propertyName, resultSet: resultSet)
      }
      mirror = mirror?.superclassMirror
    } while mirror != nil
  }
  
  public func save(waitUntilComplete: Bool = false) {
    var columnsToValue = [String: Any]()
    var mirror: Mirror? = Mirror(reflecting: self)
    repeat {
      guard let children = mirror?.children else { break }
      
      for child in children {
        guard let column = child.value as? DatabaseFetchable else { continue }
        
        let propertyName = String((child.label ?? "").dropFirst())
        columnsToValue[propertyName] = column.typeErasedValue()
      }
      mirror = mirror?.superclassMirror
    } while mirror != nil
    let columns = [String](columnsToValue.keys)
    let columnString = columns.joined(separator: ",")
    let placeholders = String(String(repeating: "?,", count: columnsToValue.count).dropLast())
    let values = columns.map { columnsToValue[$0]! }
    
    RPModel.inTransaction(operation: { (db) in
      try! db.executeUpdate("INSERT OR REPLACE INTO \(Self.tableName)(\(columnString)) VALUES (\(placeholders)) ", values: values)
      if self.id == nil {
        self.id = db.lastInsertRowId
      }
      Self.storeInstance(model: self, tableName: Self.tableName)
    }, waitUntilComplete: waitUntilComplete)
  }
  
  public class func register(tableName: String) {
    tableToClass[tableName] = Self.self
  }
  
  required public init() {
    _ = Self.tableName
    let mirror = Mirror(reflecting: self)
    mirror.children.forEach { child in
      if let observedProperty = child.value as? ColumnObservable {
        observedProperty.objectWillChange.sink { [weak self] _ in
          self?.objectWillChange.send()
        }.store(in: &subscriptions)
      }
    }
  }
}

// MARK: - Database Opening/Closing/Migrations
extension RPModel {
  public static func openDatabase(at url: URL?, migration: @escaping (FMDatabase, inout Int64) throws -> Void) {
    db = FMDatabase(url: url)
    db.open()

    sqlite3_update_hook(OpaquePointer(db.sqliteHandle), { (aux, type, cDatabaseName, cTableName, rowid) in
      guard let cTableName = cTableName else { return }
      let tableName = String(cString: cTableName)
      RPModel.queue.async {
        RPModel.tableChangedPublisher.send(tableName)
      }
    }, nil)

    inTransaction(operation: { db in
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

  private static func getCurrentSchemaVersion(db: FMDatabase) throws -> Int64 {
    try db.executeUpdate(
      "CREATE TABLE IF NOT EXISTS schema(version INTEGER)", values: nil)
    
    let rs = try db.executeQuery("SELECT version AS dbVersion FROM schema",
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

extension RPModel: Hashable {
  public static func == (lhs: RPModel, rhs: RPModel) -> Bool {
    return lhs.id == rhs.id
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  
}