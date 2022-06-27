//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrate

public struct Timestamp: Equatable, Codable {
  var time: Int64
  var node: UUID
}

public struct Dot: Codable {
  /// The version of the model that was generated when it was first created.
  var version: UUID
  /// The stable id of the model.
  var id: UUID

  /// The node that created the model.
  private(set) var creator: Node.Key
  /// The time (WRT to the creator) at which the model was created.
  private(set) var createdTime_: Int64
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
    version = UUID()
    self.id = id
    creator = UUID()
    createdTime_ = -1
    lastModifier = UUID()
    sequenceNumber = -1
    lamportClock = -1
  }

  // MARK: - Shims

  var isDeleted: Bool = false

  var createdTime: Timestamp {
    Timestamp(time: createdTime_, node: creator)
  }

  var modifiedTime: Timestamp {
    Timestamp(time: sequenceNumber, node: lastModifier)
  }

  var witnessedTime: Timestamp {
    Timestamp(time: sequenceNumber, node: lastModifier)
  }

  var isInitialized: Bool {
    createdTime_ >= 0
  }

  // MARK: - CRUD

  mutating func update(modifiedBy node: UUID, at time: Int64) {
    if !isInitialized {
      createdTime_ = time
      creator = node
      lamportClock = 0
    } else {
      lamportClock += 1
    }
    sequenceNumber = time
    lastModifier = node
  }

  mutating func delete(modifiedBy node: UUID, at time: Int64) {
    if !isInitialized {
      createdTime_ = time
      creator = node
    }
    isDeleted = true
    sequenceNumber = time
    lastModifier = node
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    // Deletions always "newer" aka greater
    precondition(lhs.id == rhs.id, "These Dots are not comparable as they have different stable ids.")

    if lhs.isDeleted, rhs.isDeleted {
      return false
    }

    if lhs.version == rhs.version {
      guard !lhs.isDeleted else { return false }
      guard !rhs.isDeleted else { return true } // rhs deleted, so "newer"

      return lhs.sequenceNumber < rhs.sequenceNumber
    } else {
      if lhs.createdTime_ == rhs.createdTime_ {
        return lhs.creator.uuidString < rhs.creator.uuidString
      }
      return lhs.createdTime_ < rhs.createdTime_
    }
  }
}

extension Dot: Equatable {}
