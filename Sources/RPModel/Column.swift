//
//  File.swift
//  
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import Combine
import FMDB

//
//func testType<T>(_ value: Any, is type_: T.Type) -> Bool {
//  return type(of: value) == T.self
//}

public protocol DatabaseFetchable {
  func fetch(propertyName: String, resultSet: FMResultSet)
  func typeErasedValue() -> Any
  var typeName: String { get }
  var isOptional: Bool { get }
}

enum SQLType {
  case bool, string, double, int, int32, int64, uint64, date
}

internal protocol ColumnObservable: AnyObject {
  var objectWillChange: ObservableObjectPublisher { get }
}

@propertyWrapper public final class Column<T>: ObservableObject, ColumnObservable {
  @Published private var _value: T?
  
  
  var key: String!
  
  public var isOptional: Bool

  public var wrappedValue: T {
    get {
      return _value!
    } set {
      _value = newValue
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
  
  var sqlType: SQLType {
    switch (T.self) {
    case is Bool.Type, is Bool?.Type: return .bool
    case is String.Type, is String?.Type: return .string
    case is Double.Type, is Double?.Type: return .double
    case is Int.Type, is Int?.Type: return .int
    case is Int32.Type, is Int32?.Type: return .int32
    case is Int64.Type, is Int64?.Type: return .int64
    case is UInt64.Type, is UInt64?.Type: return .uint64
    case is Date.Type, is Date?.Type: return .date
    default: fatalError("Invalid type")
    }
  }
}
