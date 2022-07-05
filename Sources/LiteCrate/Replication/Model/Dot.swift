//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public struct Dot: Codable {
  /// The stable id of the model.
  var id: UUID

  /// The node that created the model.
  private(set) var creator: Node.Key
  /// The time (WRT to the creator) at which the model was created.
  private(set) var createdTime: Int64
  /// The last node to modify the model.
  private(set) var lastModifier: Node.Key
  /// The time (WRT the lastModifier) that the model was last updated; for efficient delta updates only.
  private(set) var sequenceNumber: Int64
  /// Internal clock; incremented for each modification. Used to resolve conflicts between concurrent updates.
  /// If equal, then lastModifier's id is used as a tiebreaker.
  private(set) var lamportClock: Int64

  init() {
    self.init(id: UUID())
  }

  init(id: UUID) {
    self.id = id
    creator = UUID()
    createdTime = -1
    lastModifier = UUID()
    sequenceNumber = -1
    lamportClock = -1
  }

  var isInitialized: Bool {
    createdTime >= 0
  }

  // MARK: - CRUD

  mutating func update(modifiedBy node: UUID, at time: Int64, transactionTime: Int64) {
    if !isInitialized {
      createdTime = time
      creator = node
      lamportClock = 0
    } else {
      lamportClock += 1
    }
    sequenceNumber = transactionTime
    lastModifier = node
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    // Deletions always "newer" aka greater
    precondition(lhs.id == rhs.id, "These Dots are not comparable as they have different stable ids.")

    if lhs.lamportClock == rhs.lamportClock {
      return lhs.creator.uuidString < rhs.creator.uuidString
    }
    return lhs.lamportClock < rhs.lamportClock
  }

  func isSameVersion(as otherDot: Dot) -> Bool {
    creator == otherDot.creator && createdTime == otherDot.createdTime
  }
}

extension Dot: Equatable {}
