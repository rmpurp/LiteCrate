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
    // TODO:
  }
//
  //  func testPayload() throws {
//    let crate = try LiteCrate(":memory:", nodeID: UUID()) {
//      MigrationStep {
//        CreateReplicatingTable(Employee(id: UUID(), name: ""))
//        CreateReplicatingTable(Boss(id: UUID(), rank: 0))
//      }
//
//      MigrationStep {
//        Execute("INSERT INTO Boss (id, rank) VALUES ('900D0D82-0748-4D87-AC65-BF702D1202A3', 5)")
//        Execute("INSERT INTO Employee (id, name) VALUES ('900D0D83-0748-4D87-AC65-BF702D1202A3', 'bob')")
//      }
//    }
//    let j = JSONEncoder()
//    j.outputFormatting = [.prettyPrinted, .sortedKeys]
//
//    j.userInfo[DatabasePayloadProxy.databaseUserInfoKey] = crate
//    let data = try j.encode(DatabasePayloadProxy())
//    print(String(data: data, encoding: .utf8)!)
//
//    let d = JSONDecoder()
//    let crate2 = try LiteCrate(":memory:", nodeID:  UUID()) {
//      MigrationStep {
//        CreateReplicatingTable(Employee(id: UUID(), name: ""))
//        CreateReplicatingTable(Boss(id: UUID(), rank: 0))
//      }
//    }
//    d.userInfo[DatabasePayloadProxy.databaseUserInfoKey] = crate2
//    _ = try d.decode(DatabasePayloadProxy.self, from: data)
//
//    try crate2.inTransaction { proxy in
//      print(try proxy.fetch(Boss.self))
//      print(try proxy.fetch(Employee.self))
//    }
//
  // TODO: write proper test
  //  }
}
