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

  public func fetch<T: ReplicatingModel>(_ type: T.Type, with primaryKey: UUID) throws -> T? {
//    try fetch(type, where: "\(T.table.primaryKeyColumn) = ?", [primaryKey]).first
    let cursor = try db.query("SELECT json_group_object(key, value) FROM Field WHERE objectID = ?", [primaryKey])
    if cursor.step() {
      let json = cursor.data(for: 0)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .secondsSince1970
      return try decoder.decode(T.self, from: json)
    }
    return nil
  }
  
  public func fetch<T: ReplicatingModel>(_: T.Type) throws -> [T] {
    let statement = """
      SELECT json_group_object(key, value) FROM Field
          WHERE objectType = ?
          GROUP BY objectID
    """
    
    let cursor = try db.query(statement, [T.objectName])
    var results = [T]()
    while cursor.step() {
      let json = cursor.data(for: 0)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .secondsSince1970
      results.append(try decoder.decode(T.self, from: json))
    }
    return results
  }
  
  public func fetch<T: ReplicatingModel>(_: T.Type, field: String, where sqlWhereClause: String,
                                        _ values: [SqliteRepresentable?] = []) throws -> [T]
  {
    let statement = """
      SELECT json_group_object(key, value) FROM Field
          WHERE objectID IN
              (SELECT objectID FROM Field WHERE objectType = ? AND key = ? AND \(sqlWhereClause))
          GROUP BY objectID
    """

    let cursor = try db.query(statement, [T.objectName, field] + values)
    var results = [T]()
    while cursor.step() {
      let json = cursor.data(for: 0)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .secondsSince1970
      results.append(try decoder.decode(T.self, from: json))
    }
    return results
  }

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
  
  func save(_ entity: ReplicatingEntity) throws {
    guard let schema = liteCrate.schemas[entity.entityType] else {
      fatalError()
    }
    
    try db.execute(schema.insertStatement(), entity.fields)
  }
  
  public func save<T: DatabaseCodable>(_ model: T) throws {
    let encoder = DatabaseEncoder()
    try model.encode(to: encoder)
    try db.execute(T.table.insertStatement(), encoder.insertValues)
  }

  private func foreignKeyValueHasChanged<T: ReplicatingModel>(
    oldModel: T,
    newForeignKeyValues: [String: SqliteValue?]
  ) throws -> Bool {
    let encoder = DatabaseEncoder()
    try oldModel.encode(to: encoder)
    return encoder.foreignKeyValues(table: T.table) != newForeignKeyValues
  }
  
  private func objectDoesExist(id: UUID) throws -> Bool {
    return try db.query("SELECT id FROM ObjectRecord WHERE id = ?", [id]).step()
  }

  public func save<T: ReplicatingModel>(_ model: T, lamport: Int64? = nil, parents: [UUID] = []) throws {
    var parents = parents
    if parents.isEmpty {
      parents.append(nodeID)
    }
    
    try db.execute("INSERT OR IGNORE INTO ObjectRecord(id, objectType) VALUES (?, ?)", [model.id, T.objectName])
    
    let jsonEncoder = JSONEncoder()
    jsonEncoder.dateEncodingStrategy = .secondsSince1970
    let modelJSON = try jsonEncoder.encode(model)
    let statement = """
    INSERT INTO FieldInput SELECT ?, ?, ?, ?, ?, key, value FROM json_each(?)
    """
    #warning("Fix sequence stuff")
    try db.execute(statement, [model.id, T.objectName, nodeID, 0, lamport, modelJSON])
    
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
  }

  public func delete<T: ReplicatingModel>(_ model: T) throws {
//    guard let objectRecord = try fetch(ObjectRecord.self, with: model.id) else { return }
//    try delete(objectRecord: objectRecord)
  }

  private func delete(objectRecord: ObjectRecord) throws {
    guard var node = try fetch(Node.self, with: nodeID) else { return }

//    for fkField in try fetch(ForeignKeyField.self, where: "referenceID = ?", [objectRecord.id]) {
//      guard fkField.objectID != fkField.referenceID,
//            let objectRecord = try fetch(ObjectRecord.self, with: fkField.objectID) else { continue }
//      try delete(objectRecord: objectRecord)
//    }
//
    let emptyRange = EmptyRange(objectRecord: objectRecord, sequencer: node)
    node.nextSequenceNumber += 1
    try save(node)
    try mergeRangeAndDeleteMatchingModels(emptyRange)
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

    try save(range)
  }

  public func delete<T: DatabaseCodable>(_: T, where sqlWhereClause: String = "TRUE",
                                         _ values: [SqliteRepresentable?] = []) throws
  {
    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(sqlWhereClause)", values)
  }

  public func delete<T: DatabaseCodable, U: SqliteRepresentable>(_: T.Type, with primaryKey: U) throws {
    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(T.table.primaryKeyColumn) = ?", [primaryKey])
  }

#warning("Fix me")
  internal var liteCrate: LiteCrate!
  internal var db: Database
  internal var isEnabled = true

  internal init(db: Database) {
    self.db = db
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
