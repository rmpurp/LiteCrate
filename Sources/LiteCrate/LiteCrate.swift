//
//  RPModelDatabase.swift
//
//
//  Created by Ryan Purpura on 12/6/20.
//

import Foundation
//import sqlite3
import LiteCrateCore

enum LiteCrateError: Error {
  case commitError
}

public class LiteCrate {
  private var db: Database
  
  public init(url: URL?, migration: (TransactionProxy, inout Int64) throws -> Void) throws {
    db = try Database(url?.absoluteString ?? ":memory:")
    
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

//// MARK: - CRUD
//extension LiteCrate {
//  public func execute(_ sql: String, [SqliteRepresentable] = []) throws {
//    try inTransaction { proxy in
//      try proxy.execute(sql, values: values)
//    }
//  }
//
//  public func executeQuery(_ sql: String, values: [Any]? = nil) throws -> Cursor {
//    try inTransaction { proxy in
//      try proxy.executeQuery(sql, values: values)
//    }
//  }
//
//  public func save<T>(_ model: T) throws where T : LCModel {
//    try inTransaction { proxy in
//      try proxy.save(model)
//    }
//  }
//
//
//  public func fetch<T>(_ type: T.Type, with id: T.ID) throws -> T? where T : LCModel {
//    try inTransaction { proxy in
//      try proxy.fetch(type, with: id)
//    }
//  }
//
//  public func fetch<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws -> [T] where T : LCModel {
//    try inTransaction { proxy in
//      try proxy.fetch(type, allWhere: sqlWhereClause, values: values)
//    }
//  }
//
//  public func delete<T>(_ model: T) throws where T : LCModel {
//    try inTransaction { proxy in
//      try proxy.delete(model)
//    }
//  }
//
//  public func delete<T>(_ type: T.Type, with id: T.ID) throws where T : LCModel {
//    try inTransaction { proxy in
//      try proxy.delete(type, with: id)
//    }
//  }
//
//  public func delete<T>(_ type: T.Type, allWhere sqlWhereClause: String? = nil, values: [Any]? = nil) throws where T : LCModel {
//    try inTransaction { proxy in
//      try proxy.delete(type, allWhere: sqlWhereClause, values: values)
//    }
//  }
//}
