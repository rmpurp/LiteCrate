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
    version = UUID()
    id = UUID()
    timeCreated = -1
    creator = UUID()
    timeLastModified = -1
    lastModifier = UUID()
    witness = UUID()
    timeLastWitnessed = -1
  }
  
  init(id: UUID) {
    version = UUID()
    self.id = id
    timeCreated = -1
    creator = UUID()
    timeLastModified = -1
    lastModifier = UUID()
    witness = UUID()
    timeLastWitnessed = -1
  }
  
  var isInitialized: Bool {
    return timeCreated >= 0
  }
  
  var isDeleted: Bool {
    precondition(timeLastModified != nil && lastModifier != nil
                 || timeLastModified == nil && lastModifier == nil)
    return timeLastModified == nil
  }
  
  mutating func update(modifiedBy node: UUID, at time: Int64) {
    if !isInitialized {
      timeCreated = time
      creator = node
    }
    
    timeLastModified = time
    lastModifier = node

    timeLastWitnessed = time
    witness = node
  }

  mutating func delete(modifiedBy node: UUID, at time: Int64) {
    if !isInitialized {
      timeCreated = time
      creator = node
    }
    
    timeLastModified = nil
    lastModifier = nil

    timeLastWitnessed = time
    witness = node
  }
  
  static func < (lhs: Self, rhs: Self) -> Bool {
    // Deletions always "newer" aka greater
    
    guard lhs.id == rhs.id else { fatalError("These Dots are not comparable as they have different stable ids.") }
    if lhs.isDeleted && rhs.isDeleted {
      return false
    }
    
    guard let lhsTimeModified = lhs.timeLastModified else { return false }
    guard let rhsTimeModified = rhs.timeLastModified else { return true } // rhs deleted, so "newer"
    
    return  lhsTimeModified < rhsTimeModified
  }
  
  var version: UUID
  var id: UUID
  
  private(set) var timeCreated: Int64
  private(set) var creator: UUID
  
  private(set) var timeLastModified: Int64?
  private(set) var lastModifier: UUID?
  
  private(set) var timeLastWitnessed: Int64
  private(set) var witness: UUID
}

extension Dot: Equatable {}
