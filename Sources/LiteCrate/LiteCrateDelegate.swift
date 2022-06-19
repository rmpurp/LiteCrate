//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrateCore

public protocol LiteCrateDelegate {
  func transaction(didBeginIn proxy: LiteCrate.TransactionProxy) throws
  func transaction(willCommitIn proxy: LiteCrate.TransactionProxy) throws
  func migration(didInitializeIn proxy: LiteCrate.TransactionProxy) throws
  func migration<A: MigrationAction>(willRun action: A) throws
  func proxy<T: DatabaseCodable>(_ proxy: LiteCrate.TransactionProxy, willSave model: T) throws -> T
  func proxy<T: DatabaseCodable>(_ proxy: LiteCrate.TransactionProxy, willDelete model: T) throws -> T?
  func migrationActionDidRun<A: MigrationAction>(_ action: A) throws
  func liteCrate(_ crate: LiteCrate, encodingInto encoder: Encoder) throws
  func filter<T: DatabaseCodable>(model: T) throws -> Bool
}

public extension LiteCrateDelegate {
  func transaction(didBeginIn proxy: LiteCrate.TransactionProxy) throws {}
  func transaction(willCommitIn proxy: LiteCrate.TransactionProxy) throws {}
  func migration(didInitializeIn proxy: LiteCrate.TransactionProxy) throws {}
  func migration<A: MigrationAction>(willRun action: A) throws {}
  func proxy<T: DatabaseCodable>(_ proxy: LiteCrate.TransactionProxy, willSave model: T) throws -> T { model }
  func proxy<T: DatabaseCodable>(_ proxy: LiteCrate.TransactionProxy, willDelete model: T) throws -> T? { nil }
  func migrationActionDidRun<A: MigrationAction>(_ action: A) throws {}
  func liteCrate(_ crate: LiteCrate, encodingInto encoder: Encoder) throws {}
  func filter<T: DatabaseCodable>(model: T) throws -> Bool { true }
}
