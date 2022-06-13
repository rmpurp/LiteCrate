//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import XCTest

@testable import LiteCrate

struct Employee: LCModel {
  var id: UUID
  var name: String
}

struct Boss: LCModel {
  var id: UUID
  var rank: Int64
}


final class MigrationTests: XCTestCase {
  func testMigration() throws {
    let crate = try LiteCrate(":memory:") {
      MigrationStep {
        CreateReplicatingTable(Employee(id: UUID(), name: ""))
        CreateReplicatingTable(Boss(id: UUID(), rank: 0))
      }
      
      MigrationStep {
        Execute("INSERT INTO Boss (id, rank) VALUES ('900D0D82-0748-4D87-AC65-BF702D1202A3', 5)")
      }
    }
    try crate.inTransaction { proxy in
      let bosses = try proxy.fetch(Boss.self)
      XCTAssertEqual(bosses.count, 1)
      XCTAssertEqual(bosses.first!.id, UUID(uuidString: "900D0D82-0748-4D87-AC65-BF702D1202A3")!)
      XCTAssertEqual(bosses.first!.rank, 5)
      
      let employee = try proxy.fetch(Employee.self)
      XCTAssertNil(employee.first)
    }
    XCTAssertEqual(crate.replicatingTables, Set([ReplicatingTableImpl(Employee.self), ReplicatingTableImpl(Boss.self)]))
  }
  
  func testPayload() throws {
    let crate = try LiteCrate(":memory:") {
      MigrationStep {
        CreateReplicatingTable(Employee(id: UUID(), name: ""))
        CreateReplicatingTable(Boss(id: UUID(), rank: 0))
      }
      
      MigrationStep {
        Execute("INSERT INTO Boss (id, rank) VALUES ('900D0D82-0748-4D87-AC65-BF702D1202A3', 5)")
        Execute("INSERT INTO Employee (id, name) VALUES ('900D0D83-0748-4D87-AC65-BF702D1202A3', 'bob')")
      }
    }
    let j = JSONEncoder()
    j.outputFormatting = [.prettyPrinted, .sortedKeys]

    j.userInfo[DatabasePayloadProxy.databaseUserInfoKey] = crate
    try print(String(data: j.encode(DatabasePayloadProxy()), encoding: .utf8)!)
    
    // TODO: write proper test
  }
}
