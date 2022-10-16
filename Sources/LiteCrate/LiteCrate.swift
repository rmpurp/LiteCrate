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

  public init(
    _ location: String
  ) throws {
    db = try Database(location)
    try db.execute("PRAGMA FOREIGN_KEYS = TRUE")
  }

  private func runMigrations() throws {
    let proxy = TransactionProxy(liteCrate: self, database: db)
    try proxy.db.beginTransaction()

    // interpret the current version as "Next migration to run"
    var currentVersion = try proxy.getCurrentSchemaVersion()

    if currentVersion == 0 {
      try proxy.execute("""
      CREATE TABLE CreationRecord (
          id TEXT NOT NULL PRIMARY KEY,
      
          creator TEXT NOT NULL,
          creationNumber INTEGER NOT NULL,
          parent TEXT NOT NULL, -- Empty string if "no parent"
      
          modifier TEXT NOT NULL,
          modificationNumber INTEGER NOT NULL,
      
          sequencer TEXT NOT NULL,
          sequenceNumber INTEGER NOT NULL,
          
          previousCreationNumber INTEGER NOT NULL, -- loops around.

          UNIQUE (creator, creationNumber, parent),
          FOREIGN KEY (creator, parent, previousCreationNumber) REFERENCES CreationRecord DEFERRABLE INITIALLY DEFERRED
      )
      """)

      currentVersion = 1
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
