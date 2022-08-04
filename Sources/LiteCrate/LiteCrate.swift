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

  public init(
    _ location: String,
    @MigrationBuilder migrations: () -> Migration
  ) throws {
    db = try Database(location)
    try db.execute("PRAGMA FOREIGN_KEYS = TRUE")
    try runMigrations(migration: migrations())
  }

  private func runMigrations(migration: Migration) throws {
    let proxy = TransactionProxy(db: db)
    try proxy.db.beginTransaction()

    // interpret the current version as "Next migration to run"
    var currentVersion = try proxy.getCurrentSchemaVersion()

    if currentVersion == 0 {
      // TODO: Setup.
      try proxy.execute(Node.table.createTableStatement())
      try proxy.execute(ObjectRecord.table.createTableStatement())
      try proxy.execute(ForeignKeyField.table.createTableStatement())
      try proxy.execute(EmptyRange.table.createTableStatement())
      try proxy.execute("CREATE UNIQUE INDEX __FKObjectReferenceIndex__ ON ForeignKeyField (objectID, referenceID)")
      try proxy.execute("CREATE INDEX __FKObjectIndex__ ON ForeignKeyField (objectID)")
      try proxy.execute("CREATE INDEX __FKReferenceIndex__ ON ForeignKeyField (referenceID)")
      // TODO: Indexes for empyty range, object record
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
    let proxy = TransactionProxy(db: db)

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
