//
//  File.swift
//  
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import Combine
import FMDB

internal enum SQLType {
  case bool, string, double, int, int32, int64, uint64, date
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
      return _value!
    } set {
      objectWillChange?.send()
      _value = newValue
    }
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
  
  public var typeName: String {
    switch (sqlType) {
    case .int, .int32, .int64, .uint64, .bool:
      return "INTEGER"
    case .double:
      return "REAL"
    case .string:
      return "TEXT"
    case .date:
      return "DATE"
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
    return self.wrappedValue
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
    //    case is UUID.Type: wrappedValue = UUID().uuid rs.data(forColumn: column)! as! T
    }
  }
}
