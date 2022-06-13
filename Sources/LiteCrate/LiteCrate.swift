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
  var replicatingTables = Set<ReplicatingTable>()
  
  public init(_ location: String, @MigrationBuilder migrations: () -> Migration) throws {
    db = try Database(location)
    try runMigrations(migration: migrations())
  }
  
  private func runMigrations(migration: Migration) throws {
    try inTransaction { proxy in
      // interpret the current version as "Next migration to run"
      var currentVersion = try proxy.getCurrentSchemaVersion()
      for (i, migration) in migration.steps.enumerated() {
        migration.resolve(replicatingTables: &replicatingTables)
        if i < currentVersion { continue }
        for action in migration.actions {
          try action.perform(in: proxy)
        }
        currentVersion = Int64(i)
      }
      try proxy.setCurrentSchemaVersion(version: currentVersion)
    }
    
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
