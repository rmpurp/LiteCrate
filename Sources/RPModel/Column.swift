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

internal enum SQLType: Equatable {
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

/// The purpose of the Ref type is to give our fetching mechanism a way to set the value of the column
/// without having access to the original struct (i.e. a copy is obtained via introspection).
/// This also doubles as copy-on-write for when the struct is copied, although the types allowed may
/// be too small to matter to be honest.
internal class Ref<T> {
  var val: T
  init(_ v: T) { val = v }
}

internal protocol ColumnProtocol {
  mutating func fetch(propertyName: String, resultSet: FMResultSet)
  func typeErasedValue() -> Any
  var key: String? { get }
  func unsafeSetRefValue(to value: Any)
  var sqlType: SQLType { get }
}

@propertyWrapper public struct Column<Value>: ColumnProtocol {
  internal var _value: Ref<Value?>
  var key: String? = nil

  public var wrappedValue: Value {
    get {
      guard let value = _value.val else { fatalError("Column is uninitialized before use") }
      return value
    }
    set(newValue) {
      if !isKnownUniquelyReferenced(&_value) {
        _value = Ref(newValue)
      } else {
        _value.val = newValue
      }
    }
  }

  func unsafeSetRefValue(to value: Any) {
    self._value.val = dynamicCast(value, to: Value.self)
  }

  var sqlType: SQLType {
    switch Value.self {
    case is Bool.Type, is Bool?.Type:
      return .bool(value: dynamicCast(_value.val ?? Bool?.none as Any, to: Bool?.self))
    case is String.Type, is String?.Type:
      return .string(value: dynamicCast(_value.val ?? String?.none as Any, to: String?.self))
    case is Double.Type, is Double?.Type:
      return .double(value: dynamicCast(_value.val ?? Double?.none as Any, to: Double?.self))
    case is Int.Type, is Int?.Type:
      return .int(value: dynamicCast(_value.val ?? Int?.none as Any, to: Int?.self))
    case is Int32.Type, is Int32?.Type:
      return .int32(value: dynamicCast(_value.val ?? Int32?.none as Any, to: Int32?.self))
    case is Int64.Type, is Int64?.Type:
      return .int64(value: dynamicCast(_value.val ?? Int64?.none as Any, to: Int64?.self))
    case is UInt64.Type, is UInt64?.Type:
      return .uint64(value: dynamicCast(_value.val ?? UInt64?.none as Any, to: UInt64?.self))
    case is Date.Type, is Date?.Type:
      return .date(value: dynamicCast(_value.val ?? Date?.none as Any, to: Date?.self))
    case is UUID.Type, is UUID?.Type:
      return .uuid(value: dynamicCast(_value.val ?? UUID?.none as Any, to: UUID?.self))
    default: fatalError("Invalid type")
    }
  }

  public init(wrappedValue: Value) {
    self.key = nil
    self._value = Ref(wrappedValue)
  }

  public init() {
    self._value = Ref(nil)
  }

  public init() where Value: ExpressibleByNilLiteral {
    let value: Value = nil
    self._value = Ref(value)
  }

  //
  //  public init(wrappedValue: T) where T: ExpressibleByNilLiteral {
  //    self.key = key
  //    self._value = Ref(wrappedValue)
  //  }

  //  public init(wrappedValue: T, _ key: String? = nil) {
  //    self.key = key
  //    self._value = Ref(wrappedValue)
  //  }
  //
  //  public init(wrappedValue: T, _ key: String? = nil) where T: ExpressibleByNilLiteral {
  //    self.key = key
  //    self._value = Ref(wrappedValue)
  //  }

  //  public init(_ key: String? = nil) {
  //    self.key = key
  //    self._value = Ref(nil)
  //  }
  //
  //  public init(_ key: String? = nil) where T: ExpressibleByNilLiteral {
  //    self.key = key
  //    let value: T = nil
  //    self._value = Ref(value)
  //  }
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

  internal mutating func fetch(propertyName: String, resultSet: FMResultSet) {
    let column = key ?? propertyName

    switch self.sqlType {
    case .bool: wrappedValue = resultSet.bool(forColumn: column) as! Value
    case .string: wrappedValue = resultSet.string(forColumn: column) as! Value
    case .double: wrappedValue = resultSet.double(forColumn: column) as! Value
    case .int: wrappedValue = resultSet.long(forColumn: column) as! Value
    case .int32: wrappedValue = resultSet.int(forColumn: column) as! Value
    case .int64: wrappedValue = resultSet.longLongInt(forColumn: column) as! Value
    case .uint64: wrappedValue = resultSet.unsignedLongLongInt(forColumn: column) as! Value
    case .date: wrappedValue = resultSet.date(forColumn: column) as! Value
    case .uuid:
      let fetchedUUID = resultSet.string(forColumn: column).flatMap { UUID(uuidString: $0) }
      guard let uuid = fetchedUUID else {
        fatalError("Malformed database: incorrect UUID")
        // TODO: Change to some sort of exception.
      }
      wrappedValue = uuid as! Value
    }
  }
}

extension Column: Equatable where Value: Equatable {
  public static func == (lhs: Column<Value>, rhs: Column<Value>) -> Bool {
    guard lhs._value.val != nil, rhs._value.val != nil else { return true }
    guard let lhsVal = lhs._value.val, let rhsVal = rhs._value.val else { return false }
    return lhsVal == rhsVal
  }
}

extension Column: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(_value.val)
  }
}
