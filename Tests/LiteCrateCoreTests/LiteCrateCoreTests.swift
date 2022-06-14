import XCTest
@testable import LiteCrateCore

final class LiteCrateCoreTests: XCTestCase {
  func testExample() throws {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    let db = try Database(":memory:")
    try db.execute("CREATE TABLE Test(a, b, c, d, e, f, g, h, i)")
    let testUUID = UUID()
    let testData = "datadatadatablob".data(using: .utf8)!
    let testDate = Date()
    try db.execute("INSERT INTO Test VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)", ["test", 12321, 3.14, testData, nil, testDate, testUUID, true, false])
    let cursor = try db.query("SELECT a, b, c, d, e, f, g, h, i from TEST")
    XCTAssertTrue(cursor.step())
    XCTAssertEqual(cursor.string(for: 0), "test")
    XCTAssertEqual(cursor.int(for: 1), 12321)
    XCTAssertEqual(cursor.double(for: 2), 3.14)
    XCTAssertEqual(cursor.data(for: 3), testData)
    XCTAssertTrue(cursor.isNull(for: 4))
    XCTAssertLessThanOrEqual(abs(cursor.date(for: 5).timeIntervalSince(testDate)), 1.0)
    XCTAssertEqual(cursor.uuid(for: 6), testUUID)
    XCTAssertTrue(cursor.bool(for: 7))
    XCTAssertFalse(cursor.bool(for: 8))
  }
}
