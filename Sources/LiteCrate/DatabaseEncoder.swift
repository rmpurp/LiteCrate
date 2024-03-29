//
//  File.swift
//
//
//  Created by Ryan Purpura on 2/14/21.
//

import Foundation
import LiteCrateCore

class DatabaseEncoder: Encoder {
  init(tableName: String) {
    self.tableName = tableName
  }

  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  var columnToKey: [String: SqliteRepresentable?] = [:]
  var tableName: String

  var insertStatement: (String, [SqliteRepresentable?]) {
    // If there is an error here, it will be caught and resolved during developement

    let columns = [String](columnToKey.keys)
    let columnString = columns.joined(separator: ",")
    let placeholders = [String](repeating: "?", count: columnToKey.count).joined(separator: ",")
    let values = columns.map { columnToKey[$0]! }

    let insertString = "INSERT OR REPLACE INTO \(tableName)(\(columnString)) VALUES (\(placeholders)) "
    return (insertString, values)
  }

  struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    let encoder: DatabaseEncoder

    mutating func encodeNil(forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = nil
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Double(value)
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = Int64(value)
    }

    mutating func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T: Encodable {
      switch value {
      case .none:
        encoder.columnToKey[key.stringValue] = nil
      case let value as SqliteRepresentable:
        encoder.columnToKey[key.stringValue] = value
      default:
        fatalError("Incompatible type")
      }
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
      switch value {
      case let value as SqliteRepresentable:
        encoder.columnToKey[key.stringValue] = value
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

  func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    KeyedEncodingContainer(KEC(encoder: self))
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("unkeyed container not allowed")
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    fatalError()
  }
}
