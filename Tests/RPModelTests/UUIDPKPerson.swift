//
//  UUIDPKPerson.swift
//
//
//  Created by Ryan Purpura on 12/7/20.
//

import Foundation
import RPModel

struct UUIDPKPerson: RPModel {

  @Column var id: UUID = UUID()
  @Column var name: String

  init() {}

  init(name: String) {
    self.name = name
  }
}
