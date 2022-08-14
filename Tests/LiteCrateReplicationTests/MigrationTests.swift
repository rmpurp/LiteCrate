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
    try database.execute(schemaVersion1.insertStatement(), ["id": "abc123", "name": nil, "age": 17, "dog": "fido"])
    let cursor = try database.query(schemaVersion1.selectStatement())
    XCTAssertTrue(cursor.step())
    XCTAssertEqual(cursor.string(for: cursor.columnToIndex["id"]!), "abc123")
    XCTAssertTrue(cursor.isNull(for: cursor.columnToIndex["name"]!))
    XCTAssertEqual(cursor.int(for: cursor.columnToIndex["age"]!), 17)
    XCTAssertEqual(cursor.string(for: cursor.columnToIndex["dog"]!), "fido")

    print(schemaVersion1.insertStatement())
    print(schemaVersion1.selectStatement())
  }
}
