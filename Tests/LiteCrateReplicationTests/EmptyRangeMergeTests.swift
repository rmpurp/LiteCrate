//
//  OverallTests.swift
//
//
//  Created by Ryan Purpura on 6/27/22.
//

@testable import LiteCrate
@testable import LiteCrateReplication
import XCTest

private struct Model: ReplicatingModel {
  var dot: Dot = .init()
  var val: Int64 = 0
}

// TODO: Test node id tie-breaking
final class EmptyRangeMergeTests: XCTestCase {
  func testMergeRanges() throws {
    let controller = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable(Model(dot: Dot()))
    }

    try controller.inTransaction { proxy in
      try proxy.save(Model(val: 0))
      try proxy.save(Model(val: 1))
      try proxy.save(Model(val: 2))
      try proxy.save(Model(val: 3))
      try proxy.save(Model(val: 4))
      try proxy.save(Model(val: 5))
    }

    try controller.inTransaction { proxy in
      try proxy.delete(Model.self, allWhere: "val = 2")
      XCTAssertEqual(try proxy.fetch(EmptyRange.self).count, 1 + 1)

      try proxy.delete(Model.self, allWhere: "val = 4")
      XCTAssertEqual(try proxy.fetch(EmptyRange.self).count, 2 + 1)

      try proxy.delete(Model.self, allWhere: "val = 5")
      XCTAssertEqual(try proxy.fetch(EmptyRange.self).count, 2)

      try proxy.delete(Model.self, allWhere: "val = 0")
      XCTAssertEqual(try proxy.fetch(EmptyRange.self).count, 3)

      try proxy.delete(Model.self, allWhere: "val = 1")
      XCTAssertEqual(try proxy.fetch(EmptyRange.self).count, 2)

      try proxy.delete(Model.self, allWhere: "val = 3")
      XCTAssertEqual(try proxy.fetch(EmptyRange.self).count, 1)

      let range = try proxy.fetch(EmptyRange.self).first!
      XCTAssertEqual(range.start, 0)
      XCTAssertEqual(range.end, 11)
    }
  }
}
