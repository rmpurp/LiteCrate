//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/20/22.
//

import Foundation
@testable import LiteCrate
import XCTest

protocol TestAction {
  func perform(_ harness: TestHarness) throws
}

struct TestModel: ReplicatingModel {
  var id: UUID = UUID()
  var value: Int64

  static var table = Table("ChildModel") {
    Column(name: "id", type: .text).primaryKey()
    Column(name: "parent", type: .text).foreignKey(foreignTable: "TestModel")
    Column(name: "value", type: .integer)
  }
}

struct ChildModel: ReplicatingModel {
  var id: UUID
  var parent: UUID
  var value: Int64

  init(value: Int64, parent: TestModel) {
    self.id = UUID()
    self.value = value
    self.parent = parent.id
  }
  
  static var table = Table("ChildModel") {
    Column(name: "id", type: .text).primaryKey()
    Column(name: "parent", type: .text).foreignKey(foreignTable: "TestModel")
    Column(name: "value", type: .integer)
  }
}

struct CreateDatabase: TestAction {
  let databaseID: Int

  func uuid(for id: Int) -> UUID {
    switch id {
    case 0: return UUID(uuidString: "073CFDC3-67AF-471D-AE9F-B0B032AEF859")!
    case 1: return UUID(uuidString: "1C5CE18C-7891-4CD6-910B-A981386ECE48")!
    case 2: return UUID(uuidString: "2E18F5A3-88EA-4A74-BDD7-3754DD0AE950")!
    case 3: return UUID(uuidString: "3FB373D3-EEBF-42B8-AE5A-B91A7758E00F")!
    default: return UUID()
    }
  }

  func perform(_ harness: TestHarness) throws {
//    let id = uuid(for: databaseID)
//    print("Creating database with id \(databaseID) -> \(id)")
//    harness.databases[databaseID] = try ReplicationController(location: ":memory:", nodeID: id) {
//      CreateReplicatingTable(TestModel.self)
//      CreateReplicatingTable(ChildModel.self)
//    }
  }
}

struct AddChild: TestAction {
  let databaseID: Int
  let value: Int64
  let parentValue: Int64
  let id: Int?

  init(databaseID: Int, value: Int64, parentValue: Int64, id: Int? = nil) {
    self.databaseID = databaseID
    self.value = value
    self.parentValue = parentValue
    self.id = id
  }

  func perform(_ harness: TestHarness) throws {
//    print("Adding \(value) to database \(databaseID)")
//    try harness.databases[databaseID]!.inTransaction { proxy in
//      let parent = try proxy.fetch(TestModel.self, allWhere: "value = ?", [parentValue]).first!
//      var child = ChildModel(value: value, parent: parent)
//
//      if let id = id {
//        if let uuid = harness.childIDMap[id] {
//          child.dot.id = uuid
//        } else {
//          let uuid = UUID()
//          harness.childIDMap[id] = uuid
//          child.dot.id = uuid
//        }
//      }
//      try proxy.save(child)
//    }
  }
}

struct DeleteChild: TestAction {
  let databaseID: Int
  let value: Int64

  func perform(_ harness: TestHarness) throws {
//    print("Deleting child \(value) from database \(databaseID)")
//    try harness.databases[databaseID]!.inTransaction { proxy in
//      guard let model = try proxy.fetch(ChildModel.self, allWhere: "value = ?", [value]).first else {
//        XCTFail("Could not fetch model for delete with value \(value)")
//        return
//      }
//      try proxy.delete(model)
//    }
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
//    print("Adding \(value) to database \(databaseID)")
//    try harness.databases[databaseID]!.inTransaction { proxy in
//      var model = TestModel(value: value)
//      if let id = id {
//        if let uuid = harness.idMap[id] {
//          model.dot.id = uuid
//        } else {
//          let uuid = UUID()
//          harness.idMap[id] = uuid
//          model.dot.id = uuid
//        }
//      }
//      try proxy.save(model)
//    }
  }
}

struct Delete: TestAction {
  let databaseID: Int
  let value: Int64

  func perform(_ harness: TestHarness) throws {
//    print("Deleting \(value) from database \(databaseID)")
//    try harness.databases[databaseID]!.inTransaction { proxy in
//      guard let model = try proxy.fetch(TestModel.self, allWhere: "value = ?", [value]).first else {
//        XCTFail("Could not fetch model for delete with value \(value)")
//        return
//      }
//      try proxy.delete(model)
//    }
  }
}

struct Modify: TestAction {
  let databaseID: Int
  let oldValue: Int64
  let newValue: Int64

  func perform(_ harness: TestHarness) throws {
//    print("Modifying \(oldValue) int database \(databaseID) to \(newValue)")
//    try harness.databases[databaseID]!.inTransaction { proxy in
//      guard var model = try proxy.fetch(TestModel.self, allWhere: "value = ?", [oldValue]).first else {
//        XCTFail()
//        return
//      }
//      model.value = newValue
//      try proxy.save(model)
//    }
  }
}

struct Merge: TestAction {
  let fromID: Int
  let toID: Int
  let debugValue: Int
  let payloadValues: [Int64]?
  let file: StaticString
  let line: UInt

  init(
    fromID: Int,
    toID: Int,
      debugValue: Int = -1,
    payloadValues: [Int64]? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    self.fromID = fromID
    self.toID = toID
    self.debugValue = debugValue
    self.payloadValues = payloadValues
    self.file = file
    self.line = line
  }

  func perform(_ harness: TestHarness) throws {
//    print("Merging \(fromID) to \(toID)")
//    let clocks = try harness.databases[toID]!.clocks()
//    let payload = try harness.databases[fromID]!.payload(remoteNodes: clocks)
//    print("Payload: \(payload)")
//
//    if let payloadValues {
//      let actual = payload.models[TestModel.exampleInstance.tableName]!.map { ($0.model as! TestModel).value }
//      XCTAssertEqual(payloadValues.sorted(), actual.sorted(), file: file, line: line)
//    }
//
//    try harness.databases[toID]!.merge(payload)
  }
}

struct Verify: TestAction {
  let databaseID: Int
  let values: [Int64]
  let debugValue: Int
  let file: StaticString
  let line: UInt

  init(databaseID: Int, values: [Int64], debugValue: Int = -1, file: StaticString = #filePath, line: UInt = #line) {
    self.databaseID = databaseID
    self.values = values
    self.debugValue = debugValue
    self.file = file
    self.line = line
  }

  func perform(_ harness: TestHarness) throws {
//    print("Verifying \(databaseID) contains \(values)")
//    try harness.databases[databaseID]!.inTransaction { proxy in
//      let actualValues = try proxy.fetch(TestModel.self).map(\.value)
//      XCTAssertEqual(values.sorted(), actualValues.sorted(), file: self.file, line: self.line)
//    }
  }
}

struct VerifyChildren: TestAction {
  let databaseID: Int
  let values: [Int64]
  let debugValue: Int
  let file: StaticString
  let line: UInt

  init(databaseID: Int, values: [Int64], debugValue: Int = -1, file: StaticString = #filePath, line: UInt = #line) {
    self.databaseID = databaseID
    self.values = values
    self.debugValue = debugValue
    self.file = file
    self.line = line
  }

  func perform(_ harness: TestHarness) throws {
//    print("Verifying \(databaseID) contains \(values) for children")
//    try harness.databases[databaseID]!.inTransaction { proxy in
//      let actualValues = try proxy.fetch(ChildModel.self).map(\.value)
//      XCTAssertEqual(values.sorted(), actualValues.sorted(), file: self.file, line: self.line)
//    }
  }
}

@resultBuilder
enum TestBuilder {
  static func buildBlock(_ components: TestAction...) -> [TestAction] {
    components
  }
}

class TestHarness {
//  var databases = [Int: ReplicationController]()
  var idMap = [Int: UUID]()
  var childIDMap = [Int: UUID]()
  var actions: [TestAction]
  init(@TestBuilder actions: () -> [TestAction]) {
    self.actions = actions()
  }

  func run() throws {
    for action in actions {
      try action.perform(self)
    }
  }
}

func testActions(@TestBuilder actions: () -> [TestAction]) throws {
  let harness = TestHarness(actions: actions)
  try harness.run()
}
