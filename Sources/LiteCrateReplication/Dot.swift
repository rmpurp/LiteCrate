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
    timeLastModified = nil
    lastModifier = nil
    witness = UUID()
    timeLastWitnessed = -1
  }
  
  init(id: UUID) {
    version = UUID()
    self.id = id
    timeCreated = -1
    creator = UUID()
    timeLastModified = nil
    lastModifier = nil
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
  
  private(set) var version: UUID
  private(set) var id: UUID
  
  private(set) var timeCreated: Int64
  private(set) var creator: UUID
  
  private(set) var timeLastModified: Int64?
  private(set) var lastModifier: UUID?
  
  private(set) var timeLastWitnessed: Int64
  private(set) var witness: UUID
}
