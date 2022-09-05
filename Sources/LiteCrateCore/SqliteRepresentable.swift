//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

// MARK: - Sqlite Types

/// Application-level types, extending the standard SQLite types with some pragmatic additions.
public enum SQLiteType: Codable {
  case integer
  case real
  case text
  case blob
  case nullableInteger
  case nullableReal
  case nullableText
  case nullableBlob

  public var typeDefinition: String {
    switch self {
    case .integer: return "INTEGER NOT NULL"
    case .real: return "REAL NOT NULL"
    case .text: return "TEXT NOT NULL"
    case .blob: return "BLOB NOT NULL"
    case .nullableInteger: return "INTEGER"
    case .nullableReal: return "REAL"
    case .nullableText: return "TEXT"
    case .nullableBlob: return "BLOB"
    }
  }
}

public enum SQLiteValue: Equatable, SqliteRepresentable {
  case integer(val: Int64)
  case real(val: Double)
  case text(val: String)
  case blob(val: Data)
  case null
  
  public init(columnValue: ColumnValue) {
    self = .text(val: columnValue.string)
  }
  
  public static var sqliteType: SQLiteType {
    .text
  }
}

public protocol SqliteRepresentable: Codable {
  init(columnValue: ColumnValue)
  var asSqliteValue: SQLiteValue { get }
  static var sqliteType: SQLiteType { get }
}

// MARK: - SQLite Representable Conformances

public extension SQLiteValue {
  var asSqliteValue: SQLiteValue {
    self
  }
}

extension Int64: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue { .integer(val: self) }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.int
  }
  
  static public var sqliteType: SQLiteType {
    return .integer
  }
}

extension Double: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue { .real(val: self) }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.double
  }
  
  public static var sqliteType: SQLiteType {
    return .real
  }
}

extension String: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue { .text(val: self) }

  public init(columnValue: ColumnValue) {
    self = columnValue.string
  }
  
  public static var sqliteType: SQLiteType {
    return .text
  }
}

extension Data: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue { .blob(val: self) }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.data
  }
  
  public static var sqliteType: SQLiteType {
    return .blob
  }
}

extension Date: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue {
    .integer(val: Int64(timeIntervalSince1970))
  }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.date
  }
  
  public static var sqliteType: SQLiteType {
    return .integer
  }
}

extension Bool: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue {
    .integer(val: self ? 1 : 0)
  }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.bool
  }

  public static var sqliteType: SQLiteType {
    return .integer
  }
}

extension UUID: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue {
    .text(val: uuidString)
  }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.uuid
  }
  
  public static var sqliteType: SQLiteType {
    return .text
  }
}

extension Optional: SqliteRepresentable where Wrapped: SqliteRepresentable {
  public init(columnValue: ColumnValue) {
    if columnValue.null {
      self = .none
    } else {
      self = Wrapped(columnValue: columnValue)
    }
  }
  
  public var asSqliteValue: SQLiteValue {
    if let self {
      return self.asSqliteValue
    } else {
      return .null
    }
  }
  
  public static var sqliteType: SQLiteType {
    switch Wrapped.sqliteType {
    case .integer, .nullableInteger:
      return .nullableInteger
    case .real, .nullableReal:
      return .nullableReal
    case .text, .nullableText:
      return .nullableText
    case .blob, .nullableBlob:
      return .nullableBlob
    }
  }
  
  
}
