//
//  Person.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
@testable import LiteCrate

struct Person: DatabaseCodable, Identifiable {
  var id: UUID = .init()
  var name: String
  var birthday: Date?
  var dogID: UUID
  //  static var foreignKeys = [ForeignKey("dogID", references: "Dog", targetColumn: "id"), ForeignKey(["catID1", "catID2"], references: "Cat", targetColumns: ["id1", "id2"], onCascadeDelete: true)]
}

extension Person: Hashable {
  static func == (lhs: Person, rhs: Person) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
