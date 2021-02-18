import Combine
import XCTest

@testable import LiteCrate

extension DispatchSemaphore {
  func waitABit() -> DispatchTimeoutResult {
    return wait(timeout: DispatchTime.now().advanced(by: .seconds(1)))
  }
}

final class LiteCrateTests: XCTestCase {
  private let date1 = Date(timeIntervalSince1970: 123_456_789)

  var crate: LiteCrate! = nil

  let updateQueue = DispatchQueue(label: "UpdateQueue")

  override func setUp() {
    crate = try! LiteCrate(url: nil, updateQueue: updateQueue) { (db, currentVersion) in
      if currentVersion < 1 {
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
    updateQueue.sync { print("Clearing out update queue...") }
    crate.closeDatabase()
    crate = nil
  }

  func testDelete() {
    createFixtures()
    let bob = try! Person.fetch(from: crate, with: 1)!
    try! bob.delete(from: crate)
    try! XCTAssertNil(Person.fetch(from: crate, with: 1))
    try! XCTAssertEqual(Person.fetchAll(from: crate).count, 1)
  }

  func testUUIDPrimaryKey() {
    var person = UUIDPKPerson(name: "Jill")
    let id = person.id
    try! person.save(in: crate)

    person = try! UUIDPKPerson.fetch(from: crate, with: id)!

    XCTAssertEqual(person.id, id)
    XCTAssertEqual(person.name, "Jill")
  }

  func createFixtures() {
    var bob = Person(name: "Bob", birthday: date1)
    try! bob.save(in: crate)
    var carol = Person(name: "Carol", birthday: nil)
    carol.name = "Carol"
    try! carol.save(in: crate)
  }

  func testPrimaryKeyPublisher() {
    var alice = Person(name: "Alice", birthday: date1)
    try! alice.save(in: crate)

    var receivedPerson: Person? = nil
    let semaphore = DispatchSemaphore(value: 0)

    let testQueue = DispatchQueue(label: "testPrimaryKeyPublisher")
    var subscriptions = Set<AnyCancellable>()
    Person.publisher(in: crate, forPrimaryKey: alice.id)
      .receive(on: testQueue)
      .sink {
        receivedPerson = $0
        semaphore.signal()
      }
      .store(in: &subscriptions)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertEqual(receivedPerson?.id, alice.id)
    XCTAssertEqual(receivedPerson?.name, "Alice")
    XCTAssertEqual(receivedPerson?.birthday, date1)

    var bob = Person(name: "Bob", birthday: nil)
    try! bob.save(in: crate)

    alice.name = "Alice Changed"
    try! alice.save(in: crate)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertEqual(receivedPerson?.id, alice.id)
    XCTAssertEqual(receivedPerson?.name, "Alice Changed")
    XCTAssertEqual(receivedPerson?.birthday, alice.birthday)
    subscriptions.removeAll()
  }

  func testUpdatePublisher() {
    var alice = Person(name: "Alice", birthday: date1)
    try! alice.save(in: crate)

    XCTAssertNotNil(alice.id)
    let testQueue = DispatchQueue(label: "testUpdatePublisher")
    let semaphore = DispatchSemaphore(value: 0)

    var aliceChanged: Person? = nil
    var subscriptions = Set<AnyCancellable>()
    defer { subscriptions.removeAll() }

    alice.updatePublisher(in: crate)
      .receive(on: testQueue)
      .sink {
        aliceChanged = $0
        semaphore.signal()
      }.store(in: &subscriptions)

    alice.name = "Alice Changed"
    try! alice.save(in: crate)
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
    var alice = Person(name: "Alice")
    let semaphore = DispatchSemaphore(value: 0)
    var personDidFire = false

    let testQueue = DispatchQueue(label: "testTableUpdatedPublisherQueue")

    var subscriptions = Set<AnyCancellable>()
    defer { subscriptions.removeAll() }  // Ensure subscriptions stays in scope
    Person.tableUpdatedPublisher(in: crate)
      .receive(on: testQueue)
      .sink {
        personDidFire = true
        semaphore.signal()
      }.store(in: &subscriptions)

    try! alice.save(in: crate)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertTrue(personDidFire)

    personDidFire = false
    try! alice.save(in: crate)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertTrue(personDidFire)

    // Try inserting another object, make sure person publisher does not fire
    var dogDidFire = false
    personDidFire = false

    let fido = Dog(name: "Fido", owner: 3)
    Dog.tableUpdatedPublisher(in: crate, notifyOn: testQueue)
      .sink {
        dogDidFire = true
        semaphore.signal()
      }
      .store(in: &subscriptions)

    try! fido.save(in: crate)
    XCTAssertEqual(semaphore.waitABit(), .success)
    XCTAssertFalse(personDidFire)
    XCTAssertTrue(dogDidFire)
  }

  func testPublisherAll() {
    createFixtures()
    let semaphore = DispatchSemaphore(value: 0)
    var expectedIDs: Set<Int64> = [1, 2]
    var fetchedPeople: [Person] = []

    let testQueue = DispatchQueue(label: "TestPublisherAll")

    var subscriptions = Set<AnyCancellable>()
    Person.publisher(in: crate)
      .receive(on: testQueue)
      .sink { (people) in
        fetchedPeople = people
        semaphore.signal()
      }.store(in: &subscriptions)

    defer { subscriptions.removeAll() }

    if semaphore.waitABit() == .timedOut {
      XCTFail()
    }

    XCTAssertEqual(fetchedPeople.count, 2)
    for person in fetchedPeople {
      XCTAssertTrue(expectedIDs.contains(person.id!))
    }
    var alice = Person(name: "Alice")
    try! alice.save(in: crate)
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
    let uuid = UUID()

    var person: UUIDPerson = UUIDPerson(specialID: uuid)
    person.specialID = uuid
    try! person.save(in: crate)

    let id = person.id

    person = try! UUIDPerson.fetch(from: crate, with: id!)!
    XCTAssertEqual(person.id, id)
    XCTAssertEqual(person.specialID, uuid)
    XCTAssertEqual(person.optionalID, nil)

    let optionalID = UUID()
    person.optionalID = optionalID
    try! person.save(in: crate)

    person = try! UUIDPerson.fetch(from: crate, with: id!)!
    XCTAssertEqual(person.specialID, uuid)
    XCTAssertEqual(person.optionalID, optionalID)
  }

  func testSave() {
    var alice: Person! = Person(name: "Alice")
    try! alice.save(in: crate)
    XCTAssertEqual(alice.id, 1)
    XCTAssertEqual(alice.name, "Alice")
    XCTAssertEqual(alice.birthday, nil)
    alice = nil  // dealloc so we fetch a fresh copy

    let alice2 = try! Person.fetch(from: crate, with: 1)!
    XCTAssertEqual(alice2.id, 1)
    XCTAssertEqual(alice2.name, "Alice")
    XCTAssertEqual(alice2.birthday, nil)
  }

  func testFetch() {
    createFixtures()
    let bob = try! Person.fetch(from: crate, with: 1)
    let carol = try! Person.fetch(from: crate, with: 2)
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
