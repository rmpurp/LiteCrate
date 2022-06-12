//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/10/22.
//

import Foundation
import sqlite3

private typealias SqliteDatabase = OpaquePointer
private typealias SqliteStatement = OpaquePointer
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DatabaseError: Error, CustomDebugStringConvertible {
  public var debugDescription: String {
    switch (self) {
    case .error(let msg): fallthrough
    case .abort(let msg): fallthrough
    case .unknown(let msg):
      return msg
    }
  }
  
  case error(msg: String)
  case abort(msg: String)
  case unknown(msg: String)
}

public enum SqliteType {
  case integer(val: Int64)
  case real(val: Double)
  case text(val: String)
  case blob(val: Data)
}

public protocol SqliteRepresentable {
  var asSqliteType: SqliteType { get }
}

extension Int64: SqliteRepresentable {
  public var asSqliteType: SqliteType { return .integer(val: self) }
}

extension Double: SqliteRepresentable {
  public var asSqliteType: SqliteType { return .real(val: self) }
}

extension String: SqliteRepresentable {
  public var asSqliteType: SqliteType { return .text(val: self) }
}

extension Data: SqliteRepresentable {
  public var asSqliteType: SqliteType { return .blob(val: self) }
}

extension Date: SqliteRepresentable {
  public var asSqliteType: SqliteType {
    return .integer(val: Int64(timeIntervalSince1970))
  }
}

public class Cursor {
  private let database: Database
  private let statement: SqliteStatement
  private var done: Bool = false
  private var closed: Bool = false
  
  private var stepError: DatabaseError? = nil
  
  fileprivate init(database: Database, statement: SqliteStatement) {
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
  
  public func isNull(for index: Int32) -> Bool {
    guard !closed else { fatalError("Operating on a closed statement.") }
    return sqlite3_column_text(statement, index) == nil
  }
  
  /// Close this statement.
  /// It is OK to call this multiple times.
  /// This will be automatically called when this object is deinited.
  public func close() {
    guard !closed else { return }
    sqlite3_finalize(statement)
  }
  
  deinit {
    close()
  }
}

public class Database {
  private let handle: SqliteDatabase
  
  public init(_ path: String) throws {
    var ppDb: SqliteDatabase?
    let errorCode = sqlite3_open(path, &ppDb)
    handle = ppDb!
    guard errorCode == SQLITE_OK else {
      defer { sqlite3_close_v2(handle) }
      throw getError()
    }
  }
  
  fileprivate func getError() -> DatabaseError {
    let errorCode = sqlite3_errcode(handle)
    let errorMessage = String(cString: sqlite3_errmsg(handle))
    switch errorCode {
    case 1: return DatabaseError.error(msg: errorMessage)
    case 4: return DatabaseError.abort(msg: errorMessage)
    default: return DatabaseError.unknown(msg: errorMessage)
    }
  }
  
  public func query(_ statement: String, _ parameters: [SqliteRepresentable?] = []) throws -> Cursor {
    var ppStmt: SqliteStatement?
    let errorCode = sqlite3_prepare_v2(handle, statement, Int32(statement.lengthOfBytes(using: .utf8)), &ppStmt, nil)
    guard errorCode == SQLITE_OK, let ppStmt else {
      throw getError()
    }

    for (i, parameter) in parameters.enumerated() {
      let columnIndex = Int32(i + 1)
      switch parameter?.asSqliteType {
      case .integer(let val):
        sqlite3_bind_int64(ppStmt, columnIndex, val)
      case .real(let val):
        sqlite3_bind_double(ppStmt, columnIndex, val)
      case .text(let val):
        sqlite3_bind_text(ppStmt, columnIndex, val, Int32(val.lengthOfBytes(using: .utf8)), SQLITE_TRANSIENT)
      case .blob(let val):
        _ = val.withUnsafeBytes { bufferPointer in
          sqlite3_bind_blob(ppStmt, columnIndex, bufferPointer.baseAddress, Int32(bufferPointer.count), SQLITE_TRANSIENT)
        }
      case .none:
        sqlite3_bind_null(ppStmt, columnIndex)
      }
    }
    
    let cursor = Cursor(database: self, statement: ppStmt)
    return cursor
  }
  
  public func execute(_ statement: String, _ parameters: [SqliteRepresentable?] = []) throws {
      let cursor = try query(statement, parameters)
      _ = try cursor.stepWithError()
    }
  
  deinit {
    sqlite3_close_v2(handle)
  }
}
