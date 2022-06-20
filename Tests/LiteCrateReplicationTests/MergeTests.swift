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
  
  func testDelta() throws {
    let db1 = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable(Boss(age: 0))
    }
    
    try db1.inTransaction { proxy in
      try proxy.save(Boss(age: 25))
    }

    try db1.inTransaction { proxy in
      try proxy.save(Boss(age: 30))
    }
    
    let test = { clock, expectedCount in
      let db2 = try ReplicationController(location: ":memory:", nodeID: UUID()) {
        CreateReplicatingTable(Boss(age: 0))
      }
      
      let payload = try db1.encode(clocks: [Node(id: db1.nodeID, minTime: 0, time: clock)])
      try db2.decode(from: payload)
      
      try db2.inTransaction { proxy in
        let bosses = try proxy.fetch(Boss.self)
        XCTAssertEqual(bosses.count, expectedCount)
      }
    }
    
    try test(0, 2)
    try test(1, 1)
    try test(2, 0)
    try test(3, 0)
  }
}
