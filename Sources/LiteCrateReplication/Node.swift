//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/17/22.
//

import Foundation
import LiteCrate

struct Node: DatabaseCodable, Identifiable {
  var id: UUID
  var time: Int64
}
