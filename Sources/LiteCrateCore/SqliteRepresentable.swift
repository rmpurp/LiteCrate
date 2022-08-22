//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
// MARK: - Sqlite Types

/// Allowable types for columns.
public enum SqliteType: String, Codable {
  case integer = "INTEGER NOT NULL"
  case real = "REAL NOT NULL"
  case text = "TEXT NOT NULL"
  case blob = "BLOB NOT NULL"
  case nullableInteger = "INTEGER"
  case nullableReal = "REAL"
  case nullableText = "TEXT"
  case nullableBlob = "BLOB"
}

public enum ExtendedSqliteType: Codable {
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
  
  public var sqliteType: SqliteType {
    switch self {
    case .integer, .date, .bool: return .integer
    case .real: return .real
    case .text, .uuid: return .text
    case .blob: return .blob
    case .nullableInteger, .nullableDate, .nullableBool: return .nullableInteger
    case .nullableReal: return .nullableReal
    case .nullableText, .nullableUUID: return .nullableText
    case .nullableBlob: return .nullableBlob
    }
  }
}

public enum SqliteValue: Equatable, SqliteRepresentable {
  public var asSqliteValue: SqliteValue {
    return self
  }

  case integer(val: Int64)
  case real(val: Double)
  case text(val: String)
  case blob(val: Data)
}

public enum ExtendedSqliteValue: Equatable, SqliteRepresentable {
  public init(_ value: SqliteValue)  {
    switch value {
    case let .integer(val): self = .integer(val: val)
    case let .real(val): self = .real(val: val)
    case let .text(val): self = .text(val: val)
    case let .blob(val): self = .blob(val: val)
    }
  }
  
  public var asSqliteValue: SqliteValue {
    switch self {
    case let .integer(val): return val.asSqliteValue
    case let .real(val): return val.asSqliteValue
    case let .text(val): return val.asSqliteValue
    case let .blob(val): return val.asSqliteValue
    case let .bool(val): return val.asSqliteValue
    case let .uuid(val): return val.asSqliteValue
    case let .date(val): return val.asSqliteValue
    }
  }
  
  case integer(val: Int64)
  case real(val: Double)
  case text(val: String)
  case blob(val: Data)
  case bool(val: Bool)
  case uuid(val: UUID)
  case date(val: Date)
}

public protocol SqliteRepresentable: Codable {
  var asSqliteValue: SqliteValue { get }
  var asExtendedSqliteValue: ExtendedSqliteValue { get }
}

public extension SqliteRepresentable {
  var asExtendedSqliteValue: ExtendedSqliteValue {
    return ExtendedSqliteValue(asSqliteValue)
  }
}

extension Int64: SqliteRepresentable {
  public var asSqliteValue: SqliteValue { .integer(val: self) }
}

extension Double: SqliteRepresentable {
  public var asSqliteValue: SqliteValue { .real(val: self) }
}

extension String: SqliteRepresentable {
  public var asSqliteValue: SqliteValue { .text(val: self) }
}

extension Data: SqliteRepresentable {
  public var asSqliteValue: SqliteValue { .blob(val: self) }
}

extension Date: SqliteRepresentable {
  public var asSqliteValue: SqliteValue {
    .integer(val: Int64(timeIntervalSince1970))
  }
}

extension Bool: SqliteRepresentable {
  public var asSqliteValue: SqliteValue {
    .integer(val: self ? 1 : 0)
  }
}

extension UUID: SqliteRepresentable {
  public var asSqliteValue: SqliteValue {
    .text(val: uuidString)
  }
}
