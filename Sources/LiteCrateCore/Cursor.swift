//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import sqlite3

typealias SqliteStatement = OpaquePointer

public class Cursor {
  private let database: Database
  private let statement: SqliteStatement
  private var done: Bool = false
  private var closed: Bool = false
  private var _columnToIndex: [String: Int32]? = nil
  
  public var columnToIndex: [String: Int32] {
    guard !closed else { fatalError("Operating on a closed statement.") }

    if let _columnToIndex {
      return _columnToIndex
    }
    
    let columnCount = sqlite3_column_count(statement)
    guard columnCount > 0 else { return [:] }

    var columnToIndexDictionary = [String: Int32]()
    for i in 0..<columnCount {
      let name = String(cString: sqlite3_column_name(statement, i))
      columnToIndexDictionary[name] = i
    }
    _columnToIndex = columnToIndexDictionary
    return columnToIndexDictionary
  }
  
  private var stepError: DatabaseError? = nil
  
  init(database: Database, statement: SqliteStatement) {
    self.database = database
    self.statement = statement
  }
  
  public func step() -> Bool {
    do {
      return try stepWithError()
    } catch {
      return false
    }
  }
  
  public func stepWithError() throws -> Bool {
    guard !closed else { fatalError("Operating on a closed statement.") }
    let resultCode = sqlite3_step(statement)
    switch resultCode {
    case SQLITE_ROW:
      return true
    case SQLITE_OK: /* Is this even possible? */ fallthrough
    case SQLITE_DONE:
      done = true
      return false
    default:
      defer { sqlite3_finalize(statement) }
      throw database.getError()
    }
  }
  
  public func string(for index: Int32) -> String {
    guard !closed else { fatalError("Operating on a closed statement.") }
    return String(cString: sqlite3_column_text(statement, index))
  }
  
  public func int(for index: Int32) -> Int64 {
    guard !closed else { fatalError("Operating on a closed statement.") }
    return sqlite3_column_int64(statement, index)
  }
  
  public func double(for index: Int32) -> Double {
    guard !closed else { fatalError("Operating on a closed statement.") }
    return sqlite3_column_double(statement, index)
  }
  
  public func bool(for index: Int32) -> Bool {
    return int(for: index) == 0 ? false : true
  }
  
  public func data(for index: Int32) -> Data {
    guard !closed else { fatalError("Operating on a closed statement.") }
    let bytes = sqlite3_column_blob(statement, index)!
    let count = sqlite3_column_bytes(statement, index)
    return Data(bytes: bytes, count: Int(count))
  }
  
  public func date(for index: Int32) -> Date {
    let timeInterval = TimeInterval(int(for: index))
    return Date(timeIntervalSince1970: timeInterval)
  }
  
  public func uuid(for index: Int32) -> UUID {
    let uuidString = string(for: index)
    guard let uuid = UUID(uuidString: uuidString) else { fatalError("Invalid UUID string: \(uuidString)") }
    return uuid
  }
  
  public func isNull(for index: Int32) -> Bool {
    guard !closed else { fatalError("Operating on a closed statement.") }
    return sqlite3_column_text(statement, index) == nil
  }
  
  /// Close this statement.
  /// It is OK to call this multiple times.
  /// This will be automatically called when this object is deinited.
  public func close() {
    guard !closed else { return }
    defer { closed = true }
    sqlite3_finalize(statement)
  }
  
  deinit {
    close()
  }
}
