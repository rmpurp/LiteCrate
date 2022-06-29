//
//  PayloadTest.swift
//
//
//  Created by Ryan Purpura on 6/22/22.
//

@testable import LiteCrateReplication
@testable import LiteCrate
import XCTest

private struct Parent: ReplicatingModel {
  var dot: Dot = .init()
  var value: Int64
  var isParent: Bool = true
}

private struct Child: ChildReplicatingModel {
  var dot: Dot
  var parent: Parent.Key
  var parentDot: ForeignKeyDot
  var value: String
  
  init(dot: Dot = Dot(), parent: Parent, value: String) {
    self.dot = dot
    self.parent = parent.id
    self.parentDot = ForeignKeyDot(parent: parent)
    self.value = value
  }
  
  static var foreignKeys: [ForeignKey] {
    [
      ForeignKey("parent", references: "Parent", targetColumn: "id", onDelete: .noAction)
    ]
  }
}

final class ForeignKeyTests: XCTestCase {
  func testForeignKey() throws {
    let controller = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      CreateReplicatingTable(Parent(value: 0))
      CreateReplicatingTable(Child(parent: Parent(value: 0), value: ""))
    }
    
    var parent = Parent(value: 0)
    try controller.inTransaction { proxy in
      try proxy.save(parent)
      parent = try proxy.fetch(Parent.self, with: parent.id)!
    }
    
    let child = Child(parent: parent, value: "0")
    let child2 = Child(parent: parent, value: "2")

    try controller.inTransaction { proxy in
      try proxy.save(child)
      try proxy.save(child2)
      XCTAssertEqual(try proxy.fetch(Parent.self).count, 1)
      XCTAssertEqual(try proxy.fetch(Child.self).count, 2)
      print(try proxy.fetch(Child.self))
      try proxy.delete(parent)
      XCTAssertEqual(try proxy.fetch(Parent.self).count, 0)
      XCTAssertEqual(try proxy.fetch(Child.self).count, 0)
    }
  }
}
