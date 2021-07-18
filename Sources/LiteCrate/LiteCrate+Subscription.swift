//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import FMDB

@available(macOSApplicationExtension 12.0, *)
extension LiteCrate {
  internal class TableSubscription {
    private var tableName: String
    private var statement: FMResultSet
    
    var myAction: (() -> Void)?
    
    init(_ tableName: String, preparedStatement: FMResultSet) {
      self.tableName = tableName
      self.statement = preparedStatement
    }
    
    func action(_ receivedValue: String) {
      if tableName == receivedValue {
        myAction?()
      }
    }
  }
}
