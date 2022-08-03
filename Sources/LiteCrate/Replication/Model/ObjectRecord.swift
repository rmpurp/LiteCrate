//
//  File.swift
//
//
//  Created by Ryan Purpura on 7/31/22.
//

import Foundation

/// A record of a replicating model object.

struct ObjectRecord: DatabaseCodable {
  // The id of the record
  var id: UUID
  var creator: UUID
  var creationNumber: Int64
  var sequencer: UUID
  var sequenceNumber: Int64
  var lamport: Int64

  init(id: UUID, creator: Node) {
    self.id = id
    self.creator = creator.id
    creationNumber = creator.nextCreationNumber
    sequencer = creator.id
    sequenceNumber = creator.nextSequenceNumber
    lamport = 0
  }

  static var table = Table("ObjectRecord") {
    Column(name: "id", type: .text).primaryKey()
    Column(name: "creator", type: .text)
    Column(name: "creationNumber", type: .integer)
    Column(name: "sequencer", type: .text)
    Column(name: "sequenceNumber", type: .integer)
    Column(name: "lamport", type: .integer)
  }
}
