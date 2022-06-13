//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrateCore

struct Metadata<Model: ReplicatingModel>: DatabaseCodable {
  
  typealias Key = UUID

  var version: UUID
  var modelID: UUID?
  var lamport: Int64
  var sequenceLamport: Int64
  // Stop trying to optimize the sequenceLamport out.
  // It's here for when things get merged in -- the sequence
  // lamport will be set to when it was merged in, not when it was last modified.
  
  static var tableName: String {
    "crdt_" + Model.tableName
  }
  
  static var primaryKeyColumn: String {
    "version"
  }
  
  var primaryKeyValue: UUID {
    version
  }
  
  static var foreignKeys: [ForeignKey] {
    return [ForeignKey("modelID", references: Model.tableName, targetColumn: Model.primaryKeyColumn, onDelete: .restrict)]
  }
}
