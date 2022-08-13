//
//  File.swift
//  
//
//  Created by Ryan Purpura on 8/12/22.
//

import Foundation
import LiteCrateCore

public struct ReplicatingEntity {
  public let entityType: String
  public private(set) var fields: [String: SqliteValue?]

  public init(entityType: String) {
    self.entityType = entityType
    self.fields = [:]
  }

  public subscript(_ key: String) -> SqliteValue? {
    get {
      return fields[key]!
    }
    set {
      fields[key] = newValue
    }
  }
}
