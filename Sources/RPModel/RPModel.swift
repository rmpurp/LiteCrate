//
//  RPModel.swift
//
//
//  Created by Ryan Purpura on 11/23/20.
//

import Foundation
import Combine
import FMDB

class RPModel: ObservableObject {
  //  static func register(tableName: String) {}
  //  static func notify(tableName: String) {}
  
  enum ChangeType {
    case insert, delete, update
  }
  @Column var id: Int64
  
  open var tableName: String = ""
  
  static var tableToClass: Dictionary<String, RPModel.Type> = [:]
  
  class func tableDidChange(type: ChangeType, row: Int64) { }
  
  private var subscriptions: Set<AnyCancellable> = []
  
  static func notify(tableName: String, type: ChangeType, row: Int64) {
    RPModel.tableToClass[tableName]?.tableDidChange(type: type, row: row)
  }
  
  func populate(resultSet: FMResultSet) throws {
    //    let decoder = DBDecoder(resultSet: resultSet)
    //    let container = try decoder.container(keyedBy: ColumnCodingKeys.self)
    
    // Mirror for current model
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
  
  class func register(tableName: String) {
    tableToClass[tableName] = Self.self
  }
  
  init() {
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


//
//public struct ColumnCodingKeys: CodingKey {
//  public var stringValue: String
//
//  public init(stringValue: String) { self.stringValue = stringValue }
//
//  public var intValue: Int? = nil
//  public init?(intValue: Int) { fatalError("IntValue is not supported")}
//}
//
//public protocol SQLRepresentable {}
//extension Int64: SQLRepresentable {}
//extension String: SQLRepresentable {}
//extension Date: SQLRepresentable {}
//
