//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrate

struct Dot<Model: ReplicatingModel>: DatabaseCodable, Identifiable {
  var id: UUID
  var modelID: UUID?

  var timeCreated: Int64
  var creator: UUID
  
  var timeLastModified: Int64?
  var lastModifier: UUID?
  
  var timeLastWitnessed: Int64
  var witness: UUID
  
  init(modelID: UUID, time: Int64, creator: UUID) {
    self.id = UUID()
    self.modelID = modelID
    self.timeCreated = time
    self.creator = creator
    self.timeLastModified = time
    self.lastModifier = creator
    self.timeLastWitnessed = time
    self.witness = creator
  }
  
  static var tableName: String {
    "crdt_" + Model.tableName
  }

  static var foreignKeys: [ForeignKey] {
    return [ForeignKey("modelID", references: Model.tableName, targetColumn: Model.primaryKeyColumn, onDelete: .restrict)]
  }
}
