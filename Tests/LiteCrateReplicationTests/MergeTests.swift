//
//  OverallTests.swift
//  
//
//  Created by Ryan Purpura on 6/20/22.
//

import XCTest
@testable import LiteCrate
@testable import LiteCrateReplication

final class MergeTests: XCTestCase {
  
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
        
        Merge(fromID: 1, toID: 0, payloadValues: [0, 2, 3])
        Verify(databaseID: 0, values: [1, 2, 3])

        Add(databaseID: 0, value: 4)
        Modify(databaseID: 0, oldValue: 1, newValue: 5)
        Verify(databaseID: 0, values: [2, 3, 4, 5])
        Add(databaseID: 1, value: 6)
        Add(databaseID: 1, value: 7)
        Delete(databaseID: 1, value: 2)
        Verify(databaseID: 1, values: [1, 3, 6, 7])
        Merge(fromID: 1, toID: 0, debugValue: 2, payloadValues: [2, 6, 7])
        Verify(databaseID: 0, values: [3, 4, 5, 6, 7])
        Merge(fromID: 0, toID: 1, payloadValues: [4, 5])
        Verify(databaseID: 1, values: [3, 4, 5, 6, 7])
        
        Add(databaseID: 0, value: 10, id: 0)
        Add(databaseID: 1, value: 11)
        Add(databaseID: 1, value: 12, id: 0)
        Verify(databaseID: 0, values: [3, 4, 5, 6, 7, 10])
        Verify(databaseID: 1, values: [3, 4, 5, 6, 7, 11, 12])
        Merge(fromID: 0, toID: 1, debugValue: 1, payloadValues: [10])
        Verify(databaseID: 1, values: [3, 4, 5, 6, 7, 11, 12])
        Merge(fromID: 1, toID: 0, payloadValues: [10, 11, 12])
        Verify(databaseID: 0, values: [3, 4, 5, 6, 7, 11, 12])
        
        // Test modifying a value in two places. The "newest" update wins.
        Modify(databaseID: 0, oldValue: 3, newValue: 100)
        Modify(databaseID: 1, oldValue: 4, newValue: 101)
        Modify(databaseID: 1, oldValue: 3, newValue: 102)
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
        Merge(fromID: 1, toID: 0, payloadValues: [5, 6, 7])
        Verify(databaseID: 1, values: [11, 12, 101, 102])
      }
    }
}
