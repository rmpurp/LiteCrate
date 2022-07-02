//
//  OverallTests.swift
//
//
//  Created by Ryan Purpura on 6/20/22.
//

@testable import LiteCrate
@testable import LiteCrateReplication
import XCTest

final class MergeTests: XCTestCase {
  func testDatabaseIDTiebreaker() throws {
    try testActions {
      CreateDatabase(databaseID: 0)
      CreateDatabase(databaseID: 1)

      // Merge in and reject other
      Add(databaseID: 0, value: 0, id: 0)
      Add(databaseID: 0, value: 1, id: 0)
      Merge(fromID: 0, toID: 1)
      Verify(databaseID: 1, values: [1])
      Merge(fromID: 1, toID: 0)
      Verify(databaseID: 0, values: [1])

      // Merge in and accept other
      Add(databaseID: 0, value: 2, id: 1)
      Verify(databaseID: 0, values: [1, 2])
      Add(databaseID: 1, value: 3, id: 1)
      Verify(databaseID: 1, values: [1, 3])
      Merge(fromID: 1, toID: 0)
      Verify(databaseID: 0, values: [1, 3])
      Merge(fromID: 0, toID: 1)
      Verify(databaseID: 1, values: [1, 3])

      // Higher lamport trumps id.
      Add(databaseID: 0, value: 4, id: 2)
      Modify(databaseID: 0, oldValue: 4, newValue: 4)
      Add(databaseID: 1, value: 5, id: 2)
      Merge(fromID: 0, toID: 1)
      Verify(databaseID: 1, values: [1, 3, 4])
      Merge(fromID: 1, toID: 0)
      Verify(databaseID: 0, values: [1, 3, 4])

      // Higher lamport trumps id.
      Add(databaseID: 0, value: 6, id: 3)
      Modify(databaseID: 0, oldValue: 6, newValue: 6)
      Add(databaseID: 1, value: 7, id: 3)
      Merge(fromID: 1, toID: 0)
      Verify(databaseID: 0, values: [1, 3, 4, 6])
      Merge(fromID: 0, toID: 1)
      Verify(databaseID: 1, values: [1, 3, 4, 6])
    }
  }

  func testMerge() throws {
    try testActions {
      CreateDatabase(databaseID: 0)
      Add(databaseID: 0, value: 0)
      Add(databaseID: 0, value: 1)
      Verify(databaseID: 0, values: [0, 1])

      CreateDatabase(databaseID: 1)
      Merge(fromID: 0, toID: 1, payloadValues: [0, 1])
      Verify(databaseID: 1, values: [0, 1])

      Add(databaseID: 1, value: 2)
      Add(databaseID: 1, value: 3)
      Delete(databaseID: 1, value: 0)
      Verify(databaseID: 1, values: [1, 2, 3])

      Merge(fromID: 1, toID: 0, payloadValues: [2, 3])
      Verify(databaseID: 0, values: [1, 2, 3])

      Add(databaseID: 0, value: 4)
      Modify(databaseID: 0, oldValue: 1, newValue: 5)
      Verify(databaseID: 0, values: [2, 3, 4, 5])
      Add(databaseID: 1, value: 6)
      Add(databaseID: 1, value: 7)
      Delete(databaseID: 1, value: 2)
      Verify(databaseID: 1, values: [1, 3, 6, 7])
      Merge(fromID: 1, toID: 0, debugValue: 2, payloadValues: [6, 7])
      Verify(databaseID: 0, values: [3, 4, 5, 6, 7])
      Merge(fromID: 0, toID: 1, payloadValues: [4, 5])
      Verify(databaseID: 1, values: [3, 4, 5, 6, 7])

      Add(databaseID: 0, value: 10, id: 0)
      Add(databaseID: 1, value: 11)
      Add(databaseID: 1, value: 12, id: 0)
      Modify(databaseID: 1, oldValue: 12, newValue: 12) // Force lamport higher.
      Verify(databaseID: 0, values: [3, 4, 5, 6, 7, 10])
      Verify(databaseID: 1, values: [3, 4, 5, 6, 7, 11, 12])
      Merge(fromID: 0, toID: 1, debugValue: 1, payloadValues: [10])
      Verify(databaseID: 1, values: [3, 4, 5, 6, 7, 11, 12])
      Merge(fromID: 1, toID: 0, debugValue: 1, payloadValues: [11, 12])
      Verify(databaseID: 0, values: [3, 4, 5, 6, 7, 11, 12])

      // Test modifying a value in two places. The "newest" update wins.
      Modify(databaseID: 0, oldValue: 3, newValue: 100)
      Modify(databaseID: 1, oldValue: 4, newValue: 101)
      Modify(databaseID: 1, oldValue: 3, newValue: 102)
      Modify(databaseID: 1, oldValue: 102, newValue: 102)
      Verify(databaseID: 0, values: [4, 5, 6, 7, 11, 12, 100])
      Verify(databaseID: 1, values: [5, 6, 7, 11, 12, 101, 102])
      Merge(fromID: 1, toID: 0)
      Verify(databaseID: 0, values: [5, 6, 7, 11, 12, 101, 102])
      Merge(fromID: 0, toID: 1)
      Verify(databaseID: 1, values: [5, 6, 7, 11, 12, 101, 102])

      // Test one replica deleting, the other modifying. The delete wins.
      Modify(databaseID: 0, oldValue: 5, newValue: 200)
      Modify(databaseID: 0, oldValue: 6, newValue: 201)
      Modify(databaseID: 0, oldValue: 7, newValue: 202)
      Verify(databaseID: 0, values: [11, 12, 101, 102, 200, 201, 202])
      Delete(databaseID: 1, value: 6)
      Delete(databaseID: 1, value: 5)
      Delete(databaseID: 1, value: 7)
      Verify(databaseID: 1, values: [11, 12, 101, 102])
      Merge(fromID: 0, toID: 1, debugValue: 100, payloadValues: [200, 201, 202])
      Verify(databaseID: 1, values: [11, 12, 101, 102])
      Merge(fromID: 1, toID: 0, payloadValues: [])
      Verify(databaseID: 1, values: [11, 12, 101, 102])
    }
  }

  func testForeignKey() throws {
    try testActions {
      CreateDatabase(databaseID: 0)
      CreateDatabase(databaseID: 1)
      Add(databaseID: 0, value: 0)
      Add(databaseID: 0, value: 1)
      AddChild(databaseID: 0, value: 0, parentValue: 0)
      AddChild(databaseID: 0, value: 1, parentValue: 0)
      AddChild(databaseID: 0, value: 2, parentValue: 0)
      VerifyChildren(databaseID: 0, values: [0, 1, 2])
      AddChild(databaseID: 0, value: 3, parentValue: 1)
      AddChild(databaseID: 0, value: 4, parentValue: 1)
      VerifyChildren(databaseID: 0, values: [0, 1, 2, 3, 4])

      Merge(fromID: 0, toID: 1)
      Verify(databaseID: 1, values: [0, 1])
      VerifyChildren(databaseID: 1, values: [0, 1, 2, 3, 4])
      Delete(databaseID: 1, value: 0)
      VerifyChildren(databaseID: 1, values: [3, 4])
      AddChild(databaseID: 0, value: 5, parentValue: 0)
      VerifyChildren(databaseID: 0, values: [0, 1, 2, 3, 4, 5])
      AddChild(databaseID: 1, value: 6, parentValue: 1)

      Merge(fromID: 1, toID: 0)
      Verify(databaseID: 0, values: [1])
      VerifyChildren(databaseID: 0, values: [3, 4, 6])
      Delete(databaseID: 0, value: 1)
      VerifyChildren(databaseID: 0, values: [])
      Merge(fromID: 0, toID: 1)
      VerifyChildren(databaseID: 1, values: [])
    }
  }
}
