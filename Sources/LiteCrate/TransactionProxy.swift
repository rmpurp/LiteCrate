//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import LiteCrateCore

public final class TransactionProxy {
  let nodeID = UUID() // TODO: Fix me.

  public func execute(_ sql: String, _ values: [SqliteRepresentable?] = []) throws {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }
    try db.execute(sql, values)
  }

  public func query(_ sql: String, _ values: [SqliteRepresentable?] = []) throws -> Cursor {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }
    return try db.query(sql, values)
  }

  func merge(_: ReplicatingEntityWithMetadata) throws {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }
  }

  public func save<T>(entityType: String, _ entity: T) throws where T: Codable & Identifiable, T.ID == UUID {
    try save(ReplicatingEntity(entityType: entityType, object: entity))
  }

  public func save(_ entity: ReplicatingEntity) throws {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }

    guard let schema = liteCrate.schemas[entity.entityType] else {
      fatalError()
    }

    if var existingEntityWithMetadata = try fetchWithMetadata(entity.entityType, with: entity.id) {
      existingEntityWithMetadata.merge(entity, sequencer: nodeID, sequenceNumber: TEMPsequenceNumber)
      TEMPsequenceNumber += 1
      try db.execute(schema.insertStatement(), existingEntityWithMetadata.insertValues())
    } else {
      let entityWithMetadata = ReplicatingEntityWithMetadata(
        newReplicatingEntity: entity, creator: nodeID, sequenceNumber: TEMPsequenceNumber
      )
      TEMPsequenceNumber += 1
      try db.execute(schema.insertStatement(), entityWithMetadata.insertValues())
    }
  }

  public func fetch<T>(_ entityType: String, type: T.Type, with id: UUID) throws -> T?
    where T: Codable & Identifiable, T.ID == UUID
  {
    try fetch(entityType, type: type, predicate: "id = ?", [id]).first
  }

  public func fetch(_ entityType: String, with id: UUID) throws -> ReplicatingEntity? {
    try fetch(entityType, predicate: "id = ?", [id]).first
  }

  private func fetchWithMetadata(_ entityType: String, with id: UUID) throws -> ReplicatingEntityWithMetadata? {
    try fetchWithMetadata(entityType, predicate: "id = ?", [id]).first
  }

  public func fetch<T>(_ entityType: String, type _: T.Type, predicate: String = "TRUE",
                       _ values: [SqliteRepresentable?] = []) throws -> [T]
    where T: Codable & Identifiable, T.ID == UUID
  {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }

    guard let schema = liteCrate.schemas[entityType] else { fatalError() }
    let cursor = try db.query(schema.fieldsOnlySelectStatement(predicate: predicate), values)
    let databaseDecorder = DatabaseDecoder(cursor: cursor)

    var returnValue = [T]()
    while cursor.step() {
      try returnValue.append(T(from: databaseDecorder))
    }
    return returnValue
  }

  public func fetch(_ entityType: String, predicate: String = "TRUE",
                    _ values: [SqliteRepresentable?] = []) throws -> [ReplicatingEntity]
  {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }

    guard let schema = liteCrate.schemas[entityType] else { fatalError() }
    let cursor = try db.query(schema.fieldsOnlySelectStatement(predicate: predicate), values)
    var returnValue = [ReplicatingEntity]()
    while cursor.step() {
      returnValue.append(cursor.entity(with: schema))
    }
    return returnValue
  }

  func fetchWithMetadata(_ entityType: String, predicate: String = "TRUE",
                         _: [SqliteRepresentable?] = []) throws -> [ReplicatingEntityWithMetadata]
  {
    guard isEnabled else {
      fatalError("Do not use this proxy outside of the transaction closure")
    }

    guard let schema = liteCrate.schemas[entityType] else { fatalError() }
    let cursor = try db.query(schema.fieldsOnlySelectStatement(predicate: predicate))
    var returnValue = [ReplicatingEntityWithMetadata]()
    while cursor.step() {
      returnValue.append(cursor.entityWithMetadata(with: schema))
    }
    return returnValue
  }

  // MARK: - Old stuff below

//    guard var node = try fetch(Node.self, with: nodeID) else { return }
//
//    let encoder = DatabaseEncoder()
//    try model.encode(to: encoder)
//
//    if var objectRecord = try fetch(ObjectRecord.self, with: model.id),
//       let oldModel = try fetch(T.self, with: model.id)
//    {
//      // The model already exists; set us as the latest sequencer and bump the lamport.
//      objectRecord.lamport += 1
//      objectRecord.sequencer = nodeID
//      objectRecord.sequenceNumber = node.nextSequenceNumber
//
//      if try foreignKeyValueHasChanged(
//        oldModel: oldModel,
//        newForeignKeyValues: encoder.foreignKeyValues(table: T.table)
//      ) {
//        // When a foreign key changes, this is considered a rebirth of the object. The reason behind this is changing a
//        // foreign key typically signifies moving the object to a different category, etc., so if it gets concurrently
//        // deleted on another node, the moved object does not get deleted.
//        objectRecord.creator = nodeID
//        objectRecord.creationNumber = node.nextCreationNumber
//        node.nextCreationNumber += 1
//        // TODO: Should this need to delete foreign key dependencies? My guess is no, but I need to think about the
//        // implications. Actually, this should probably rebirth the dependencies, as well. Yikes...
//      }
//
//      try save(objectRecord)
//    } else {
//      // The model does not exist or needs to be recreated; create a new one and bump the node's creation number.
//      let objectRecord = ObjectRecord(id: model.id, creator: node)
//      try save(objectRecord)
//      node.nextCreationNumber += 1
//    }
//    // Regardless, we bump the node's sequence number and save it.
//    node.nextSequenceNumber += 1
//    try save(node)
//
//    try db.execute(T.table.insertStatement(), encoder.insertValues)

  public func delete<T: ReplicatingModel>(_: T) throws {
//    guard let objectRecord = try fetch(ObjectRecord.self, with: model.id) else { return }
//    try delete(objectRecord: objectRecord)
  }

  private func mergeRangeAndDeleteMatchingModels(_ range: EmptyRange) throws {
//    let overlappingRanges = try fetch(EmptyRange.self, where: "node = ? AND start <= ? and end >= ?",
//                                      [range.end + 1, range.start - 1])
//    var range = range
//    for overlappingRange in overlappingRanges {
//      range.start = min(range.start, overlappingRange.start)
//      range.end = max(range.end, overlappingRange.end)
//      try delete(overlappingRange)
//    }

    try execute("DELETE FROM ObjectRecord WHERE creator = ? AND ? <= creationNumber AND creationNumber >= ?",
                [range.node, range.start, range.end])

//    try save(range)
  }

  public func delete<T: DatabaseCodable>(_: T, where sqlWhereClause: String = "TRUE",
                                         _ values: [SqliteRepresentable?] = []) throws
  {
    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(sqlWhereClause)", values)
  }

  public func delete<T: DatabaseCodable, U: SqliteRepresentable>(_: T.Type, with primaryKey: U) throws {
    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(T.table.primaryKeyColumn) = ?", [primaryKey])
  }

  #warning(" persist sequence number, node")
  internal var liteCrate: LiteCrate
  internal var TEMPsequenceNumber: Int64 = 0
  internal var db: Database
  internal var isEnabled = true

  internal init(liteCrate: LiteCrate, database: Database) {
    self.liteCrate = liteCrate
    db = database
  }
}

internal extension TransactionProxy {
  func getCurrentSchemaVersion() throws -> Int64 {
    let cursor = try query("PRAGMA user_version")

    if cursor.step() {
      let currentVersion = cursor.int(for: 0)
      NSLog("DB at version %d", currentVersion)
      return currentVersion
    } else {
      fatalError("TODO: Change this to reasonable error")
    }
  }

  func setCurrentSchemaVersion(version: Int64) throws {
    try execute(String(format: "PRAGMA user_version = %lld", version), [])
    // Being very careful to avoid injection vulnerability; ? is not valid here.
  }
}
