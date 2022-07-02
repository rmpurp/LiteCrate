import Combine
import XCTest

@testable import LiteCrate
import SQLite3

extension DispatchSemaphore {
  func waitABit() -> DispatchTimeoutResult {
    wait(timeout: DispatchTime.now().advanced(by: .seconds(1)))
  }
}

@available(macOS 12.0, *)
final class LiteCrateTests: XCTestCase {
  func testSaveAndFetch() throws {
    let person = Person(name: "Bob", dogID: UUID())
    let crate = try LiteCrate(":memory:") {
      MigrationGroup {
        CreateTable(Person.self)
      }
    }
    try crate.inTransaction { proxy in
      try proxy.save(person)
    }

    var reached = false

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
