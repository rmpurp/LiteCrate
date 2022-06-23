//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrate

public protocol ReplicatingModel: DatabaseCodable<UUID> {
  var dot: Dot { get set }
}

public extension ReplicatingModel {
  var primaryKeyValue: Key {
    dot.version
  }

  static var primaryKeyColumn: String {
    "version"
  }
}
