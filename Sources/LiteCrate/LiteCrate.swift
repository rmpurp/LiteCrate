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
  var nodeID: UUID
  
  public init(_ location: String, nodeID: UUID, @MigrationBuilder migrations: () -> Migration) throws {
    self.db = try Database(location)
    self.nodeID = nodeID
    try runMigrations(migration: migrations())
  }
  
  private func runMigrations(migration: Migration) throws {
    let proxy = TransactionProxy(db: db, node: nodeID)
    try proxy.db.beginTransaction()
    
    // interpret the current version as "Next migration to run"
    var currentVersion = try proxy.getCurrentSchemaVersion()
    if currentVersion == 0 {
      try Execute("CREATE TABLE Node(id TEXT PRIMARY KEY, time INT NOT NULL)").perform(in: proxy)
      currentVersion = 1
    }
    
    for (i, migration) in migration.steps.enumerated() {
      let step = i + 1
      migration.resolve(replicatingTables: &replicatingTables)
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
    let proxy = TransactionProxy(db: db, node: nodeID)
    
    defer { proxy.isEnabled = false }
    
    do {
      try proxy.beginTransaction()
      
      let returnValue = try block(proxy)
      try proxy.incrementTimeIfNeeded()
      try proxy.db.commit()
      proxy.isEnabled = false
      return returnValue
    } catch {
      try proxy.db.rollback()
      throw error
    }
  }
}
