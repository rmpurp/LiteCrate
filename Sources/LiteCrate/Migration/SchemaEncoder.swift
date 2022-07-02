//
//  File.swift
//
//
//  Created by Ryan Purpura on 2/17/22.
//

import Foundation
import LiteCrateCore

public class SchemaEncoder: Encoder {
  enum SqliteType: String {
    case integer = "INTEGER NOT NULL"
    case real = "REAL NOT NULL"
    case text = "TEXT NOT NULL"
    case blob = "BLOB NOT NULL"
    case nullableInteger = "INTEGER"
    case nullableReal = "REAL"
    case nullableText = "TEXT"
    case nullableBlob = "BLOB"
  }

  public init<T: DatabaseCodable>(_ instance: T) {
    tableName = instance.tableName
    primaryKeyColumn = T.primaryKeyColumn
    foreignKeys = T.foreignKeys
    try? instance.encode(to: self)
  }

  public var codingPath: [CodingKey] = []
  public var userInfo: [CodingUserInfoKey: Any] = [:]

  var tableName: String
  var primaryKeyColumn: String
  var foreignKeys: [ForeignKey]

  var columns: [String: SqliteType] = [:]

  struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    let encoder: SchemaEncoder

    func encodeNil(forKey _: Key) throws {
      fatalError()
    }

    func encode(_: Bool, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: String, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .text
    }

    func encode(_: Double, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .real
    }

    func encode(_: Float, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .real
    }

    func encode(_: Int, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: Int8, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: Int16, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: Int32, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: Int64, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: UInt, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: UInt8, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: UInt16, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: UInt32, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encode(_: UInt64, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }

    func encodeIfPresent(_: Bool?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: String?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableText
    }

    func encodeIfPresent(_: Float?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableReal
    }

    func encodeIfPresent(_: Double?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableReal
    }

    func encodeIfPresent(_: Int?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: Int8?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: Int16?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: Int32?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: Int64?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: UInt?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: UInt8?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: UInt16?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: UInt32?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_: UInt64?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent<T>(_: T?, forKey key: Key) throws where T: Encodable {
      if T.self == Date.self {
        encoder.columns[key.stringValue] = .nullableInteger
      } else if T.self == Data.self {
        encoder.columns[key.stringValue] = .nullableBlob
      } else if T.self == T.self {
        encoder.columns[key.stringValue] = .nullableText
      }
    }

    mutating func encode<T: SqliteRepresentable>(sqliteRepresentable value: T, forKey key: Key) throws {
      switch value.asSqliteType {
      case let .blob(val): try encode(val, forKey: key)
      case let .integer(val): try encode(val, forKey: key)
      case let .real(val): try encode(val, forKey: key)
      case let .text(val): try encode(val, forKey: key)
      }
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
      switch value {
      case let value as SqliteRepresentable:
        try encode(sqliteRepresentable: value, forKey: key)
      default:
        try value.encode(to: encoder)
      }
    }

    mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey _: Key)
      -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
    {
      fatalError()
    }

    mutating func nestedUnkeyedContainer(forKey _: Key) -> UnkeyedEncodingContainer {
      fatalError()
    }

    mutating func superEncoder() -> Encoder {
      fatalError()
    }

    mutating func superEncoder(forKey _: Key) -> Encoder {
      fatalError()
    }
  }

  public func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    KeyedEncodingContainer(KEC(encoder: self))
  }

  public func unkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("unkeyed container not allowed")
  }

  public func singleValueContainer() -> SingleValueEncodingContainer {
    fatalError()
  }
}

public extension SchemaEncoder {
  var creationStatement: String {
    let opening = "CREATE TABLE \(tableName) (\n"
    var components = [String]()
    let ending = "\n);"

    let sortedColumns = columns.sorted {
      if $0.key == primaryKeyColumn { return true }
      if $1.key == primaryKeyColumn { return false }
      return $0.key < $1.key
    }

    components.append(contentsOf: sortedColumns.map { "\($0) \($1.rawValue)" })
    components.append("PRIMARY KEY (\(primaryKeyColumn))")
    components.append(contentsOf: foreignKeys.map(\.creationStatement))
    return opening + components.map { "    " + $0 }.joined(separator: ",\n") + ending
  }

  var selectStatement: String {
    let columns = [String](columns.keys)
    let columnString = columns.lazy
      .map { "\($0) AS \($0)" }
      .joined(separator: ",")

    return "SELECT \(columnString) FROM \(tableName)"
  }
}
