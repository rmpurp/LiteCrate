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
  case bool
  case uuid
  case date
  case nullableInteger
  case nullableReal
  case nullableText
  case nullableBlob
  case nullableBool
  case nullableUUID
  case nullableDate

  public var typeDefinition: String {
    switch self {
    case .integer, .date, .bool: return "INTEGER NOT NULL"
    case .real: return "REAL NOT NULL"
    case .text, .uuid: return "TEXT NOT NULL"
    case .blob: return "BLOB NOT NULL"
    case .nullableInteger, .nullableDate, .nullableBool: return "INTEGER"
    case .nullableReal: return "REAL"
    case .nullableText, .nullableUUID: return "TEXT"
    case .nullableBlob: return "BLOB"
    }
  }
}

public enum SQLiteValue: Equatable, SqliteRepresentable {
  case integer(val: Int64)
  case real(val: Double)
  case text(val: String)
  case blob(val: Data)
  case bool(val: Bool)
  case uuid(val: UUID)
  case date(val: Date)
  
  public init(columnValue: ColumnValue) {
    #warning("Remove me.")
    print("WARNING: This should be removed at some point.")
    self = .text(val: columnValue.string)
  }
}

public protocol SqliteRepresentable: Codable {
  init(columnValue: ColumnValue)
  var asSqliteValue: SQLiteValue { get }
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
}

extension Double: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue { .real(val: self) }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.double
  }
}

extension String: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue { .text(val: self) }

  public init(columnValue: ColumnValue) {
    self = columnValue.string
  }
}

extension Data: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue { .blob(val: self) }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.data
  }
}

extension Date: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue {
    .date(val: self)
  }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.date
  }
}

extension Bool: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue {
    .bool(val: self)
  }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.bool
  }

}

extension UUID: SqliteRepresentable {
  public var asSqliteValue: SQLiteValue {
    .uuid(val: self)
  }
  
  public init(columnValue: ColumnValue) {
    self = columnValue.uuid
  }
}
