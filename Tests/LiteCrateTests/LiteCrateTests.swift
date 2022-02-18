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
}
