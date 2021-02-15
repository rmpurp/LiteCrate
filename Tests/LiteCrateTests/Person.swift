//
//  Person.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import LiteCrate

struct Person: LCModel {
  var id: Int64?
  var name: String
  var birthday: Date?
}
