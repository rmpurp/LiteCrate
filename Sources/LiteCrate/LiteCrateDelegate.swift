//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrateCore

public protocol LiteCrateDelegate {
  func transaction(didBeginIn proxy: TransactionProxy) throws
  func transaction(willCommitIn proxy: TransactionProxy) throws
  func transactionDidEnd()
  func migration(didInitializeIn proxy: TransactionProxy) throws
  func migration<A: MigrationAction>(willRun action: A) throws
  func proxy<T: DatabaseCodable>(_ proxy: TransactionProxy, willSave model: T) throws -> any DatabaseCodable
  func proxy<T: DatabaseCodable>(_ proxy: TransactionProxy, willDelete model: T) throws
    -> (any DatabaseCodable)?
  func migrationActionDidRun<A: MigrationAction>(_ action: A) throws
  func liteCrate(_ crate: LiteCrate, encodingInto encoder: Encoder) throws
  func filter<T: DatabaseCodable>(model: T) throws -> Bool
}

public extension LiteCrateDelegate {
  func transaction(didBeginIn _: TransactionProxy) throws {}
  func transaction(willCommitIn _: TransactionProxy) throws {}
  func transactionDidEnd() {}
  func migration(didInitializeIn _: TransactionProxy) throws {}
  func migration<A: MigrationAction>(willRun _: A) throws {}
  func proxy<T: DatabaseCodable>(_: TransactionProxy,
                                 willSave model: T) throws -> any DatabaseCodable { model }
  func proxy<T: DatabaseCodable>(_: TransactionProxy, willDelete _: T) throws -> (any DatabaseCodable)? { nil
  }

  func migrationActionDidRun<A: MigrationAction>(_: A) throws {}
  func liteCrate(_: LiteCrate, encodingInto _: Encoder) throws {}
  func filter<T: DatabaseCodable>(model _: T) throws -> Bool { true }
}
