//
//  File.swift
//  
//
//  Created by Ryan Purpura on 2/17/22.
//

import Foundation

class SchemaEncoder: Encoder {
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
  
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]

  var columns: [String: SqliteType] = [:]
  
  struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    let encoder: SchemaEncoder
    
    func encodeNil(forKey key: Key) throws {
      fatalError()
    }
    
    func encode(_ value: Bool, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: String, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .text
    }
    
    func encode(_ value: Double, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .real
    }
    
    func encode(_ value: Float, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .real
    }
    
    func encode(_ value: Int, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: Int8, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: Int16, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: Int32, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: Int64, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: UInt, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: UInt8, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: UInt16, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: UInt32, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encode(_ value: UInt64, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .integer
    }
    
    func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: String?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableText
    }
    
    func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableReal
    }
    
    func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableReal
    }
    
    func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }

    func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
      encoder.columns[key.stringValue] = .nullableInteger
    }
    
    func encodeIfPresent<T>(_ value: T?, forKey key: Key) throws where T : Encodable {
      if T.self == Date.self {
        encoder.columns[key.stringValue] = .nullableReal
      } else if T.self == Data.self {
        encoder.columns[key.stringValue] = .nullableBlob
      } else {
        encoder.columns[key.stringValue] = .nullableText
      }
    }
    
    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
      if T.self == Date.self {
        encoder.columns[key.stringValue] = .real
      } else if T.self == Data.self {
        encoder.columns[key.stringValue] = .blob
      } else {
        encoder.columns[key.stringValue] = .text
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
