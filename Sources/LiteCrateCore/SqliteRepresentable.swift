//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public enum SqliteValue: Equatable {
  case integer(val: Int64)
  case real(val: Double)
  case text(val: String)
  case blob(val: Data)
}

public protocol SqliteRepresentable: Codable {
  var asSqliteValue: SqliteValue { get }
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
