//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public enum SqliteType {
  case integer(val: Int64)
  case real(val: Double)
  case text(val: String)
  case blob(val: Data)
}

public protocol SqliteRepresentable: Codable {
  var asSqliteType: SqliteType { get }
}

extension Int64: SqliteRepresentable {
  public var asSqliteType: SqliteType { .integer(val: self) }
}

extension Double: SqliteRepresentable {
  public var asSqliteType: SqliteType { .real(val: self) }
}

extension String: SqliteRepresentable {
  public var asSqliteType: SqliteType { .text(val: self) }
}

extension Data: SqliteRepresentable {
  public var asSqliteType: SqliteType { .blob(val: self) }
}

extension Date: SqliteRepresentable {
  public var asSqliteType: SqliteType {
    .integer(val: Int64(timeIntervalSince1970))
  }
}

extension Bool: SqliteRepresentable {
  public var asSqliteType: SqliteType {
    .integer(val: self ? 1 : 0)
  }
}

extension UUID: SqliteRepresentable {
  public var asSqliteType: SqliteType {
    .text(val: uuidString)
  }
}
