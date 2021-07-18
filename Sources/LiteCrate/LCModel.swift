//
//  File.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import Combine
import FMDB
import Foundation

public protocol LCModel: Identifiable, Equatable, Codable where ID == UUID {
  
  override var id: ID { get set }
  //  var everSynced: Bool { get set }
  //  var isDirty: Bool { get set }
}

extension LCModel {
  internal var insertValues: (columnString: String, placeholders: String, values: [Any]) {
    let encoder = DatabaseEncoder()
    try! self.encode(to: encoder)
    let columnsToValue = encoder.columnToKey
    // If there is an error here, it will be caught and resolved during developement
    
    let columns = [String](columnsToValue.keys)
    let columnString = columns.joined(separator: ",")
    let placeholders = String(String(repeating: "?,", count: columnsToValue.count).dropLast())
    let values = columns.map { columnsToValue[$0]! }
    return (columnString, placeholders, values)
  }
  
  public static var tableName: String { String(describing: Self.self) }
}

