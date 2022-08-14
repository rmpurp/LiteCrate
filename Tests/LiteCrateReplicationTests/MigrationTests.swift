//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import XCTest

@testable import LiteCrate
@testable import LiteCrateCore

final class MigrationTests: XCTestCase {
  func testEntitySchema() throws {
    let schemaVersion1 = EntitySchema(name: "Person")
        .withProperty("name", type: .nullableText)
        .withProperty("age", type: .integer)
        .withRelationship("dog", reference: "Dog")

    let database = try Database(":memory:")
    try database.execute("CREATE TABLE Dog (id TEXT NOT NULL PRIMARY KEY)")
    try database.execute("INSERT INTO Dog VALUES ('fido')")
    print(schemaVersion1.createTableStatement())

    try database.execute(schemaVersion1.createTableStatement())
    print(schemaVersion1.insertStatement())

    try database.execute(schemaVersion1.insertStatement(), [
      "id": "abc123",
      "name": nil,
      "name__sequencer": "a",
      "name__sequenceNumber": 1,
      "name__lamport": 2,
      "age": 17,
      "age__sequencer": "b",
      "age__sequenceNumber": 3,
      "age__lamport": 4,
      "dog": "fido",
      "dog__sequencer": "c",
      "dog__sequenceNumber": 5,
      "dog__lamport": 6,
    ])
    let cursor = try database.query(schemaVersion1.selectStatement())
    XCTAssertTrue(cursor.step())
    XCTAssertEqual(cursor.string(for: cursor.columnToIndex["id"]!), "abc123")
    XCTAssertTrue(cursor.isNull(for: cursor.columnToIndex["name"]!))
    XCTAssertEqual(cursor.int(for: cursor.columnToIndex["age"]!), 17)
    XCTAssertEqual(cursor.string(for: cursor.columnToIndex["dog"]!), "fido")

    print(schemaVersion1.selectStatement())
  }
}
