//
//  File.swift
//  
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import Combine
import FMDB

func testType<T>(_ value: Any, is type_: T.Type) -> Bool {
  return type(of: value) == T.self
}

public protocol DatabaseFetchable {
  func fetch(propertyName: String, resultSet: FMResultSet)
  func typeErasedValue() -> Any
  var typeName: String { get }
  var isOptional: Bool { get }
}

internal protocol ColumnObservable: AnyObject {
  var objectWillChange: ObservableObjectPublisher { get }
}

@propertyWrapper public final class Column<T>: ObservableObject, ColumnObservable {
  @Published private var _value: T?
  
  var key: String?
  public var isOptional: Bool
  public var wrappedValue: T {
    get {
      return _value!
    } set {
      _value = newValue
    }
  }
  
  public var typeName: String {
    let objectToConsider: Any = isOptional ? self._value! : self._value as Any
    // TODO: Blob
    if testType(objectToConsider, is: Int?.self)
        || testType(objectToConsider, is: Int32?.self)
        || testType(objectToConsider, is: Int64?.self)
        || testType(objectToConsider, is: UInt64?.self)
        || testType(objectToConsider, is: Bool?.self)
    {
      return "INTEGER"
    } else if testType(objectToConsider, is: Double?.self) {
      return "REAL"
    } else if testType(objectToConsider, is: String?.self) {
      return "TEXT"
    } else if testType(objectToConsider, is: Date?.self) {
      return "DATE"
    } else {
      fatalError("Unsupported type")
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

extension Column: DatabaseFetchable {
  public func typeErasedValue() -> Any {
    return self.wrappedValue
  }
  
  public func fetch(propertyName: String, resultSet: FMResultSet) {
    let column = key ?? propertyName
    
    //    if let value = try? container.decode(T.self, forKey: codingKey) {
    //      wrappedValue = value
    switch T.self {
    case is Bool.Type, is Bool?.Type: wrappedValue = resultSet.bool(forColumn: column) as! T
    case is String.Type: wrappedValue = resultSet.string(forColumn: column) as! T
    case is Double.Type: wrappedValue = resultSet.double(forColumn: column) as! T
    case is Int.Type: wrappedValue = resultSet.long(forColumn: column) as! T
    case is Int32.Type: wrappedValue = resultSet.int(forColumn: column) as! T
    case is Int64.Type: wrappedValue = resultSet.longLongInt(forColumn: column) as! T
    case is UInt64.Type: wrappedValue = resultSet.unsignedLongLongInt(forColumn: column) as! T
    case is Date.Type: wrappedValue = resultSet.date(forColumn: column)! as! T
      
    case is String?.Type: wrappedValue = resultSet.string(forColumn: column) as! T
    case is Double?.Type: wrappedValue = resultSet.double(forColumn: column) as! T
    case is Int?.Type: wrappedValue = resultSet.long(forColumn: column) as! T
    case is Int32?.Type: wrappedValue = resultSet.int(forColumn: column) as! T
    case is Int64?.Type: wrappedValue = resultSet.longLongInt(forColumn: column) as! T
    case is UInt64?.Type: wrappedValue = resultSet.unsignedLongLongInt(forColumn: column) as! T
    case is Date?.Type: wrappedValue = resultSet.date(forColumn: column) as! T
      
    //    case is UUID.Type: wrappedValue = UUID().uuid rs.data(forColumn: column)! as! T
    default:
      fatalError()
    }
  }
}
