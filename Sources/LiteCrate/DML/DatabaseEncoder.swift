//
//  File.swift
//
//
//  Created by Ryan Purpura on 2/14/21.
//

import Foundation
import LiteCrateCore

class DatabaseEncoder: Encoder {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  private(set) var insertValues: [String: SQLiteValue] = [:]

  struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    let encoder: DatabaseEncoder

    mutating func encodeNil(forKey key: Key) throws {
      encoder.insertValues[key.stringValue] = nil
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = value.asSqliteValue
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .text(val: value)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .real(val: value)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .real(val: Double(value))
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: value)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
      if key.stringValue == "id" { return }
      encoder.insertValues[key.stringValue] = .integer(val: Int64(value))
    }

    mutating func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T: Encodable {
      if key.stringValue == "id" { return }
      switch value {
      case .none:
        encoder.insertValues[key.stringValue] = nil
      case let value as SqliteRepresentable:
        encoder.insertValues[key.stringValue] = value.asSqliteValue
      default:
        fatalError("Incompatible type")
      }
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
      if key.stringValue == "id" { return }
      switch value {
      case let value as SqliteRepresentable:
        encoder.insertValues[key.stringValue] = value.asSqliteValue
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
