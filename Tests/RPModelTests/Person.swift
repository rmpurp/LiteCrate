//
//  Person.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import RPModel

class Person: RPModel {
  @Column var name: String
  @Column var birthday: Date?
}
