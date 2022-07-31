//
//  EmptyRange.swift
//
//
//  Created by Ryan Purpura on 6/26/22.
//

import Foundation

/// A range of dots that represents the fact that no nondeleted elements were created in the range by the given Node.
struct EmptyRange: DatabaseCodable, Identifiable {
  /// The id of the range.
  var id: UUID
  /// The node for which this range applied.
  var node: UUID
  /// The start of the range (inclusive).
  var start: Int64
  /// The end ot the range (inclusive).
  var end: Int64
  /// The last node to modify this range.
  var sequencer: UUID
  /// The time (WRT to the sequencer) that this range was last updated; for efficient delta updates only.
  var sequenceNumber: Int64

  static var table = Table("EmptyRange") {
    Column(name: "id", type: .text)
    Column(name: "node", type: .text)
    Column(name: "start", type: .integer)
    Column(name: "end", type: .integer)
    Column(name: "lastModifier", type: .text)
    Column(name: "sequenceNumber", type: .integer)
  }
  
  init(node: UUID, start: Int64, end: Int64, sequencer: UUID, sequenceNumber: Int64) {
    id = UUID()
    self.start = start
    self.end = end
    self.node = node
    self.sequencer = sequencer
    self.sequenceNumber = sequenceNumber
  }
}

extension EmptyRange: CustomDebugStringConvertible {
  var debugDescription: String {
    "EmptyRange(id:\(id.short), node:\(node.short), \(start)->\(end), lastModifier:\(sequencer.short), seqNum:\(sequenceNumber))"
  }
}

private extension UUID {
  var short: String {
    String(uuidString.prefix(4))
  }
}
