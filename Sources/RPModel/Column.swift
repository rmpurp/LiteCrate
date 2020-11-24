//
//  File.swift
//  
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import Combine
import FMDB

public protocol DatabaseFetchable {
  func decodeValue(propertyName: String, resultSet: FMResultSet) throws
}

internal protocol ColumnObservable: AnyObject {
  var objectWillChange: ObservableObjectPublisher { get }
}

@propertyWrapper public final class Column<T>: ObservableObject, ColumnObservable {
  var key: String?
  @Published private var _value: T?
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
  }
  
  public init(_ key: String? = nil) {
    self.key = key
    self._value = nil
  }
  
  public init(_ key: String? = nil) where T: ExpressibleByNilLiteral {
    self.key = key
    let value: T = nil
    self._value = value
  }
  
}

extension Column: DatabaseFetchable {
  public func decodeValue(propertyName: String, resultSet: FMResultSet) throws {
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
