//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import FMDB

@available(macOSApplicationExtension 12.0, *)
extension LiteCrate {
  internal final class TransactionProxy: CrateProxy {
    func executeUpdate(_ sql: String, values: [Any]?) throws {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      try db.executeUpdate(sql, values: values)
    }
    
    func executeQuery<T>(_ sql: String, values: [Any]?, transformOutput: (FMResultSet) throws -> T) throws -> T {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      let rs = try db.executeQuery(sql, values: values)
      defer { rs.close() }
      return try transformOutput(rs)
    }
    
    func executeQuery(_ sql: String, values: [Any]?) throws -> FMResultSet {
      guard isEnabled else {
        fatalError("Do not use this proxy outside of the transaction closure")
      }
      return try db.executeQuery(sql, values: values)
    }
    
    
    func save<T>(_ model: T) throws where T : LCModel {
      let (columnString, placeholders, values) = model.insertValues
      try db.executeUpdate(
        "INSERT OR REPLACE INTO \(T.tableName)(\(columnString)) VALUES (\(placeholders)) ",
        values: values)
    }
    
    func delete<T>(_ model: T) throws where T : LCModel {
      try db.executeUpdate("DELETE FROM \(T.tableName) WHERE id = ?", values: [model.id])
    }
    
    func delete<T>(_ type: T.Type) throws where T : LCModel {
      try delete(type, allWhere: nil, values: nil)
    }
    
    func delete<T>(_ type: T.Type, allWhere sqlWhereClause: String?) throws where T : LCModel {
      try delete(type, allWhere: sqlWhereClause, values: nil)
    }
    
    public func delete<T: LCModel>(_ type: T.Type, with id: T.ID) throws {
      try db.executeUpdate("DELETE FROM \(T.tableName) WHERE id = ?", values: [id])
    }
    
    public func delete<T: LCModel>(_ type: T.Type, allWhere sqlWhereClause: String?, values: [Any]?) throws {
      let sqlWhereClause = sqlWhereClause.flatMap { "WHERE \($0)" } ?? ""
      try db.executeUpdate("DELETE FROM \(T.tableName) \(sqlWhereClause)", values: values)
    }
    
    public func delete(from crate: CrateProxy) throws {
    }
    
    var db: FMDatabase
    var isEnabled = true
    
    init(db: FMDatabase) {
      self.db = db
    }
  }
}
