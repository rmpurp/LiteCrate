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

private struct Employee: ReplicatingModel {
  static var exampleInstance: Employee {
    Employee(name: "")
  }

  var name: String
  var dot: Dot = .init()
}

private struct Boss: ReplicatingModel {
  var rank: Int64
  var dot: Dot = .init()

  static var exampleInstance: Boss {
    Boss(rank: 0)
  }
}

final class MigrationTests: XCTestCase {
  func testMigration() throws {
    let controller = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      MigrationGroup {
        CreateReplicatingTable(Employee.self)
        CreateReplicatingTable(Boss.self)
      }
    }

    XCTAssertEqual(controller.tables.count, 2)
  }
}
