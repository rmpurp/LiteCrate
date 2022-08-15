//
//  File.swift
//  
//
//  Created by Ryan Purpura on 8/12/22.
//

import Foundation
import LiteCrateCore

struct CompleteFieldData {
  var lamport: Int64
  var sequencer: UUID
  var sequenceNumber: Int64
  var value: ExtendedSqliteValue?
}

enum FieldType {
  case dataOnly(fields: [String: ExtendedSqliteValue?])
  case dataAndMetadata(fields: [String: CompleteFieldData])
}

struct ReplicatingEntityWithMetadata {
  var fields: [String: CompleteFieldData]
  let id: UUID
  
  init(id: UUID, fields: [String: CompleteFieldData]) {
    self.fields = fields
    self.id = id
  }
  
  init(newReplicatingEntity: ReplicatingEntity, creator: UUID, sequenceNumber: Int64) {
    fields = [:]
    id = newReplicatingEntity.id
    for (key, value) in newReplicatingEntity.fields {
      fields[key] = CompleteFieldData(lamport: 0, sequencer: creator, sequenceNumber: sequenceNumber, value: value)
    }
  }
  
  mutating func merge(_ entity: ReplicatingEntity, sequencer: UUID, sequenceNumber: Int64) {
    for (key, value) in entity.fields {
      guard var existing = fields[key] else { fatalError("Incompatible schema!") }
      if existing.value != value {
        existing.value = value
        existing.sequencer = sequencer
        existing.sequenceNumber = sequenceNumber
        fields[key] = existing
      }
    }
  }
  
  mutating func merge(_ entity: ReplicatingEntityWithMetadata) {
    for (key, otherField) in entity.fields {
      guard let existing = fields[key] else { fatalError("Incompatible schema!") }
      if existing.lamport < otherField.lamport
          || existing.lamport == otherField.lamport
              && otherField.sequencer.uuidString > existing.sequencer.uuidString {
        fields[key] = otherField
      }
    }
  }
  
  func insertValues() -> [String: SqliteRepresentable?] {
    var insertDict = [String: SqliteRepresentable?]()
    insertDict["id"] = id
    for (key, field) in fields {
      insertDict[key] = field.value
      // TODO: make this unified with EntitySchema
      insertDict["\(key)__lamport"] = field.lamport
      insertDict["\(key)__sequencer"] = field.sequencer
      insertDict["\(key)__sequenceNumber"] = field.sequenceNumber
    }
    return insertDict
  }
}

public struct ReplicatingEntity {
  public let entityType: String
  public let id: UUID
  public private(set) var fields: [String: ExtendedSqliteValue?]

  public init(entityType: String, id: UUID) {
    self.entityType = entityType
    self.id = id
    self.fields = [:]
  }

  public subscript(_ key: String) -> ExtendedSqliteValue? {
    get {
      return fields[key]!
    }
    set {
      fields[key] = newValue
    }
  }
}
