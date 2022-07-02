//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import XCTest

@testable import LiteCrate
@testable import LiteCrateReplication

private struct Employee: ReplicatingModel, Identifiable {
  var id: UUID
  var name: String
  var dot: Dot = .init()

  static var exampleInstance: Employee {
    Employee(id: UUID(), name: "")
  }
}

private struct Boss: DatabaseCodable, Identifiable {
  var id: UUID
  var rank: Int64

  static var exampleInstance: Boss {
    Boss(id: UUID(), rank: 0)
  }
}

private struct Customer: ReplicatingModel, Identifiable {
  var id: UUID
  var orderArrived: Int64
  var dot: Dot = .init()

  static var exampleInstance: Customer {
    Customer(id: UUID(), orderArrived: 0)
  }
}

final class ReplicationDelegateTests: XCTestCase {
  func testTime() throws {
    let crate = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      MigrationGroup {
        CreateReplicatingTable(Employee.self)
        CreateTable(Boss.self)
      }
    }

    try crate.inTransaction { proxy in
      XCTAssertEqual(crate.time, 0)
      try proxy.save(Boss(id: UUID(), rank: 0))
    }

    try crate.inTransaction { proxy in
      XCTAssertEqual(crate.time, 0)
      try proxy.save(Employee(id: UUID(), name: "arst"))
    }

    try crate.inTransaction(block: { _ in
      XCTAssertEqual(crate.time, 1)
    })
  }
}
