import Combine
import XCTest

@testable import LiteCrate
import SQLite3

extension DispatchSemaphore {
  func waitABit() -> DispatchTimeoutResult {
    return wait(timeout: DispatchTime.now().advanced(by: .seconds(1)))
  }
}

@available(macOS 12.0, *)
final class LiteCrateTests: XCTestCase {
  private let date1 = Date(timeIntervalSince1970: 123_456_789)
  
  func createCrate() async -> LiteCrate {
    try! LiteCrate(url: nil) { (db, currentVersion) in
      if currentVersion < 1 {
        try db.executeUpdate(
          """
            CREATE TABLE Person (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                birthday INTEGER
            )
          """, values: nil)
        
        try db.executeUpdate(
          """
            CREATE TABLE Dog (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                owner INTEGER,
                FOREIGN KEY (owner) REFERENCES Person(id)
            )
          """, values: nil)
        
        try db.executeUpdate(
          """
            CREATE TABLE UUIDPerson (
                id INTEGER PRIMARY KEY,
                specialID TEXT NOT NULL,
                optionalID TEXT
            )
          """, values: nil)
        
        try db.executeUpdate(
          """
            CREATE TABLE UUIDPKPerson (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )
          """, values: nil)
      }
    }
  }
  
  func testSave() async {
    lc_log("Running \(#function)")
    let crate = await createCrate()
    
    var bob = Person(name: "Bob")
    bob.birthday = date1
    
    try! await crate.save(bob)
    
    let bobCopy = try! await crate.fetch(Person.self, with: bob.id)
    
    guard let bobCopy = bobCopy else {
      XCTFail()
      await crate.close()
      return
    }
    
    XCTAssertEqual(bob.id, bobCopy.id)
    XCTAssertEqual(bob.birthday, bobCopy.birthday)
    XCTAssertEqual(bob.name, bobCopy.name)
    XCTAssertEqual(bobCopy.birthday, date1)
    XCTAssertEqual(bobCopy.name, "Bob")
    await crate.close()
  }
  
  func makeBob(in crate: LiteCrate) async -> Person {
    let bob = Person(name: "Bob", birthday: date1)
    try! await crate.inTransaction { proxy in
      try proxy.save(bob)
    }
    return bob
  }
  
  func testDelete() async {
    lc_log("Running \(#function)")
    
    let crate = await createCrate()
    
    let bob = await makeBob(in: crate)
    
    var bobCopy = try! await crate.inTransaction { proxy in
      try proxy.fetch(Person.self, with: bob.id)
    }
    
    XCTAssertNotNil(bobCopy)
    
    try! await crate.inTransaction { proxy in
      try proxy.delete(bob)
    }
    
    bobCopy = try! await crate.inTransaction { proxy in
      try proxy.fetch(Person.self, with: bob.id)
    }
    
    XCTAssertNil(bobCopy)
    await crate.close()
  }
  
  func testStream() async {
    lc_log("Running \(#function)")
    
    let crate = await createCrate()
    let bob = await makeBob(in: crate)
    let sally = Person(name: "Sally")
    let marco = Person(name: "Marco")
    
    let stream = await crate.stream(for: Person.self)
    
    let task = Task {
      var counter = 0
      for try await elements in stream {
        if counter == 0 {
          XCTAssertEqual(elements.count, 1)
          XCTAssertTrue(elements.contains(bob))
        } else if counter == 1 {
          XCTAssertEqual(elements.count, 2)
          XCTAssertTrue(elements.contains(bob))
          XCTAssertTrue(elements.contains(sally))
        } else if counter == 2 {
          XCTAssertEqual(elements.count, 2)
          XCTAssertTrue(elements.contains(sally))
          XCTAssertTrue(elements.contains(marco))
        } else if counter == 3 {
          XCTAssertEqual(elements.count, 1)
          XCTAssertTrue(elements.contains(sally))
          break
        }
        
        counter += 1
      }
    }
    
    try! await crate.inTransaction { proxy in
      try proxy.save(sally)
    }
    
    try! await crate.inTransaction { proxy in
      try proxy.delete(bob)
      try proxy.save(marco)
    }
    
    try! await crate.inTransaction { proxy in
      try proxy.delete(marco)
    }
    
    try! await task.value
  }
}
