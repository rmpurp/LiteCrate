//
//  File.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import RPModel

struct Dog: RPModel {
  init() {
    
  }
  
  @Column var id: Int64
  @Column var name: String
  @Column var owner: Int64

  init(name: String, owner: Int64) {
    self.name = name
    self.owner = owner
  }
}


