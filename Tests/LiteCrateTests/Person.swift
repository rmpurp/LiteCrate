//
//  Person.swift
//
//
//  Created by Ryan Purpura on 11/24/20.
//

import Foundation
import LiteCrate

struct Person: DatabaseCodable {
  var id: UUID = UUID()
  var name: String
  var birthday: Date?
  var dogID: UUID
  
//  static var foreignKeys = [ForeignKey("dogID", references: "Dog", targetColumn: "id"), ForeignKey(["catID1", "catID2"], references: "Cat", targetColumns: ["id1", "id2"], onCascadeDelete: true)]
}

extension Person: Hashable { }
