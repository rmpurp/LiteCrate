//
//  MergeTests.swift
//  
//
//  Created by Ryan Purpura on 6/19/22.
//

import XCTest
@testable import LiteCrateReplication
@testable import LiteCrate

fileprivate struct Boss: ReplicatingModel, Hashable {
  var age: Int64
  var dot: Dot = Dot()
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(dot.id)
  }
}

extension UUID {
  var short: String {
    let hyphen = uuidString.firstIndex(of: "-")!
    return String(uuidString[..<hyphen])
  }
}

extension Boss: CustomDebugStringConvertible {
  var debugDescription: String {
    return "Boss(age:\(age), version:\(dot.version.short), id:\(dot.id.short))"
  }
  
  
}

final class MergeTests: XCTestCase {
  func testOneWayMerge() throws {
    let db1 = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable(Boss(age: 0))
    }
    
    let db2 = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable (Boss(age: 0))
    }
    
    var bosses: Set<Boss> = []
    
    try db1.inTransaction { proxy in
      try proxy.save(Boss(age: 25))
      try proxy.save(Boss(age: 30))
      bosses = try bosses.union(proxy.fetch(Boss.self))
    }
    
    try db2.merge(db1)
    var db2Bosses: Set<Boss> = []

    try db2.inTransaction { proxy in
      db2Bosses = try db2Bosses.union(proxy.fetch(Boss.self))
    }
    XCTAssertEqual(bosses.count, 2)
    XCTAssertEqual(bosses, db2Bosses)
  }
  
  func testOneWayMergeWithDelete() throws {
    let db1 = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable(Boss(age: 0))
    }
    
    let db2 = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable (Boss(age: 0))
    }
        
    try db1.inTransaction { proxy in
      try proxy.save(Boss(age: 25))
      try proxy.save(Boss(age: 30))
      try proxy.save(Boss(age: 35))
    }
    
    try db2.merge(db1)
    
    var expected = Set<Boss>()
    
    try db1.inTransaction { proxy in
      let boss = try proxy.fetch(Boss.self, allWhere: "age = 25").first!
      try proxy.delete(boss)
      expected = expected.union(try proxy.fetch(Boss.self))
    }
    
    try db2.merge(db1)

    try db2.inTransaction { proxy in
      let actual = Set(try proxy.fetch(Boss.self))
      XCTAssertEqual(expected, actual)
      XCTAssertEqual(2, actual.count)
    }
  }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
}
