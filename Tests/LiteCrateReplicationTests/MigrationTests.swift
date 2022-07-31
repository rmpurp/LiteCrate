//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import XCTest

@testable import LiteCrate

final class MigrationTests: XCTestCase {
//  func testMigration() throws {
//    let controller = try ReplicationController(location: ":memory:", nodeID: UUID()) {
//      MigrationGroup {
//        CreateReplicatingTable(Employee.self)
//        CreateReplicatingTable(Boss.self)
//      }
//    }
//
//    XCTAssertEqual(controller.tables.count, 2)
//  }
  
  func test() {
    let table = Table("Person") {
      Column(name: "id", type: .text).primaryKey()
      Column(name: "name", type: .text)
      Column(name: "age", type: .nullableText)
      Column(name: "parent", type: .nullableText).foreignKey(foreignTable: "Person")
    }
    print(table.createTableStatement())
    print(table.selectStatement())
  }
}
