import XCTest

#if !canImport(ObjectiveC)
  public func allTests() -> [XCTestCaseEntry] {
    [
      testCase(LiteCrateTests.allTests),
    ]
  }
#endif
