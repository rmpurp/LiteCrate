//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/18/21.
//

import Foundation

extension LiteCrate {
  internal final class TablesToSignalWrapper {
    private var _tablesToSignal: Set<String> = []
    private var lock = NSLock()
    
    var tablesToSignal: Set<String> {
      let tables: Set<String>
      lock.lock()
      tables = _tablesToSignal
      lock.unlock()
      return tables
    }
    
    func insert(_ table: String) {
      lock.lock()
      _tablesToSignal.insert(table)
      lock.unlock()
    }
    
    func clear() {
      lock.lock()
      _tablesToSignal.removeAll()
      lock.unlock()
    }
  }
}
