//
//  UUIDPKPerson.swift
//
//
//  Created by Ryan Purpura on 12/7/20.
//

import Foundation
import LiteCrate

struct UUIDPKPerson: LCModel {
  var id: UUID = UUID()
  var name: String

  init(name: String) {
    self.name = name
  }
}
