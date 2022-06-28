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
  var name: String
  var dot: Dot = .init()
}

private struct Boss: ReplicatingModel {
  var rank: Int64
  var dot: Dot = .init()
}

final class MigrationTests: XCTestCase {
  func testMigration() throws {
    let controller = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      MigrationGroup {
        CreateReplicatingTable(Employee(name: ""))
        CreateReplicatingTable(Boss(rank: 0))
      }
    }

    XCTAssertEqual(controller.exampleInstances.count, 2)
  }
}
