//
//  EmptyRange.swift
//
//
//  Created by Ryan Purpura on 6/26/22.
//

import Foundation
import LiteCrate

/// A range of dots that represents the fact that no nondeleted elements were created in the range by the given Node.
struct EmptyRange: DatabaseCodable, Identifiable {
  /// The id of the range.
  var id: UUID
  /// The node for which this range applied.
  var node: Node.Key
  /// The start of the range (inclusive).
  var start: Int64
  /// The end ot the range (inclusive).
  var end: Int64
  /// The last node to modify this range.
  var lastModifier: Node.Key
  /// The time (WRT to the lastModifier) that this range was last updated; for efficient delta updates only.
  var sequenceNumber: Int64

  init(node: Node.Key, start: Int64, end: Int64, sequenceNumber: Int64) {
    id = UUID()
    self.start = start
    self.end = end
    self.node = node
    lastModifier = node
    self.sequenceNumber = sequenceNumber
  }
}
