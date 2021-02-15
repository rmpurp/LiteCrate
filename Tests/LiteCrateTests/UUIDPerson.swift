//
//  UUIDPerson.swift
//
//
//  Created by Ryan Purpura on 12/5/20.
//

import Foundation
import LiteCrate

struct UUIDPerson: LCModel {
  var id: Int64?
  var specialID: UUID
  var optionalID: UUID?
}
