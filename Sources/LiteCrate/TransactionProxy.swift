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
  
  public func fetch<T: DatabaseCodable, U: SqliteRepresentable>(_ type: T.Type, with primaryKey: U) throws -> T? {
    try fetch(type, where: "\(T.table.primaryKeyColumn) = ?", [primaryKey]).first
  }

  public func fetch<T: DatabaseCodable>(_: T.Type, where sqlWhereClause: String? = nil,
                                        _ values: [SqliteRepresentable?] = []) throws -> [T]
  {
    let sqlWhereClause = sqlWhereClause ?? "TRUE"

    let cursor = try db.query(T.table.selectStatement(where: sqlWhereClause), values)
    let decoder = DatabaseDecoder(cursor: cursor)
    var models = [T]()
    while cursor.step() {
      let model = try T(from: decoder)
      models.append(model)
    }
    return models
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

  public func save<T: DatabaseCodable>(_ model: T) throws {
    let encoder = DatabaseEncoder()
    try model.encode(to: encoder)
    try db.execute(T.table.insertStatement(), encoder.insertValues)
  }

  public func save<T: ReplicatingModel>(_ model: T) throws {
    guard var node = try fetch(Node.self, with: nodeID) else { return }
    
    
    if var objectRecord = try fetch(ObjectRecord.self, with: model.id) {
      // The model already exists; set us as the latest sequencer and bump the lamport.
      objectRecord.lamport += 1
      objectRecord.sequencer = nodeID
      objectRecord.sequenceNumber = node.nextSequenceNumber
      try save(objectRecord)
    } else {
      // The model does not exist (as far as we know), create a new one and bump the node's creation number.
      let objectRecord = ObjectRecord(id: model.id, creator: node)
      try save(objectRecord)
      node.nextCreationNumber += 1
    }
    // Regardless, we bump the node's sequence number and save it.
    node.nextSequenceNumber += 1
    try save(node)
    
    let encoder = DatabaseEncoder()
    try model.encode(to: encoder)
    try db.execute(T.table.insertStatement(), encoder.insertValues)
  }
  
  public func delete<T: DatabaseCodable>(_: T, where sqlWhereClause: String = "TRUE", _ values: [SqliteRepresentable?] = []) throws {
    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(sqlWhereClause)", values)
  }

  public func delete<T: DatabaseCodable, U: SqliteRepresentable>(_: T.Type, with primaryKey: U) throws {
    try db.execute("DELETE FROM \(T.table.tableName) WHERE \(T.table.primaryKeyColumn) = ?", [primaryKey])
  }

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
