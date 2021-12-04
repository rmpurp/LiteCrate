//
//  RPModelDatabase.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import FMDB
import Foundation
import SQLite3


enum LiteCrateError: Error {
  case commitError
}

public class LiteCrate {
  private var db: FMDatabase
  
  public init(url: URL?, migration: (TransactionProxy, inout Int64) throws -> Void) throws {
    db = FMDatabase(url: url)
    db.open()
    
    try inTransaction { db in
      var currentVersion = try db.getCurrentSchemaVersion()
      try migration(db, &currentVersion)
      try db.setCurrentSchemaVersion(version: currentVersion)
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
      proxy.db.beginTransaction()
      
      let returnValue = try block(proxy)
      let success = proxy.db.commit()
      proxy.isEnabled = false
      if !success { throw LiteCrateError.commitError }
      
      return returnValue
    } catch {
      proxy.db.rollback()
      throw error
    }
  }
}

// MARK: - CRUD
extension LiteCrate {
  public func executeUpdate(_ sql: String, values: [Any]? = nil) throws {
    try inTransaction { proxy in
      try proxy.executeUpdate(sql, values: values)
    }
  }
  
  public func executeQuery(_ sql: String, values: [Any]? = nil) throws -> FMResultSet {
    try inTransaction { proxy in
      try proxy.executeQuery(sql, values: values)
    }
  }
  
  public func executeQuery<T>(_ sql: String, values: [Any]? = nil, transformOutput: (FMResultSet) throws -> T) throws -> T {
    try inTransaction { proxy in
      try proxy.executeQuery(sql, values: values, transformOutput: transformOutput)
    }
  }
  
  public func save<T>(_ model: T) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.save(model)
    }
  }
  
  
  public func fetch<T>(_ type: T.Type, with id: T.ID) throws -> T? where T : LCModel {
    try inTransaction { proxy in
      try proxy.fetch(type, with: id)
    }
  }
  
  public func fetch<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws -> [T] where T : LCModel {
    try inTransaction { proxy in
      try proxy.fetch(type, allWhere: sqlWhereClause, values: values)
    }
  }
  
  public func delete<T>(_ model: T) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.delete(model)
    }
  }
  
  public func delete<T>(_ type: T.Type, with id: T.ID) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.delete(type, with: id)
    }
  }
  
  public func delete<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws where T : LCModel {
    try inTransaction { proxy in
      try proxy.delete(type, allWhere: sqlWhereClause, values: values)
    }
  }
}
