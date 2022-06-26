//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/25/22.
//

import Foundation
import LiteCrate

struct EmptyRange: DatabaseCodable {
  typealias Key = Never

  var node: UUID
  var start: Int64
  var end: Int64

  var modifiedNode: UUID
  var modifiedTime: Int64
}
