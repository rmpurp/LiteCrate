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
  private var delegate: (any DatabaseDelegate)?
  var nodeID: UUID
  
  public init(_ location: String, delegate: (any DatabaseDelegate)? = nil, nodeID: UUID, @MigrationBuilder migrations: () -> Migration) throws {
    self.db = try Database(location)
    self.delegate = delegate
    self.nodeID = nodeID
    try runMigrations(migration: migrations())
  }
  
  private func runMigrations(migration: Migration) throws {
    let proxy = TransactionProxy(db: db, delegate: delegate, node: nodeID)

    // Don't call delegate transaction method.
    try proxy.db.beginTransaction()
    
    // interpret the current version as "Next migration to run"
    var currentVersion = try proxy.getCurrentSchemaVersion()
    if currentVersion == 0 {
      try delegate?.migrationDidInitialize(proxy)
      currentVersion = 1
    }
    
    for (i, migration) in migration.steps.enumerated() {
      let step = i + 1
      if step < currentVersion { continue }
      for action in migration.actions {
        try delegate?.migrationActionWillRun(action)
        try action.perform(in: proxy)
        try delegate?.migrationActionDidRun(action)
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
    let proxy = TransactionProxy(db: db, delegate: delegate, node: nodeID)
    
    defer { proxy.isEnabled = false }
    
    do {
      try proxy.db.beginTransaction()
      try delegate?.transactionDidBegin(proxy)
      let returnValue = try block(proxy)
      try delegate?.transactionWillCommit(proxy)
      try proxy.db.commit()
      proxy.isEnabled = false
      return returnValue
    } catch {
      try proxy.db.rollback()
      throw error
    }
  }
}
