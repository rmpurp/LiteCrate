//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import sqlite3

typealias SqliteStatement = OpaquePointer

public struct ColumnValue {
  private var cursor: Cursor
  private var columnIndex: Int32
  init(cursor: Cursor, columnIndex: Int32) {
    self.cursor = cursor
    self.columnIndex = columnIndex
  }
  
  var null: Bool { cursor.isNull(for: columnIndex) }
  var string: String { cursor.string(for: columnIndex) }
  var int: Int64 { cursor.int(for: columnIndex) }
  var double: Double { cursor.double(for: columnIndex) }
  var bool: Bool { cursor.bool(for: columnIndex) }
  var uuid: UUID { cursor.uuid(for: columnIndex) }
  var date: Date { cursor.date(for: columnIndex) }
  var data: Data { cursor.data(for: columnIndex) }

}

public class Cursor {
  private let database: Database
  private let statement: SqliteStatement
  private var done: Bool = false
  private var closed: Bool = false
  private var _columnToIndex: [String: Int32]?

  public var columnToIndex: [String: Int32] {
    guard !closed else { fatalError("Operating on a closed statement.") }

    if let _columnToIndex {
      return _columnToIndex
    }

    let columnCount = sqlite3_column_count(statement)
    guard columnCount > 0 else { return [:] }

    var columnToIndexDictionary = [String: Int32]()
    for i in 0 ..< columnCount {
      let name = String(cString: sqlite3_column_name(statement, i))
      columnToIndexDictionary[name] = i
    }
    _columnToIndex = columnToIndexDictionary
    return columnToIndexDictionary
  }

  private var stepError: DatabaseError?

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
      defer { close() }
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
    int(for: index) == 0 ? false : true
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

  public func string(for column: String) -> String {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return string(for: index)
  }

  public func int(for column: String) -> Int64 {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return int(for: index)
  }

  public func double(for column: String) -> Double {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return double(for: index)
  }

  public func bool(for column: String) -> Bool {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return bool(for: index)
  }

  public func data(for column: String) -> Data {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return data(for: index)
  }

  public func date(for column: String) -> Date {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return date(for: index)
  }

  public func uuid(for column: String) -> UUID {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return uuid(for: index)
  }

  public func isNull(for column: String) -> Bool {
    // TODO: Make this throw or something.
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return isNull(for: index)
  }
  
  public func columnValue(for column: String) -> ColumnValue {
    guard let index = columnToIndex[column] else { fatalError("Column does not exist.") }
    return ColumnValue(cursor: self, columnIndex: index)
  }

  /// Close this statement.
  /// It is OK to call this multiple times, as long as you don't call it from different threads.
  /// This will be automatically called when this object is deinited.
  public func close() {
    guard !closed else { return }
    closed = true
    sqlite3_finalize(statement)
  }

  deinit {
    close()
  }
}
