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
      XCTAssertEqual(boss1Fetched.dot.witness, db.nodeID)
      XCTAssertEqual(boss1Fetched.dot.lastModifier, db.nodeID)
      XCTAssertEqual(boss1Fetched.dot.creator, db.nodeID)
      XCTAssertEqual(boss1Fetched.dot.timeCreated, 0)
      XCTAssertEqual(boss1Fetched.dot.timeLastModified, 0)
      XCTAssertEqual(boss1Fetched.dot.timeLastWitnessed, 0)
    }

    try db.inTransaction { proxy in
      var boss1Fetched = try proxy.fetch(Boss.self, with: boss1.primaryKeyValue)!
      boss1Fetched.age = 43
      try proxy.save(boss1Fetched)

      boss1Fetched = try proxy.fetch(Boss.self, with: boss1.primaryKeyValue)!
      XCTAssertEqual(boss1Fetched.dot.version, boss1.dot.version)
      XCTAssertEqual(boss1Fetched.dot.id, boss1.dot.id)
      XCTAssertEqual(boss1Fetched.dot.witness, db.nodeID)
      XCTAssertEqual(boss1Fetched.dot.lastModifier, db.nodeID)
      XCTAssertEqual(boss1Fetched.dot.creator, db.nodeID)
      XCTAssertEqual(boss1Fetched.dot.timeCreated, 0)
      XCTAssertEqual(boss1Fetched.dot.timeLastModified, 1)
      XCTAssertEqual(boss1Fetched.dot.timeLastWitnessed, 1)
    }
  }

  func testDotDeletion() throws {
    let db = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      MigrationGroup {
        CreateReplicatingTable(Boss(age: 0))
      }
    }

    let boss1 = Boss(age: 42)

    try db.inTransaction { proxy in
      try proxy.save(boss1)
    }

    let boss1Version2 = Boss(age: 43, dot: Dot(id: boss1.dot.id))
    try db.inTransaction { proxy in
      try proxy.save(boss1Version2)

      XCTAssertNil(try proxy.fetch(Boss.self, with: boss1.primaryKeyValue))

      let boss1Fetched = try proxy.fetchIgnoringDelegate(Boss.self, with: boss1.primaryKeyValue)!
      XCTAssertEqual(boss1Fetched.age, 42)
      XCTAssertEqual(boss1Fetched.dot.isDeleted, true)
      XCTAssertNil(boss1Fetched.dot.timeLastModified)
      XCTAssertNil(boss1Fetched.dot.lastModifier)
      XCTAssertEqual(boss1Fetched.dot.timeCreated, 0)
      XCTAssertEqual(boss1Fetched.dot.timeLastWitnessed, 1)
    }

    try db.inTransaction { proxy in
      XCTAssertNil(try proxy.fetch(Boss.self, with: boss1.primaryKeyValue))
    }

    try db.inTransaction { proxy in
      try proxy.delete(boss1Version2)
      XCTAssertNil(try proxy.fetch(Boss.self, with: boss1Version2.primaryKeyValue))
      XCTAssertNotNil(try proxy.fetchIgnoringDelegate(Boss.self, with: boss1Version2.primaryKeyValue))
    }
  }
}
