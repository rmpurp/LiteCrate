//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import FMDB

extension LiteCrate {
  internal class TableSubscription {
    private var tableName: String
    
    var myAction: (() -> Void)?
    
    init(_ tableName: String) {
      self.tableName = tableName
    }
    
    func action(_ receivedValue: String) {
      if tableName == receivedValue {
        myAction?()
      }
    }
  }
}
