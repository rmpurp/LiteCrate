//
//  RPModel.swift
//
//
//  Created by Ryan Purpura on 11/23/20.
//

import Foundation
import Combine
import FMDB

public class RPModel: ObservableObject {
  //  static func register(tableName: String) {}
  //  static func notify(tableName: String) {}
  
  public enum ChangeType {
    case insert, delete, update
  }
  @Column public var id: Int64
  
  public var tableName: String = ""
  
  public static var tableToClass: Dictionary<String, RPModel.Type> = [:]
  
  public class func tableDidChange(type: ChangeType, row: Int64) { }
  
  private var subscriptions: Set<AnyCancellable> = []
  
  public static func notify(tableName: String, type: ChangeType, row: Int64) {
    RPModel.tableToClass[tableName]?.tableDidChange(type: type, row: row)
  }
  
  public func populate(resultSet: FMResultSet) throws {
    var mirror: Mirror? = Mirror(reflecting: self)
    repeat {
      guard let children = mirror?.children else { break }
      
      for child in children {
        guard var decodableKey = child.value as? DatabaseFetchable else { continue }
        let propertyName = String((child.label ?? "").dropFirst())
        
        try decodableKey.decodeValue(propertyName: propertyName, resultSet: resultSet)
      }
      mirror = mirror?.superclassMirror
    } while mirror != nil
  }
  
  public class func register(tableName: String) {
    tableToClass[tableName] = Self.self
  }
  
  public init() {
    let mirror = Mirror(reflecting: self)
    mirror.children.forEach { child in
      if let observedProperty = child.value as? ColumnObservable {
        observedProperty.objectWillChange.sink { [weak self] _ in
          self?.objectWillChange.send()
        }.store(in: &subscriptions)
      }
    }
  }
}
