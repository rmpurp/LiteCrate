//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/20/22.
//

import Foundation
import XCTest
@testable import LiteCrate
@testable import LiteCrateReplication

protocol TestAction {
  func perform(_ harness: TestHarness) throws
}


struct TestModel: ReplicatingModel {
  var value: Int64
  var dot: Dot = Dot()
}

struct CreateDatabase: TestAction {
  let databaseID: Int
  
  func perform(_ harness: TestHarness) throws {
    print("Creating database with id \(databaseID)")
    harness.databases[databaseID] = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable(TestModel(value: 0))
    }
  }
}

struct Add: TestAction {
  let databaseID: Int
  let value: Int64
  let id: Int?
  
  init(databaseID: Int, value: Int64, id: Int? = nil) {
    self.databaseID = databaseID
    self.value = value
    self.id = id
  }
  
  func perform(_ harness: TestHarness) throws {
    print("Adding \(value) to database \(databaseID)")
    try harness.databases[databaseID]!.inTransaction { proxy in
      var model = TestModel(value: value)
      if let id = id {
        if let uuid = harness.idMap[id] {
          model.dot.id = uuid
        } else {
          let uuid = UUID()
          harness.idMap[id] = uuid
          model.dot.id = uuid
        }
      }
      try proxy.save(model)
    }
  }
}

struct Delete: TestAction {
  let databaseID: Int
  let value: Int64
  
  func perform(_ harness: TestHarness) throws {
    print("Deleting \(value) from database \(databaseID)")
    try harness.databases[databaseID]!.inTransaction { proxy in
      guard let model = try proxy.fetch(TestModel.self, allWhere: "value = ?", [value]).first else {
        XCTFail("Could not fetch model for delete with value \(value)")
        return
      }
      try proxy.delete(model)
    }
  }
}

struct Modify: TestAction {
  let databaseID: Int
  let oldValue: Int64
  let newValue: Int64

  func perform(_ harness: TestHarness) throws {
    print("Modifying \(oldValue) int database \(databaseID) to \(newValue)")
    try harness.databases[databaseID]!.inTransaction { proxy in
      var model = try proxy.fetch(TestModel.self, allWhere: "value = ?", [oldValue]).first!
      model.value = newValue
      try proxy.save(model)
    }
  }
}

struct Merge: TestAction {
  let fromID: Int
  let toID: Int
  let debugValue: Int
  let payloadValues: [Int64]?

  init(fromID: Int, toID: Int, debugValue: Int = -1, payloadValues: [Int64]? = nil) {
    self.fromID = fromID
    self.toID = toID
    self.debugValue = debugValue
    self.payloadValues = payloadValues
  }
  
  func perform(_ harness: TestHarness) throws {
    print("Merging \(fromID) to \(toID)")
    let clocks = try harness.databases[toID]!.clocks()
    let payload = try harness.databases[fromID]!.encode(clocks: clocks)
    print("Payload: \(payload)")
    let tempDB = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable(TestModel(value: 0))
    }

    try tempDB.decode(from: payload)
    
    if let payloadValues {
      try tempDB.inTransaction { proxy in
        let actual = try proxy.fetchIgnoringDelegate(TestModel.self).map(\.value)
        XCTAssertEqual(payloadValues.sorted(), actual.sorted())
      }
    }
    
    try harness.databases[toID]!.merge(tempDB)
  }
}

struct Verify: TestAction {
  let databaseID: Int
  let values: [Int64]
  let debugValue: Int

  init(databaseID: Int, values: [Int64], debugValue: Int = -1) {
    self.databaseID = databaseID
    self.values = values
    self.debugValue = debugValue
  }
  
  func perform(_ harness: TestHarness) throws {
    print("Verifying \(databaseID) contains \(values)")
    try harness.databases[databaseID]!.inTransaction { proxy in
      let actualValues = try proxy.fetch(TestModel.self).map(\.value)
      XCTAssertEqual(values.sorted(), actualValues.sorted())
    }
  }
  
}

@resultBuilder
struct TestBuilder {
  static func buildBlock(_ components: TestAction...) -> [TestAction] {
    components
  }
  
}

class TestHarness {
  var databases = [Int: ReplicationController]()
  var idMap = [Int: UUID]()
  
  init(@TestBuilder actions: () -> [TestAction]) throws {
    for action in actions() {
      try action.perform(self)
    }
  }
}
