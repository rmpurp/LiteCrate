//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrateCore

public protocol LiteCrateDelegate {
  func transactionDidBegin(_ proxy: LiteCrate.TransactionProxy) throws
  func transactionWillCommit(_ proxy: LiteCrate.TransactionProxy) throws
  func migrationDidInitialize(_ proxy: LiteCrate.TransactionProxy) throws
  func migrationActionWillRun<A: MigrationAction>(_ action: A) throws
  func model<T: DatabaseCodable>(_ model: T, willSaveIn proxy: LiteCrate.TransactionProxy) throws
  func model<T: DatabaseCodable>(_ model: T, willDeleteIn proxy: LiteCrate.TransactionProxy) throws
  func migrationActionDidRun<A: MigrationAction>(_ action: A) throws
}

public extension LiteCrateDelegate {
  func transactionDidBegin(_ proxy: LiteCrate.TransactionProxy) throws {}
  func transactionWillCommit(_ proxy: LiteCrate.TransactionProxy) throws {}
  func migrationDidInitialize(_ proxy: LiteCrate.TransactionProxy) throws {}
  func migrationActionWillRun<A: MigrationAction>(_ action: A) throws {}
  func model<T: DatabaseCodable>(_ model: T, willSaveIn proxy: LiteCrate.TransactionProxy) throws {}
  func model<T: DatabaseCodable>(_ model: T, willDeleteIn proxy: LiteCrate.TransactionProxy) throws {}
  func migrationActionDidRun<A: MigrationAction>(_ action: A) throws {}
}

