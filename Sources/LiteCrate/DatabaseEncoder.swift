//
//  File.swift
//
//
//  Created by Ryan Purpura on 2/14/21.
//

import Foundation

class DatabaseEncoder: Encoder {

  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  var columnToKey: [String: Any] = [:]

  struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    let encoder: DatabaseEncoder

    mutating func encodeNil(forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = NSNull()
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
      encoder.columnToKey[key.stringValue] = value
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
      encoder.columnToKey[key.stringValue] = value

    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
      if let date = value as? Date {
        encoder.columnToKey[key.stringValue] = date.timeIntervalSince1970
      } else if let data = value as? Data {
        encoder.columnToKey[key.stringValue] = data
      } else if let uuid = value as? UUID {
        encoder.columnToKey[key.stringValue] = uuid.uuidString
      } else {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.keyEncodingStrategy = .useDefaultKeys
        jsonEncoder.dateEncodingStrategy = .millisecondsSince1970

        encoder.columnToKey[key.stringValue] = try jsonEncoder.encode(value)
      }
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
      -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
    {
      fatalError()
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
      fatalError()
    }

    mutating func superEncoder() -> Encoder {
      fatalError()
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
      fatalError()
    }
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    return KeyedEncodingContainer(KEC(encoder: self))
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("unkeyed container not allowed")

  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    fatalError()
  }

}
