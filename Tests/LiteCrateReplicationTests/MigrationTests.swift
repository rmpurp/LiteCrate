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
    let schemaVersion1 = EntitySchema(name: "Person")
        .withProperty("name", type: .text, version: 1)
        .withProperty("age", type: .nullableInteger, version: 1)
        .withRelationship("dog", reference: "Dog", version: 1)
    
    let schema = schemaVersion1
        .withProperty("age2", type: .blob, version: 2)
        .withRelationship("dog2", reference: "Dog", version: 2)

    for a in schema.statementsToRun(currentVersion: 0) {
      print(a)
    }

    for b in schema.statementsToRun(currentVersion: 1) {
      print(b)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    print(String(data: try! encoder.encode(schema), encoding: .utf8)!)
    print(schema.insertStatement())
  
//    let table = Table("Person") {
//      Column(name: "id", type: .text).primaryKey()
//      Column(name: "name", type: .text)
//      Column(name: "age", type: .nullableText)
//      Column(name: "parent", type: .nullableText).foreignKey(foreignTable: "Person")
//    }
//    print(table.createTableStatement())
//    print(table.selectStatement())
//    print(table.insertStatement())
  }
}
