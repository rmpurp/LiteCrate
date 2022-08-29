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

    try database.execute(schemaVersion1.createTableStatement())
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
    let cursor = try database.query(schemaVersion1.completeSelectStatement())
    XCTAssertTrue(cursor.step())
    XCTAssertEqual(cursor.string(for: cursor.columnToIndex["id"]!), "abc123")
    XCTAssertTrue(cursor.isNull(for: cursor.columnToIndex["name"]!))
    XCTAssertEqual(cursor.int(for: cursor.columnToIndex["age"]!), 17)
    XCTAssertEqual(cursor.string(for: cursor.columnToIndex["dog"]!), "fido")
  }

  func testCRUD() throws {
    let schema = EntitySchema(name: "Person")
      .withProperty("name", type: .text)
      .withProperty("age", type: .integer)

    let liteCrate = try LiteCrate(":memory:", migrations: {})
    liteCrate.register(schema)

    var entity = ReplicatingEntity(entityType: "Person", id: UUID())
    entity["name"] = .text(val: "bob")
    entity["age"] = .integer(val: 4)

    try liteCrate.inTransaction { db in
      try db.execute(schema.createTableStatement())
      try db.save(entity)
      let fetched = try db.fetch("Person", with: entity.id)!
      guard case let .text(name) = fetched.fields["name"] else { XCTFail(); return }
      guard case let .integer(age) = fetched.fields["age"] else { XCTFail(); return }
      XCTAssertEqual(name, "bob")
      XCTAssertEqual(age, 4)
      XCTAssertEqual(fetched.id, entity.id)
    }
  }

  struct Person: Identifiable, Codable {
    var id: UUID
    var name: String
    var age: Int64
  }

  func testCRUDCodable() throws {
    let schema = EntitySchema(name: "Person")
      .withProperty("name", type: .text)
      .withProperty("age", type: .integer)

    let liteCrate = try LiteCrate(":memory:", migrations: {})
    liteCrate.register(schema)

    let person = Person(id: UUID(), name: "bob", age: 4)

    try liteCrate.inTransaction { db in
      try db.execute(schema.createTableStatement())
      try db.save(entityType: "Person", person)
      let fetched = try db.fetch("Person", type: Person.self, with: person.id)!
      XCTAssertEqual(person.id, fetched.id)
      XCTAssertEqual(person.name, fetched.name)
      XCTAssertEqual(person.age, fetched.age)
    }
  }
}
