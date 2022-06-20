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
  func testTableCreation() {
    let person = Person(name: "arst", dogID: UUID())
    print(person.creationStatement)
    XCTAssertTrue(true)
  }

  func testSaveAndFetch() throws {
    let person = Person(name: "Bob", dogID: UUID())
    let crate = try LiteCrate(":memory:") {
      MigrationGroup {
        CreateTable(Person(name: "", dogID: UUID()))
      }
    }
    try crate.inTransaction { proxy in
      try proxy.save(person)
    }

    var reached: Bool = false

    try crate.inTransaction { proxy in
      guard let fetchedPerson = try proxy.fetch(Person.self, with: person.id) else {
        XCTFail()
        return
      }
      XCTAssertEqual(fetchedPerson.id, person.id)
      XCTAssertEqual(fetchedPerson.name, "Bob")
      XCTAssertEqual(fetchedPerson.dogID, person.dogID)
      reached = true
    }
    XCTAssertTrue(reached)
  }
}
