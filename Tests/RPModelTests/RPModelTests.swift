import XCTest
@testable import RPModel

extension DispatchSemaphore {
  func waitABit() -> DispatchTimeoutResult {
    return wait(timeout: DispatchTime.now().advanced(by: .milliseconds(500)))
  }

}

final class RPModelTests: XCTestCase {
  
  private let date1 = Date(timeIntervalSince1970: 123456789)
  
  override func setUp() {
    RPModel.closeDatabase()
    RPModel.openDatabase(at: nil) { [self] (db, currentVersion) in
      if currentVersion < 0 {
        try db.executeUpdate("""
          CREATE TABLE Person (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              birthday DATE
          )
        """, values: nil)

        try db.executeUpdate("""
          CREATE TABLE Dog (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              owner INTEGER,
              FOREIGN KEY (owner) REFERENCES Person(id)
          )
        """, values: nil)
        
        try db.executeUpdate("""
          INSERT INTO Person values (1, "Bob", ?), (2, "Carol", NULL)
        """, values: [date1])
      }
    }
  }
  
  override func tearDown() {
    RPModel.closeDatabase()
  }
  
  func testTableUpdatedPublisher() {
    let alice: Person = Person()
    alice.name = "Alice"
    let semaphore = DispatchSemaphore(value: 0)
    var personDidFire = false
    
    let subscription = Person.tableUpdatedPublisher()
      .sink {
        personDidFire = true
        semaphore.signal()
      }
    
    alice.save()
    _ = semaphore.wait(timeout: DispatchTime.now().advanced(by: .milliseconds(500)))
    XCTAssertTrue(personDidFire)
    
    personDidFire = false
    alice.save()
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertTrue(personDidFire)
    
    // Try inserting another object, make sure person publisher does not fire
    var dogDidFire = false
    personDidFire = false
    
    let fido = Dog(name: "Fido", owner: 3)
    let dogSub = Dog.tableUpdatedPublisher()
      .sink {
        dogDidFire = true
        semaphore.signal()
      }
    fido.save()
    XCTAssertEqual(semaphore.waitABit(), .success)

    XCTAssertFalse(personDidFire)
    XCTAssertTrue(dogDidFire)
    
    dogSub.cancel()
    subscription.cancel()
  }
  
  func testPublisherAll() {
    let semaphore = DispatchSemaphore(value: 0)
    var expectedIDs: Set<Int64> = [1, 2]
    var fetchedPeople: [Person] = []
    _ = Person.publisher()
      .sink { (people) in
        fetchedPeople = people
        semaphore.signal()
      }
    if semaphore.waitABit() == .timedOut {
      XCTFail()
    }
    
    XCTAssertEqual(fetchedPeople.count, 2)
    for person in fetchedPeople {
      XCTAssertTrue(expectedIDs.contains(person.id))
    }
    
    let alice = Person()
    alice.name = "Alice"
    alice.save(waitUntilComplete: true)
    expectedIDs.insert(3)

    if semaphore.waitABit() == .timedOut {
      XCTFail()
    }

    XCTAssertEqual(fetchedPeople.count, 3)
    for person in fetchedPeople {
      XCTAssertTrue(expectedIDs.contains(person.id))
    }

  }
  
  func testConsistentFetchAfterSave() {
    let alice: Person! = Person()
    alice.name = "Alice"
    alice.save(waitUntilComplete: true)
    XCTAssertEqual(alice.id, 3)
    XCTAssertEqual(alice.name, "Alice")
    XCTAssertEqual(alice.birthday, nil)
    
    let alice2 = Person.fetch(with: 3)!
    XCTAssertEqual(alice2.id, 3)
    XCTAssertEqual(alice2.name, "Alice")
    XCTAssertEqual(alice2.birthday, nil)
    XCTAssertTrue(alice === alice2)    
  }
  
  func testSave() {
    var alice: Person! = Person()
    alice.name = "Alice"
    alice.save(waitUntilComplete: true)
    XCTAssertEqual(alice.id, 3)
    XCTAssertEqual(alice.name, "Alice")
    XCTAssertEqual(alice.birthday, nil)
    alice = nil // dealloc so we fetch a fresh copy
    
    
    let alice2 = Person.fetch(with: 3)!
    XCTAssertEqual(alice2.id, 3)
    XCTAssertEqual(alice2.name, "Alice")
    XCTAssertEqual(alice2.birthday, nil)
    
    let alice3 = Person.fetch(with: 3)!
    XCTAssertTrue(alice2 === alice3)
  }
  
  func testFetch() {
    let bob = Person.fetch(with: 1)
    let carol = Person.fetch(with: 2)
    XCTAssertNotNil(bob)
    XCTAssertEqual(bob!.id, 1)
    XCTAssertEqual(bob!.name, "Bob")
    XCTAssertEqual(bob!.birthday, date1)
    
    XCTAssertNotNil(carol)
    XCTAssertEqual(carol!.id, 2)
    XCTAssertEqual(carol!.name, "Carol")
    XCTAssertEqual(carol!.birthday, nil)
  }
  
  
  
  static var allTests = [
    ("testFetch", testFetch),
    ("testFetch", testSave),
    ("testFetch", testConsistentFetchAfterSave),
    
  ]
}
