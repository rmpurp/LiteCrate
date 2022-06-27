//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/10/22.
//

import Foundation
import sqlite3

typealias SqliteDatabase = OpaquePointer

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DatabaseError: Error, CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case let .error(msg): fallthrough
    case let .abort(msg): fallthrough
    case let .unknown(msg):
      return msg
    }
  }

  case error(msg: String)
  case abort(msg: String)
  case unknown(msg: String)
}

public class Database {
  private let handle: SqliteDatabase
  private var closed: Bool = false

  public init(_ path: String) throws {
    var ppDb: SqliteDatabase?
    let errorCode = sqlite3_open(path, &ppDb)
    handle = ppDb!
    guard errorCode == SQLITE_OK else {
      defer { sqlite3_close_v2(handle) }
      throw getError()
    }
  }

  func getError() -> DatabaseError {
    guard !closed else { fatalError("Operating on a closed database.") }
    let errorCode = sqlite3_errcode(handle)
    let errorMessage = String(cString: sqlite3_errmsg(handle))
    switch errorCode {
    case 1: return DatabaseError.error(msg: errorMessage)
    case 4: return DatabaseError.abort(msg: errorMessage)
    default: return DatabaseError.unknown(msg: errorMessage)
    }
  }

  public func query(_ statement: String, _ parameters: [SqliteRepresentable?] = []) throws -> Cursor {
    guard !closed else { fatalError("Operating on a closed database.") }
    var ppStmt: SqliteStatement?
    let errorCode = sqlite3_prepare_v2(handle, statement, Int32(statement.lengthOfBytes(using: .utf8)), &ppStmt, nil)
    guard errorCode == SQLITE_OK, let ppStmt else {
      throw getError()
    }

    for (i, parameter) in parameters.enumerated() {
      let columnIndex = Int32(i + 1)
      switch parameter?.asSqliteType {
      case let .integer(val):
        sqlite3_bind_int64(ppStmt, columnIndex, val)
      case let .real(val):
        sqlite3_bind_double(ppStmt, columnIndex, val)
      case let .text(val):
        sqlite3_bind_text(ppStmt, columnIndex, val, Int32(val.lengthOfBytes(using: .utf8)), SQLITE_TRANSIENT)
      case let .blob(val):
        _ = val.withUnsafeBytes { bufferPointer in
          sqlite3_bind_blob(
            ppStmt,
            columnIndex,
            bufferPointer.baseAddress,
            Int32(bufferPointer.count),
            SQLITE_TRANSIENT
          )
        }
      case .none:
        sqlite3_bind_null(ppStmt, columnIndex)
      }
    }

    let cursor = Cursor(database: self, statement: ppStmt)
    return cursor
  }

  public func execute(_ statement: String, _ parameters: [SqliteRepresentable?] = []) throws {
    guard !closed else { fatalError("Operating on a closed database.") }
    let cursor = try query(statement, parameters)
    _ = try cursor.stepWithError()
  }

  public func close() {
    guard !closed else { return }
    defer { closed = true }
    sqlite3_close_v2(handle)
  }

  public func beginTransaction() throws {
    try execute("BEGIN DEFERRED")
  }

  public func rollback() throws {
    try execute("ROLLBACK")
  }

  public func commit() throws {
    try execute("COMMIT")
  }

  deinit {
    close()
  }
}
