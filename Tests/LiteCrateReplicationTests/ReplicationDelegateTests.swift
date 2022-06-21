//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import XCTest

@testable import LiteCrateReplication
@testable import LiteCrate

fileprivate struct Employee: ReplicatingModel, Identifiable {
  var id: UUID
  var name: String
  var dot: Dot = Dot()
}

fileprivate struct Boss: DatabaseCodable, Identifiable {
  var id: UUID
  var rank: Int64
}

fileprivate struct Customer: ReplicatingModel, Identifiable {
  var id: UUID
  var orderArrived: Int64
  var dot: Dot = Dot()
}

final class ReplicationDelegateTests: XCTestCase {
  func testTime() throws {
    let crate = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      MigrationGroup {
        CreateReplicatingTable(Employee(id: UUID(), name: ""))
        CreateTable(Boss(id: UUID(), rank: 0))
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
    
    try crate.inTransaction(block: { proxy in
      XCTAssertEqual(crate.time, 1)
    })
  }
}
