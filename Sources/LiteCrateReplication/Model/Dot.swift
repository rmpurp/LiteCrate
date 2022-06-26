//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrate

public struct Dot: Codable {
  init() {
    self.init(id: UUID())
  }

  init(id: UUID) {
    self.id = id
    createdTime = -1
    modifiedLamport = -1
    sequenceNumber = -1
    creator = UUID()
    lastModifier = UUID()
  }

  var isInitialized: Bool {
    createdTime >= 0
  }

  mutating func update(modifiedBy node: UUID, at time: Int64, transactionTime: Int64) {
    if !isInitialized {
      createdTime = time
      creator = node
      modifiedLamport = 0
    } else {
      modifiedLamport += 1
    }
    sequenceNumber = transactionTime
    lastModifier = node
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    // Deletions always "newer" aka greater
    precondition(lhs.id == rhs.id, "These Dots are not comparable as they have different stable ids.")
    fatalError()
//    if lhs.isDeleted, rhs.isDeleted {
//      return false
//    }
//
//    if lhs.version == rhs.version {
//      guard let lhsTimeModified = lhs.modifiedTime else { return false }
//      guard let rhsTimeModified = rhs.modifiedTime else { return true } // rhs deleted, so "newer"
//
//      return lhsTimeModified < rhsTimeModified
//    } else {
//      if lhs.createdTime.time == rhs.createdTime.time {
//        return lhs.createdTime.node.uuidString < rhs.createdTime.node.uuidString
//      }
//      return lhs.createdTime.time < rhs.createdTime.time
//    }
  }

  var id: UUID

  private(set) var createdTime: Int64
  private(set) var creator: UUID
  private(set) var lastModifier: UUID
  private(set) var sequenceNumber: Int64 // Global time modified; *only* for fetching deltas. (lastModifier, sequenceNumber)
  private(set) var modifiedLamport: Int64 // Model-local version clock; for resolving conflicts. (lastModifier, modifiedLamport)
}

extension Dot: Equatable {}
