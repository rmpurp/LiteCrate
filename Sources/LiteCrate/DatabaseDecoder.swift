//
//  File.swift
//
//
//  Created by Ryan Purpura on 2/14/21.
//

import LiteCrateCore
import Foundation

class DatabaseDecoder: Decoder {
  struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var codingPath: [CodingKey] = []
    var allKeys: [Key] = []
    var decoder: DatabaseDecoder
    var cursor: Cursor

    func contains(_ key: Key) -> Bool {
      return cursor.columnToIndex[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
      guard let index = cursor.columnToIndex[key.stringValue] else {
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
      }

      return cursor.isNull(for: index)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
      guard let index = cursor.columnToIndex[key.stringValue] else {
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
      }

      return cursor.bool(for: index)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
      guard let index = cursor.columnToIndex[key.stringValue] else {
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
      }

      return cursor.string(for: index)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
      guard let index = cursor.columnToIndex[key.stringValue] else {
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
      }

      return cursor.double(for: index)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
      fatalError()
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
      fatalError()
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
      fatalError()
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
      fatalError()
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
      fatalError()
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
      guard let index = cursor.columnToIndex[key.stringValue] else {
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
      }
      return cursor.int(for: index)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
      fatalError()
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
      fatalError()

    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
      fatalError()

    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
      fatalError()
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
      fatalError()
    }
    
    func index(for key: Key) throws -> Int32 {
      guard let index = cursor.columnToIndex[key.stringValue] else {
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
      }
      return index
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {

      switch type {
      case is Date.Type, is Date?.Type:
        let index = try index(for: key)
        return cursor.date(for: index) as! T
      case is Data.Type, is Data?.Type:
        let index = try index(for: key)
        return cursor.data(for: index) as! T
      case is UUID.Type, is UUID?.Type:
        let index = try index(for: key)
        return cursor.uuid(for: index) as! T
      default:
        return try type.init(from: decoder)
//        fatalError("Unsupported type")
      }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
      -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        fatalError()
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
      fatalError()

    }

    func superDecoder() throws -> Decoder {
      fatalError()

    }

    func superDecoder(forKey key: Key) throws -> Decoder {
      fatalError()
    }
  }

  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]
  let cursor: Cursor
  
  init(cursor: Cursor) {
    self.cursor = cursor
  }

  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
  where Key: CodingKey {
    return KeyedDecodingContainer(KDC(decoder: self, cursor: cursor))
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    fatalError()
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    fatalError()
  }
}
