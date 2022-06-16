//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/16/22.
//

import Foundation
import LiteCrateCore

public protocol DatabaseDelegate {
  func transactionDidBegin(_ proxy: Database.TransactionProxy)
  func transactionWillCommit(_ proxy: Database.TransactionProxy)
  func migrationActionWillRun(_ action: MigrationAction)
}

extension DatabaseDelegate {
  func transactionDidBegin(_ proxy: Database.TransactionProxy) { }
  func transactionWillCommit(_ proxy: Database.TransactionProxy) { }
}
