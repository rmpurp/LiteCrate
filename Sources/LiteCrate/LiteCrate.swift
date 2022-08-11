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
          INSERT INTO Field VALUES (?1, 'Node', ?1, 0, 0, 'id', ?1), (?1, 'Node', ?1, 0, 0, 'nextSequenceNumber', 0)
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

      try proxy.execute("""
      CREATE TABLE Field (
          objectID TEXT NOT NULL,
          objectType TEXT NOT NULL,
          sequencer TEXT NOT NULL,
          sequenceNumber INTEGER NOT NULL,
          lamport INTEGER NOT NULL,
          key TEXT NOT NULL,
          value BLOB,
          PRIMARY KEY (objectID, key),
          FOREIGN KEY (objectID, objectType) REFERENCES ObjectRecord(id, type)
      )
      """)
      
      try proxy.execute("""
      CREATE VIEW FieldInput AS
          SELECT
              objectID AS objectID,
              objectType AS objectType,
              sequencer AS sequencer,
              sequenceNumber AS sequenceNumber,
              lamport AS lamport,
              key AS key,
              value AS value
          FROM Field;
      """)

      try proxy.execute("""
      CREATE TRIGGER InsertFieldTrigger INSTEAD OF INSERT ON FieldInput BEGIN
          SELECT RAISE(IGNORE) FROM Field
                  WHERE NEW.lamport IS NULL AND objectID = NEW.objectID AND key = NEW.key AND value = NEW.value;

          SELECT RAISE(IGNORE) FROM Field
                  WHERE objectID = NEW.objectID AND key = NEW.key AND (
                      lamport > NEW.lamport
                      OR lamport = NEW.lamport AND value >= NEW.value
                  );
                        
          INSERT OR REPLACE INTO Field VALUES (
              NEW.objectID,
              NEW.objectType,
              NEW.sequencer,
              NEW.sequenceNumber,
              COALESCE(NEW.lamport, 1 + (SELECT lamport FROM Field WHERE objectID = NEW.objectID AND key = NEW.key), 0),
              NEW.key,
              NEW.value
          );
          --ON CONFLICT DO UPDATE SET
          --    lamport = max(lamport, excluded.lamport),
          --    value = iif(lamport = excluded.lamport,
          --            max(value, excluded.value),
          --                iff(lamport < excluded.lamport,
          --                    excluded.value,
          --                    value));
      END
      """)
      
//      try proxy.execute("CREATE UNIQUE INDEX __FKObjectReferenceIndex__ ON ForeignKeyField (objectID, referenceID)")
//      try proxy.execute("CREATE INDEX __FKObjectIndex__ ON ForeignKeyField (objectID)")
//      try proxy.execute("CREATE INDEX __FKReferenceIndex__ ON ForeignKeyField (referenceID)")
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
