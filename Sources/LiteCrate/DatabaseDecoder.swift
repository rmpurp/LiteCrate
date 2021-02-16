//
//  File.swift
//
//
//  Created by Ryan Purpura on 2/14/21.
//

import FMDB
import Foundation

struct DatabaseDecoder: Decoder {
  struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var codingPath: [CodingKey] = []
    var allKeys: [Key] = []

    var resultSet: FMResultSet

    func contains(_ key: Key) -> Bool {
      return resultSet.columnIndex(forName: key.stringValue) >= 0
    }

    func decodeNil(forKey key: Key) throws -> Bool {
      resultSet.columnIsNull(key.stringValue)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
      return resultSet.bool(forColumn: key.stringValue)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
      return resultSet.string(forColumn: key.stringValue) ?? ""
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
      return resultSet.double(forColumn: key.stringValue)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
      fatalError()
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
      return resultSet.long(forColumn: key.stringValue)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
      fatalError()
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
      fatalError()
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
      return resultSet.int(forColumn: key.stringValue)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
      return resultSet.longLongInt(forColumn: key.stringValue)
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
      return resultSet.unsignedLongLongInt(forColumn: key.stringValue)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
      switch type {
      case is Date.Type, is Date?.Type:
        return Date(timeIntervalSince1970: resultSet.double(forColumn: key.stringValue)) as! T
      case is UUID.Type, is UUID?.Type:
        guard
          let uuid = resultSet.string(forColumn: key.stringValue).flatMap(UUID.init(uuidString:))
        else { fatalError() }
        return uuid as! T
      default:
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .useDefaultKeys
        let jsonString = resultSet.string(forColumn: key.stringValue)
        guard let data = jsonString.flatMap({ $0.data(using: .utf8) }),
          let value = try? jsonDecoder.decode(T.self, from: data)
        else {
          fatalError()
        }
        return value
      }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
      -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
    {
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
  let resultSet: FMResultSet

  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
  where Key: CodingKey {
    return KeyedDecodingContainer(KDC(resultSet: resultSet))
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    fatalError()
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    fatalError()
  }
}
