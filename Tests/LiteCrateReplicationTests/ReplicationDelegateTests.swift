//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import XCTest

@testable import LiteCrateReplication
@testable import LiteCrate

fileprivate struct Employee: ReplicatingModel, Identifiable {
  var id: UUID
  var name: String
  var dot: Dot = Dot()
}

fileprivate struct Boss: DatabaseCodable, Identifiable {
  var id: UUID
  var rank: Int64
}

fileprivate struct Customer: ReplicatingModel, Identifiable {
  var id: UUID
  var orderArrived: Int64
  var dot: Dot = Dot()
}

final class ReplicationDelegateTests: XCTestCase {
  func testTime() throws {
    let crate = try ReplicationController(location: ":memory:", nodeID: UUID()) {
      MigrationGroup {
        CreateReplicatingTable(Employee(id: UUID(), name: ""))
        CreateTable(Boss(id: UUID(), rank: 0))
      }
    }

    try crate.inTransaction { proxy in
      XCTAssertEqual(crate.time, 0)
      try proxy.save(Boss(id: UUID(), rank: 0))
    }
    
    try crate.inTransaction { proxy in
      XCTAssertEqual(crate.time, 0)
      try proxy.save(Employee(id: UUID(), name: "arst"))
    }
    
    try crate.inTransaction(block: { proxy in
      XCTAssertEqual(crate.time, 1)
    })

    
  }
  
    func testPayload() throws {
      let crate = try ReplicationController(location: ":memory:", nodeID: UUID()) {
        MigrationGroup {
          CreateReplicatingTable(Employee(id: UUID(), name: ""))
          CreateReplicatingTable(Customer(id: UUID(), orderArrived: 0))
        }
  
//        MigrationStep {
//          Execute("INSERT INTO Customer (id, orderArrived) VALUES ('900D0D82-0748-4D87-AC65-BF702D1202A3', 5)")
//          Execute("INSERT INTO Employee (id, name) VALUES ('900D0D83-0748-4D87-AC65-BF702D1202A3', 'bob')")
//        }
      }
      
      try crate.inTransaction { proxy in
        try proxy.save(Customer(id: UUID(), orderArrived: 5))
        try proxy.save(Employee(id: UUID(), name: "bob"))
      }
      
      let json = try crate.payload(remoteNodes: [])
      
      
      let crate2 = try ReplicationController(location: ":memory:", nodeID: UUID()) {
        MigrationGroup {
          CreateReplicatingTable(Employee(id: UUID(), name: ""))
          CreateReplicatingTable(Customer(id: UUID(), orderArrived: 0))
        }
      }
      
//      try crate2.decode(from: json)
      try print(crate2.payload(remoteNodes: []))

      
//      let j = JSONEncoder()
//      j.outputFormatting = [.prettyPrinted, .sortedKeys]
//
//      j.userInfo[DatabasePayloadProxy.databaseUserInfoKey] = crate
//      let data = try j.encode(DatabasePayloadProxy())
//      print(String(data: data, encoding: .utf8)!)
//
//      let d = JSONDecoder()
//      let crate2 = try LiteCrate(":memory:", nodeID:  UUID()) {
//        MigrationStep {
//          CreateReplicatingTable(Employee(id: UUID(), name: ""))
//          CreateReplicatingTable(Boss(id: UUID(), rank: 0))
//        }
//      }
//      d.userInfo[DatabasePayloadProxy.databaseUserInfoKey] = crate2
//      _ = try d.decode(DatabasePayloadProxy.self, from: data)
//
//      try crate2.inTransaction { proxy in
//        print(try proxy.fetch(Boss.self))
//        print(try proxy.fetch(Employee.self))
//      }
  
//   TODO: write proper test
    }
}
