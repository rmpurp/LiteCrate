//
//  File.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Combine
import FMDB
import Foundation

func dynamicCast<T>(_ value: Any, to _: T.Type) -> T {
  return value as! T
}

internal enum SQLType {
  case bool(value: Bool?)
  case string(value: String?)
  case double(value: Double?)
  case int(value: Int?)
  case int32(value: Int32?)
  case int64(value: Int64?)
  case uint64(value: UInt64?)
  case date(value: Date?)
  case uuid(value: UUID?)
}

internal protocol ColumnProtocol: AnyObject {
  func fetch(propertyName: String, resultSet: FMResultSet)
  func typeErasedValue() -> Any
  var typeName: String { get }
  var isOptional: Bool { get }
  var key: String? { get }
  var objectWillChange: ObservableObjectPublisher? { set get }
}

@propertyWrapper public final class Column<T>: ColumnProtocol {
  private var _value: T?
  weak var objectWillChange: ObservableObjectPublisher? = nil
  var key: String? = nil

  public var isOptional: Bool
  public var wrappedValue: T {
    get {
      guard let value = _value else { fatalError("Column is uninitialized before use") }
      return value
    }
    set {
      objectWillChange?.send()
      _value = newValue
    }
  }

  var sqlType: SQLType {
    switch T.self {
    case is Bool.Type, is Bool?.Type:
      return .bool(value: dynamicCast(_value ?? Bool?.none as Any, to: Bool?.self))
    case is String.Type, is String?.Type:
      return .string(value: dynamicCast(_value ?? String?.none as Any, to: String?.self))
    case is Double.Type, is Double?.Type:
      return .double(value: dynamicCast(_value ?? Double?.none as Any, to: Double?.self))
    case is Int.Type, is Int?.Type:
      return .int(value: dynamicCast(_value ?? Int?.none as Any, to: Int?.self))
    case is Int32.Type, is Int32?.Type:
      return .int32(value: dynamicCast(_value ?? Int32?.none as Any, to: Int32?.self))
    case is Int64.Type, is Int64?.Type:
      return .int64(value: dynamicCast(_value ?? Int64?.none as Any, to: Int64?.self))
    case is UInt64.Type, is UInt64?.Type:
      return .uint64(value: dynamicCast(_value ?? UInt64?.none as Any, to: UInt64?.self))
    case is Date.Type, is Date?.Type:
      return .date(value: dynamicCast(_value ?? Date?.none as Any, to: Date?.self))
    case is UUID.Type, is UUID?.Type:
      return .uuid(value: dynamicCast(_value ?? UUID?.none as Any, to: UUID?.self))
    default: fatalError("Invalid type")
    }
  }

  public var typeName: String {
    switch sqlType {
    case .int, .int32, .int64, .uint64, .bool, .date:
      return "INTEGER"
    case .double:
      return "REAL"
    case .string:
      return "TEXT"
    case .uuid:
      return "TEXT"
    }
  }

  public init(wrappedValue: T, _ key: String? = nil) {
    self.key = key
    self._value = wrappedValue
    isOptional = false
  }

  public init(wrappedValue: T, _ key: String? = nil) where T: ExpressibleByNilLiteral {
    self.key = key
    self._value = wrappedValue
    isOptional = true
  }

  public init(_ key: String? = nil) {
    self.key = key
    self._value = nil
    isOptional = false
  }

  public init(_ key: String? = nil) where T: ExpressibleByNilLiteral {
    self.key = key
    let value: T = nil
    self._value = value
    isOptional = true
  }
}

extension Column {
  internal func typeErasedValue() -> Any {
    switch sqlType {
    case .uuid(let uuid):
      return uuid.flatMap { $0.uuidString } as Any
    default:
      return self.wrappedValue
    }
  }

  internal func fetch(propertyName: String, resultSet: FMResultSet) {
    let column = key ?? propertyName

    switch self.sqlType {
    case .bool: wrappedValue = resultSet.bool(forColumn: column) as! T
    case .string: wrappedValue = resultSet.string(forColumn: column) as! T
    case .double: wrappedValue = resultSet.double(forColumn: column) as! T
    case .int: wrappedValue = resultSet.long(forColumn: column) as! T
    case .int32: wrappedValue = resultSet.int(forColumn: column) as! T
    case .int64: wrappedValue = resultSet.longLongInt(forColumn: column) as! T
    case .uint64: wrappedValue = resultSet.unsignedLongLongInt(forColumn: column) as! T
    case .date: wrappedValue = resultSet.date(forColumn: column) as! T
    case .uuid:
      let fetchedUUID = resultSet.string(forColumn: column).flatMap { UUID(uuidString: $0) }
      guard let uuid = fetchedUUID else {
        fatalError("Malformed database: incorrect UUID")
        // TODO: Change to some sort of exception.
      }
      wrappedValue = uuid as! T
    }
  }
}
