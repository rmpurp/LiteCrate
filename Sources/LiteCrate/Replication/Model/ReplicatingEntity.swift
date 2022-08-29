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
  var value: SQLiteValue?
}

enum FieldType {
  case dataOnly(fields: [String: SQLiteValue?])
  case dataAndMetadata(fields: [String: CompleteFieldData])
}

struct ReplicatingEntityWithMetadata {
  let entityType: String
  var fields: [String: CompleteFieldData]
  let id: UUID

  init(entityType: String, id: UUID, fields: [String: CompleteFieldData]) {
    self.entityType = entityType
    self.fields = fields
    self.id = id
  }

  init(newReplicatingEntity: ReplicatingEntity, creator: UUID, sequenceNumber: Int64) {
    entityType = newReplicatingEntity.entityType
    fields = [:]
    id = newReplicatingEntity.id
    for (key, value) in newReplicatingEntity.fields {
      fields[key] = CompleteFieldData(lamport: 0, sequencer: creator, sequenceNumber: sequenceNumber, value: value)
    }
  }

  mutating func merge(_ entity: ReplicatingEntity, sequencer: UUID, sequenceNumber: Int64) {
    precondition(entityType == entity.entityType)
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
    precondition(entityType == entity.entityType)

    for (key, otherField) in entity.fields {
      guard let existing = fields[key] else { fatalError("Incompatible schema!") }
      if existing.lamport < otherField.lamport
        || existing.lamport == otherField.lamport
        && otherField.sequencer.uuidString > existing.sequencer.uuidString
      {
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
  public private(set) var fields: [String: SQLiteValue?]

  public init(entityType: String, id: UUID) {
    self.entityType = entityType
    self.id = id
    fields = [:]
  }

  public init<T>(entityType: String, object: T) throws where T: Codable & Identifiable, T.ID == UUID {
    id = object.id
    self.entityType = entityType
    let encoder = DatabaseEncoder()
    try object.encode(to: encoder)
    fields = encoder.insertValues
  }

  func int64(for key: String) -> Int64 {
    guard case let .integer(val) = fields[key] else { fatalError() }
    return val
  }

  func string(for key: String) -> String {
    guard case let .text(val) = fields[key] else { fatalError() }
    return val
  }

  func bool(for key: String) -> Bool {
    guard case let .bool(val) = fields[key] else { fatalError() }
    return val
  }

  func data(for key: String) -> Data {
    guard case let .blob(val) = fields[key] else { fatalError() }
    return val
  }

  func uuid(for key: String) -> UUID {
    guard case let .uuid(val) = fields[key] else { fatalError() }
    return val
  }

  func date(for key: String) -> Date {
    guard case let .date(val) = fields[key] else { fatalError() }
    return val
  }

  func isNull(for key: String) -> Bool {
    guard let value = fields[key] else { fatalError() }
    return value == nil
  }

  public subscript(_ key: String) -> SQLiteValue? {
    get {
      fields[key]!
    }
    set {
      fields[key] = newValue
    }
  }
}
