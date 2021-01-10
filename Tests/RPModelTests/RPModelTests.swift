import XCTest

@testable import RPModel

extension DispatchSemaphore {
  func waitABit() -> DispatchTimeoutResult {
    return wait(timeout: DispatchTime.now().advanced(by: .seconds(1)))
  }
}

final class RPModelTests: XCTestCase {
  private let date1 = Date(timeIntervalSince1970: 123_456_789)
  
  var store: DataStore!
  
  override func setUp() {
    store = try! DataStore(url: nil) { (db, currentVersion) in
      if currentVersion < 0 {
        try db.executeUpdate(
          """
            CREATE TABLE Person (
                id INTEGER PRIMARY KEY,
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

  override func tearDown() {
    store.closeDatabase()
    store = nil
  }

  func testDelete() {
    createFixtures()
    let bob = Person.fetch(store: store, with: 1)!
    try! bob.delete(store: store)
    XCTAssertNil(Person.fetch(store: store, with: 1))
    XCTAssertEqual(Person.fetchAll(store: store).count, 1)
  }

  func testUUIDPrimaryKey() {
    var person = UUIDPKPerson(name: "Jill")
    let id = person.id
    try! person.save(store: store)

    person = UUIDPKPerson.fetch(store: store,with: id)!

    XCTAssertEqual(person.id, id)
    XCTAssertEqual(person.name, "Jill")
  }

  func createFixtures() {
    var bob = Person()
    bob.name = "Bob"
    bob.birthday = date1
    try! bob.save(store: store)
    var carol = Person()
    carol.name = "Carol"
    try! carol.save(store: store)
  }

  func testPrimaryKeyPublisher() {
    var alice = Person()
    alice.name = "Alice"
    alice.birthday = date1
    try! alice.save(store: store)

    var receivedPerson: Person? = nil
    let semaphore = DispatchSemaphore(value: 0)

    _ = Person.publisher(store: store, forPrimaryKey: alice.id)
      .sink {
        receivedPerson = $0
        semaphore.signal()
      }
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertEqual(receivedPerson?.id, alice.id)
    XCTAssertEqual(receivedPerson?.name, "Alice")
    XCTAssertEqual(receivedPerson?.birthday, date1)

    var bob = Person()
    bob.name = "Bob"
    try! bob.save(store: store)

    alice.name = "Alice Changed"
    try! alice.save(store: store)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertEqual(receivedPerson?.id, alice.id)
    XCTAssertEqual(receivedPerson?.name, "Alice Changed")
    XCTAssertEqual(receivedPerson?.birthday, alice.birthday)

  }

  func testUpdatePublisher() {
    var alice = Person()
    alice.name = "Alice"
    alice.birthday = date1
    try! alice.save(store: store)

    XCTAssertNotNil(alice.id)

    let semaphore = DispatchSemaphore(value: 0)

    var aliceChanged: Person? = nil

    _ = alice.updatePublisher(store: store).sink {
      aliceChanged = $0
      semaphore.signal()
    }

    alice.name = "Alice Changed"
    try! alice.save(store: store)
    XCTAssertEqual(semaphore.waitABit(), .success)

    if let aliceChanged = aliceChanged {
      XCTAssertEqual(aliceChanged.name, "Alice Changed")
      XCTAssertEqual(aliceChanged.id, alice.id)
      XCTAssertEqual(aliceChanged.birthday, alice.birthday)
    } else {
      XCTFail()
    }
  }

  func testTableUpdatedPublisher() {
    var alice = Person()
    alice.name = "Alice"
    let semaphore = DispatchSemaphore(value: 0)
    var personDidFire = false

    let subscription = Person.tableUpdatedPublisher(store: store)
      .sink {
        personDidFire = true
        semaphore.signal()
      }

    try! alice.save(store: store)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertTrue(personDidFire)

    personDidFire = false
    try! alice.save(store: store)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertTrue(personDidFire)

    // Try inserting another object, make sure person publisher does not fire
    var dogDidFire = false
    personDidFire = false

    let fido = Dog(name: "Fido", owner: 3)
    let dogSub = Dog.tableUpdatedPublisher(store: store)
      .sink {
        dogDidFire = true
        semaphore.signal()
      }
    try! fido.save(store: store)
    XCTAssertEqual(semaphore.waitABit(), .success)

    XCTAssertFalse(personDidFire)
    XCTAssertTrue(dogDidFire)

    dogSub.cancel()
    subscription.cancel()
  }

  func testPublisherAll() {
    createFixtures()
    let semaphore = DispatchSemaphore(value: 0)
    var expectedIDs: Set<Int64> = [1, 2]
    var fetchedPeople: [Person] = []
    _ = Person.publisher(store: store)
      .sink { (people) in
        fetchedPeople = people
        semaphore.signal()
      }
    if semaphore.waitABit() == .timedOut {
      XCTFail()
    }

    XCTAssertEqual(fetchedPeople.count, 2)
    for person in fetchedPeople {
      XCTAssertTrue(expectedIDs.contains(person.id!))
    }
    var alice = Person()
    alice.name = "Alice"
    try! alice.save(store: store)
    expectedIDs.insert(3)

    if semaphore.waitABit() == .timedOut {
      XCTFail()
    }

    XCTAssertEqual(fetchedPeople.count, 3)
    for person in fetchedPeople {
      XCTAssertTrue(expectedIDs.contains(person.id!))
    }
  }

  func testFetchUUID() {
    var person: UUIDPerson = UUIDPerson()
    let uuid = UUID()
    person.specialID = uuid
    try! person.save(store: store)

    let id = person.id

    person = UUIDPerson.fetch(store: store, with: id!)!
    XCTAssertEqual(person.specialID, uuid)
    XCTAssertEqual(person.optionalID, nil)

    let optionalID = UUID()
    person.optionalID = optionalID
    try! person.save(store: store)

    person = UUIDPerson.fetch(store: store, with: id!)!
    XCTAssertEqual(person.specialID, uuid)
    XCTAssertEqual(person.optionalID, optionalID)
  }

  func testSave() {
    var alice: Person! = Person()
    alice.name = "Alice"
    try! alice.save(store: store)
    XCTAssertEqual(alice.id, 1)
    XCTAssertEqual(alice.name, "Alice")
    XCTAssertEqual(alice.birthday, nil)
    alice = nil  // dealloc so we fetch a fresh copy

    let alice2 = Person.fetch(store: store, with: 1)!
    XCTAssertEqual(alice2.id, 1)
    XCTAssertEqual(alice2.name, "Alice")
    XCTAssertEqual(alice2.birthday, nil)
  }

  func testFetch() {
    createFixtures()
    let bob = Person.fetch(store: store, with: 1)
    let carol = Person.fetch(store: store, with: 2)
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
    ("testFetch", testFetch)
  ]
}
