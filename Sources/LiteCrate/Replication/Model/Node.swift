//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/17/22.
//

import Foundation

struct Node: ReplicatingModel, Identifiable {
  var id: UUID
  var nextSequenceNumber: Int64
  var nextCreationNumber: Int64

  static var table: Table = .init("Node") {
    Column(Self.CodingKeys.id, type: .text).primaryKey()
    Column(Self.CodingKeys.nextSequenceNumber, type: .integer)
    Column(Self.CodingKeys.nextCreationNumber, type: .integer)
  }
}

// private extension Collection where Element == Node {
//  func toDict() -> [UUID: Node] {
//    var dict = [UUID: Node]()
//    for node in self {
//      dict[node.id] = node
//    }
//    return dict
//  }
// }
