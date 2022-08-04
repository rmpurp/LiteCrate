//
//  File.swift
//
//
//  Created by Ryan Purpura on 8/3/22.
//

import Foundation

struct ForeignKeyField: DatabaseCodable {
  var id: Int64?
  var objectID: UUID
  var referenceID: UUID

  static var table = Table("ForeignKeyField") {
    Column(Self.CodingKeys.id, type: .integer).primaryKey()
    Column(Self.CodingKeys.objectID, type: .text)
    Column(Self.CodingKeys.referenceID, type: .text)
  }
}
