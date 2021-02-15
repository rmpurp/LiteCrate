//
//  File.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import LiteCrate

struct Dog: LCModel {
  var id: Int64?
  var name: String
  var owner: Int64

  init(name: String, owner: Int64) {
    self.name = name
    self.owner = owner
  }
}
