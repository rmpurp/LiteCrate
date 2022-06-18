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
    timeCreated = -1
    creator = UUID()
    timeLastModified = nil
    lastModifier = nil
    witness = UUID()
    timeLastWitnessed = -1
  }
  
  var isInitialized: Bool {
    return timeCreated < 0
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
    timeLastWitnessed = time
    lastModifier = node
    witness = node
  }
  
  var timeCreated: Int64
  var creator: UUID
  
  var timeLastModified: Int64?
  var lastModifier: UUID?
  
  var timeLastWitnessed: Int64
  var witness: UUID
}
