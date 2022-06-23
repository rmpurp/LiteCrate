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
  init() {
    version = UUID()
    id = UUID()
    createdTime = Timestamp(time: -1, node: UUID())
    modifiedTime = Timestamp(time: -1, node: UUID())
    witnessedTime = Timestamp(time: -1, node: UUID())
  }

  init(id: UUID) {
    version = UUID()
    self.id = id
    createdTime = Timestamp(time: -1, node: UUID())
    modifiedTime = Timestamp(time: -1, node: UUID())
    witnessedTime = Timestamp(time: -1, node: UUID())
  }

  var isInitialized: Bool {
    createdTime.time >= 0
  }

  var isDeleted: Bool {
    modifiedTime == nil
  }

  mutating func update(modifiedBy node: UUID, at time: Int64) {
    let now = Timestamp(time: time, node: node)
    if !isInitialized {
      createdTime = now
    }
    modifiedTime = now
    witnessedTime = now
  }

  mutating func delete(modifiedBy node: UUID, at time: Int64) {
    let now = Timestamp(time: time, node: node)
    if !isInitialized {
      createdTime = now
    }

    modifiedTime = nil
    witnessedTime = now
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    // Deletions always "newer" aka greater
    precondition(lhs.id == rhs.id, "These Dots are not comparable as they have different stable ids.")

    if lhs.isDeleted, rhs.isDeleted {
      return false
    }

    if lhs.version == rhs.version {
      guard let lhsTimeModified = lhs.modifiedTime?.time else { return false }
      guard let rhsTimeModified = rhs.modifiedTime?.time else { return true } // rhs deleted, so "newer"

      return lhsTimeModified < rhsTimeModified
    } else {
      if lhs.createdTime.time == rhs.createdTime.time {
        return lhs.createdTime.node.uuidString < rhs.createdTime.node.uuidString
      }
      return lhs.createdTime.time < rhs.createdTime.time
    }
  }

  var version: UUID
  var id: UUID

  private(set) var createdTime: Timestamp
  private(set) var modifiedTime: Timestamp?
  private(set) var witnessedTime: Timestamp

  private enum CodingKeys: String, CodingKey {
    case id
    case version
    case createdTime
    case createdNode
    case modifiedTime
    case modifiedNode
    case witnessedTime
    case witnessedNode
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: Self.CodingKeys)
    try container.encode(version, forKey: .version)
    try container.encode(id, forKey: .id)
    try container.encode(createdTime.time, forKey: .createdTime)
    try container.encode(createdTime.node, forKey: .createdNode)
    try container.encodeIfPresent(modifiedTime?.time, forKey: .modifiedTime)
    try container.encodeIfPresent(modifiedTime?.node, forKey: .modifiedNode)
    try container.encode(witnessedTime.time, forKey: .witnessedTime)
    try container.encode(witnessedTime.node, forKey: .witnessedNode)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: Self.CodingKeys)
    version = try container.decode(UUID.self, forKey: .version)
    id = try container.decode(UUID.self, forKey: .id)
    createdTime = try Timestamp(time: container.decode(Int64.self, forKey: .createdTime),
                                node: container.decode(UUID.self, forKey: .createdNode))
    if let modifiedTime = try container.decodeIfPresent(Int64.self, forKey: .modifiedTime),
       let modifiedNode = try container.decodeIfPresent(UUID.self, forKey: .modifiedNode)
    {
      self.modifiedTime = Timestamp(time: modifiedTime,
                                    node: modifiedNode)
    } else {
      modifiedTime = nil
    }
    witnessedTime = try Timestamp(time: container.decode(Int64.self, forKey: .witnessedTime),
                                  node: container.decode(UUID.self, forKey: .witnessedNode))
  }
}

extension Dot: Equatable {}
