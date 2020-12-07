//
//  Person.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import RPModel

struct Person: RPModel {
  @Column var id: Int64?
  @Column var name: String
  @Column var birthday: Date?
}
