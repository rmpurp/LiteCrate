//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/19/22.
//

import Foundation
import XCTest

@testable import LiteCrate
@testable import LiteCrateReplication

private struct Boss: ReplicatingModel {
  var age: Int64
  var dot: Dot = .init()
}

final class DotTests: XCTestCase {
  func testDotCreation() throws {
    let db = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      MigrationGroup {
        CreateReplicatingTable(Boss(age: 0))
      }
    }

    let boss1 = Boss(age: 42)
    try db.inTransaction { proxy in
      try proxy.save(boss1)
      let boss1Fetched = try proxy.fetch(Boss.self, with: boss1.primaryKeyValue)!
      XCTAssertEqual(boss1Fetched.dot.version, boss1.dot.version)
      XCTAssertEqual(boss1Fetched.dot.id, boss1.dot.id)
//      XCTAssertEqual(boss1Fetched.dot.witnessedTime, Timestamp(time: 0, node: db.nodeID))
//      XCTAssertEqual(boss1Fetched.dot.modifiedTime, Timestamp(time: 0, node: db.nodeID))
//      XCTAssertEqual(boss1Fetched.dot.createdTime, Timestamp(time: 0, node: db.nodeID))
    }

    try db.inTransaction { proxy in
      var boss1Fetched = try proxy.fetch(Boss.self, with: boss1.primaryKeyValue)!
      boss1Fetched.age = 43
      try proxy.save(boss1Fetched)

      boss1Fetched = try proxy.fetch(Boss.self, with: boss1.primaryKeyValue)!
      XCTAssertEqual(boss1Fetched.dot.version, boss1.dot.version)
      XCTAssertEqual(boss1Fetched.dot.id, boss1.dot.id)
//      XCTAssertEqual(boss1Fetched.dot.witness, db.nodeID)
//      XCTAssertEqual(boss1Fetched.dot.lastModifier, db.nodeID)
//      XCTAssertEqual(boss1Fetched.dot.creator, db.nodeID)
//      XCTAssertEqual(boss1Fetched.dot.timeCreated, 0)
//      XCTAssertEqual(boss1Fetched.dot.timeLastModified, 1)
//      XCTAssertEqual(boss1Fetched.dot.timeLastWitnessed, 1)
//      XCTAssertEqual(boss1Fetched.dot.witnessedTime, Timestamp(time: 1, node: db.nodeID))
//      XCTAssertEqual(boss1Fetched.dot.modifiedTime, Timestamp(time: 1, node: db.nodeID))
//      XCTAssertEqual(boss1Fetched.dot.createdTime, Timestamp(time: 0, node: db.nodeID))
    }
  }
}
