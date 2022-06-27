//
//  PayloadTest.swift
//
//
//  Created by Ryan Purpura on 6/22/22.
//

@testable import LiteCrateReplication
import XCTest

private struct ModelA: ReplicatingModel, Equatable {
  var dot: Dot = .init()
  var value: Int64
}

private struct ModelB: ReplicatingModel, Equatable {
  var dot: Dot = .init()
  var value: String
}

extension Node: Equatable {
  public static func == (lhs: Node, rhs: Node) -> Bool {
    lhs.id == rhs.id && lhs.time == rhs.time && lhs.minTime == rhs.minTime
  }
}

final class PayloadTests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testPayloadCodingRoundtrip() throws {
    let payload = ReplicationPayload(models: [
      "ModelA": [ModelA(value: 5), ModelA(value: 8)],
      "ModelB": [ModelB(value: "a"), ModelB(value: "b"), ModelB(value: "c")],
    ], nodes: [
      Node(id: UUID(), minTime: 1, time: 2),
      Node(id: UUID(), minTime: 3, time: 4),
      Node(id: UUID(), minTime: 5, time: 6),
    ], ranges: [
      EmptyRange(node: UUID(), start: 0, end: 3, lastModifier: UUID(), sequenceNumber: 5),
      EmptyRange(node: UUID(), start: 7, end: 9, lastModifier: UUID(), sequenceNumber: 1003),
    ])

    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()
    jsonDecoder.userInfo = [.init(rawValue: "instances")!: [ModelA(value: 0), ModelB(value: "")]]

    let encoded = try jsonEncoder.encode(payload)
    let decoded = try jsonDecoder.decode(ReplicationPayload.self, from: encoded)
    let actualModels = decoded.models["ModelA"] as! [ModelA]
    let actualModelsB = decoded.models["ModelB"] as! [ModelB]
    XCTAssertEqual(actualModels, payload.models["ModelA"] as! [ModelA])
    XCTAssertEqual(actualModelsB, payload.models["ModelB"] as! [ModelB])
    XCTAssertEqual(decoded.nodes, payload.nodes)
  }
}
