import Combine
import XCTest

@testable import LiteCrate
import SQLite3

extension DispatchSemaphore {
  func waitABit() -> DispatchTimeoutResult {
    wait(timeout: DispatchTime.now().advanced(by: .seconds(1)))
  }
}

fileprivate struct Person2: ReplicatingModel {
  static var table: Table = Table("") {
    
  }
  
  var id: UUID
  var age: Int64
}

@available(macOS 12.0, *)
final class LiteCrateTests: XCTestCase {
  func testSaveAndFetch() throws {
    let crate = try LiteCrate(":memory:") {}
    try crate.inTransaction { db in
      let person = Person2(id: UUID(), age: 10)
      let person2 = Person2(id: UUID(), age: 20)
      let person3 = Person2(id: UUID(), age: 30)
      try db.save(person)
      try db.save(person2)
      try db.save(person3)
//      try block.execute("INSERT INTO Field VALUES (?, ?, ?, ?, ?, ?, ?)", [id, "a", "a", 0, 0, "id", id])
//      try block.execute("INSERT INTO Field VALUES (?, ?, ?, ?, ?, ?, ?)", [id, "a", "a", 0, 0, "age", 10])
//      try block.execute("INSERT INTO Field VALUES (?, ?, ?, ?, ?, ?, ?)", [id2, "a", "a", 0, 0, "id", id2])
//      try block.execute("INSERT INTO Field VALUES (?, ?, ?, ?, ?, ?, ?)", [id2, "a", "a", 0, 0, "age", 20])
//      try block.execute("INSERT INTO Field VALUES (?, ?, ?, ?, ?, ?, ?)", [id3, "a", "a", 0, 0, "id", id3])
//      try block.execute("INSERT INTO Field VALUES (?, ?, ?, ?, ?, ?, ?)", [id3, "a", "a", 0, 0, "age", 30])

      let people = try db.fetch(Person2.self, field: "age", where: "? < value AND value < ?", [15, 35])
      print(people)
    }
//    let crate = try LiteCrate(":memory:") {
//      MigrationGroup {
//        CreateTable(Person.self)
//      }
//    }
//    try crate.inTransaction { proxy in
//      try proxy.save(person)
//    }
//
//    var reached = false
//
//    try crate.inTransaction { proxy in
//      guard let fetchedPerson = try proxy.fetch(Person.self, with: person.id) else {
//        XCTFail()
//        return
//      }
//      XCTAssertEqual(fetchedPerson.id, person.id)
//      XCTAssertEqual(fetchedPerson.name, "Bob")
//      XCTAssertEqual(fetchedPerson.dogID, person.dogID)
//      reached = true
//    }
//    XCTAssertTrue(reached)
  }
}
