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
import ObjectiveC


/// Disgusting hack in order to have more flexibility in returning Self-related return values.
public protocol DatabaseFetcher {
  init()
}

// MARK: - CRUD operations
extension DatabaseFetcher {
  /// Fetches the instance with the given primary key. Although the database access is done on a separate thread, this method
  /// blocks until the database operation is complete.
  /// - Parameter primaryKey: database primary key
  /// - Returns: instance, or nil if cannot be found
  public static func fetch(with primaryKey: Int64) -> Self? where Self: RPModel {
    return Self.fetchAll(forAllWhere: "id = ?", values: [primaryKey]).first
  }
  
  
  /// Blocking call to fetch
  public static func fetchAll(forAllWhere sqlWhereClause: String? = nil, values: [Any]? = nil) -> [Self] where Self: RPModel {
    // TODO: Properly rewrite query if where clause is null
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
}

// MARK: - Publishers
extension DatabaseFetcher {
  internal static func tableUpdatedPublisher() -> AnyPublisher<Void, Never> where Self: RPModel {
    RPModel.tableChangedPublisher
      .filter { $0 == Self.tableName }
      .map { _ in () }
      .assertNoFailure()
      .eraseToAnyPublisher()
  }
  
  
  /// Creates a publisher that fetches all items that match the where condition given.
  /// - Parameter sqlWhereClause: SQL WHERE clause. If null, fetches all.
  /// - Returns: publisher that publishes the stuff.
  public static func publisher(forAllWhere sqlWhereClause: String? = nil, values: [Any]? = nil) -> AnyPublisher<[Self], Never> where Self: RPModel {
    Just(())
      .subscribe(on: Self.queue)
      .append(Self.tableUpdatedPublisher())
      .map { _ in Self.fetchAll(forAllWhere: sqlWhereClause, values: values) }
      .eraseToAnyPublisher()
  }
}

open class RPModel: ObservableObject, DatabaseFetcher, Identifiable {
  // MARK: - Properties
  private(set) var isDeleted: Bool = false
  private(set) var isDirty: Bool = false
  
  private static var db: FMDatabase!
  @Column public var id: Int64!
  
  /// Publishes the name of a table which had an update/insert/delete
  fileprivate static var tableChangedPublisher = PassthroughSubject<String, Never>()
  
  // Override to set name different than class name
  open class var tableName: String {
    String(NSStringFromClass(self).split(separator: ".").last!)
  }
  
  fileprivate static let queue: DispatchQueue = DispatchQueue(
    label: "RPModelDispatchQueue",
    qos: .userInteractive,
    attributes: [],
    autoreleaseFrequency: .workItem,
    target: nil)
  
  private var subscriptions: Set<AnyCancellable> = []
  
  fileprivate static var instances: [String: NSMapTable<NSNumber, RPModel>] = [String: NSMapTable<NSNumber, RPModel>]()
  
  public static var createTableStatement: String {
    let model = Self()
    var creationStringComponents = ["CREATE TABLE",
                                    Self.tableName,
                                    "(",
                                    "id INTEGER PRIMARY KEY",
    ]
    for (label, column) in model.labeledColumns {
      guard label != "id" else { continue }
      
      creationStringComponents.append(",")
      creationStringComponents.append(label)
      creationStringComponents.append(column.typeName)
      creationStringComponents.append(column.isOptional ? "" : "NOT NULL")
    }
    creationStringComponents.append(")")
    return creationStringComponents.joined(separator: " ")
  }
  
  
  fileprivate static func storeInstance(model: RPModel?, tableName: String) {
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
  
  fileprivate func populate(resultSet: FMResultSet) {
    for (label, column) in labeledColumns {
      column.fetch(propertyName: label, resultSet: resultSet)
    }
  }
  
  public func save(waitUntilComplete: Bool = false) {
    var columnsToValue = [String: Any]()
    for (label, column) in labeledColumns {
      columnsToValue[label] = column.typeErasedValue()
    }
    
    let columns = [String](columnsToValue.keys)
    let columnString = columns.joined(separator: ",")
    let placeholders = String(String(repeating: "?,", count: columnsToValue.count).dropLast())
    let values = columns.map { columnsToValue[$0]! }
    
    RPModel.inDatabase(operation: { (db) in
      try! db.executeUpdate("INSERT OR REPLACE INTO \(Self.tableName)(\(columnString)) VALUES (\(placeholders)) ", values: values)
      if self.id == nil {
        self.id = db.lastInsertRowId
      }
      Self.storeInstance(model: self, tableName: Self.tableName)
    }, waitUntilComplete: waitUntilComplete)
  }
  
  public func delete(waitUntilComplete: Bool = false) {
    RPModel.inDatabase(operation: { [id] db in
      guard let id = id else { return }
      try! db.executeUpdate("DELETE FROM \(Self.tableName) WHERE id = ?", values: [id])
      self.isDeleted = true
      
    }, waitUntilComplete: waitUntilComplete)
  }
  
  
  private var _objectWillChange: ObservableObjectPublisher?
  
  required public init() {
    _ = Self.tableName
  }
}


// MARK: - Database Operations
extension RPModel {
  public static func inTransaction(operation: @escaping (FMDatabase) throws -> Void, waitUntilComplete: Bool = false) {
    inDatabase(operation: { db in
      db.beginDeferredTransaction()
      do {
        try operation(db)
      } catch {
        db.rollback()
      }
      db.commit()
    }, waitUntilComplete: waitUntilComplete)
  }
  
  public static func inDatabase(operation: @escaping (FMDatabase) -> Void, waitUntilComplete: Bool = false) {
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

// MARK: - Column Introspection

private struct PropertyIterator: IteratorProtocol {
  var currentMirror: Mirror
  var currentChildIterator: AnyIterator<Mirror.Child>
  init(mirror: Mirror) {
    self.currentMirror = mirror
    self.currentChildIterator = mirror.children.makeIterator()
  }
  
  mutating func next() -> Mirror.Child? {
    if let nextElem = currentChildIterator.next() {
      return nextElem
    }
    
    guard let nextMirror = currentMirror.superclassMirror else { return nil }
    currentChildIterator = nextMirror.children.makeIterator()
    currentMirror = nextMirror
    
    return next()
  }
}

extension RPModel {
  private var labeledColumns: AnyIterator<(String, ColumnProtocol)> {
    let mirror = Mirror(reflecting: self)
    let propertyIterator = AnyIterator(PropertyIterator(mirror: mirror))
    let columnIterator = propertyIterator.lazy
      .map { child -> (String, ColumnProtocol)? in
        guard let column = child.value as? ColumnProtocol,
              let label = child.label?.dropFirst() else { return nil }
        return (column.key ?? String(label), column)
      }
      .compactMap { $0 }
      .makeIterator()
    return AnyIterator(columnIterator)
  }

  public var objectWillChange: ObservableObjectPublisher {
    // https://forums.swift.org/t/question-about-valid-uses-of-observableobject-s-synthesized-objectwillchange/31141/2
    if let objectWillChange = _objectWillChange {
      return objectWillChange
    }
    
    // Not initialized yet; install into columns.
    let observableObjectPublisher = ObservableObjectPublisher()
    for (_, column) in labeledColumns {
      column.objectWillChange = observableObjectPublisher
    }
    _objectWillChange = observableObjectPublisher
    return observableObjectPublisher
  }
}
