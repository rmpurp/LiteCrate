//
//  RPModelDatabase.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import Foundation
import LiteCrateCore

enum LiteCrateError: Error {
  case commitError
}

public class LiteCrate {
  private var db: Database
  let nodeID = UUID() // TODO: Fix me.
  private(set) var schemas = [String: EntitySchema]()
  
  public init(
    _ location: String,
    @MigrationBuilder migrations: () -> Migration
  ) throws {
    db = try Database(location)
    try db.execute("PRAGMA FOREIGN_KEYS = TRUE")
    try runMigrations(migration: migrations())
  }
  
  public func register(_ schema: EntitySchema) {
    schemas[schema.name] = schema
  }

  private func runMigrations(migration: Migration) throws {
    let proxy = TransactionProxy(liteCrate: self, database: db)
    try proxy.db.beginTransaction()

    // interpret the current version as "Next migration to run"
    var currentVersion = try proxy.getCurrentSchemaVersion()

    if currentVersion == 0 {
      // TODO: Setup.
//      try proxy.execute(Node.table.createTableStatement())
//      try proxy.execute(ObjectReacord.table.createTableStatement())
//      try proxy.execute(ForeignKeyField.table.createTableStatement())
//      try proxy.execute(EmptyRange.table.createTableStatement())
      try proxy.execute("""
      CREATE TABLE ObjectRecord (
          id TEXT NOT NULL PRIMARY KEY,
          objectType TEXT NOT NULL,
          nextCreationNumber INTEGER NOT NULL DEFAULT 0, -- Local. Set to 0 if receiving and DNE.
          UNIQUE (id, objectType)
      )
      """)
      
      // Bootstrap this node.
      try proxy.execute("""
          INSERT INTO ObjectRecord VALUES (?, 'Node', 0)
      """, [nodeID])

      try proxy.execute("""
      CREATE TABLE DeletedRange (
          parentObject TEXT REFERENCES ObjectRecord ON DELETE CASCADE,
          sequencer TEXT NOT NULL,
          sequenceNumber INTEGER NOT NULL,
          start INTEGER NOT NULL,
          end INTEGER NOT NULL
      )
      """)

      try proxy.execute("""
      CREATE TABLE CreationRecord (
          id TEXT PRIMARY KEY REFERENCES ObjectRecord (id),
          creationNumber INTEGER NOT NULL,
          parentObject TEXT NOT NULL
      )
      """)
      currentVersion = 1
    }

    for (i, migration) in migration.steps.enumerated() {
      let step = i + 1
      if step < currentVersion { continue }
      for action in migration.actions {
        try action.perform(in: proxy)
      }
      currentVersion = Int64(step)
    }

    try proxy.setCurrentSchemaVersion(version: currentVersion)
    try proxy.db.commit()
  }

  public func close() {
    db.close()
  }

  @discardableResult
  public func inTransaction<T>(block: (TransactionProxy) throws -> T) throws -> T {
    let proxy = TransactionProxy(liteCrate: self, database: db)

    defer { proxy.isEnabled = false }
    do {
      try proxy.db.beginTransaction()
      let returnValue = try block(proxy)
      try proxy.db.commit()
      proxy.isEnabled = false
      return returnValue
    } catch {
      try proxy.db.rollback()
      throw error
    }
  }
}
