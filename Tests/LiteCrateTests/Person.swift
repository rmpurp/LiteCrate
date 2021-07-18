//
//  Person.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import LiteCrate

struct Person: LCModel {
//  var everSynced: Bool = false
//  var isDirty: Bool = true
  
  var id: UUID = UUID()
  var name: String
  var birthday: Date?
}

extension Person: Hashable { }
