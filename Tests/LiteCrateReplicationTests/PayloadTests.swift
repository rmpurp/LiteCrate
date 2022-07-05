//
//  PayloadTest.swift
//
//
//  Created by Ryan Purpura on 6/22/22.
//

@testable import LiteCrate
import XCTest

private struct ModelA: ReplicatingModel, Equatable {
  var dot: Dot = .init()
  var value: Int64

  static var exampleInstance: ModelA {
    ModelA(value: 0)
  }
}

private struct ModelB: ReplicatingModel, Equatable {
  var dot: Dot = .init()
  var value: String

  static var exampleInstance: ModelB {
    ModelB(value: "")
  }
}

extension Node: Equatable {
  public static func == (lhs: Node, rhs: Node) -> Bool {
    lhs.id == rhs.id && lhs.time == rhs.time && lhs.minTime == rhs.minTime
  }
}

extension ReplicatingModel {
  var pair: any ModelDotPairProtocol {
    // TODO: Fix
    ModelDotPair(model: self, dot: dot, foreignKeyDots: [])
  }
}

final class PayloadTests: XCTestCase {
  func testPayloadCodingRoundtrip() throws {
    let payload = ReplicationPayload(models: [
      "ModelA": [ModelA(value: 5).pair, ModelA(value: 8).pair],
      "ModelB": [ModelB(value: "a").pair, ModelB(value: "b").pair, ModelB(value: "c").pair],
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
    jsonDecoder.userInfo = [.init(rawValue: "tables")!: ["ModelA": ModelA.self, "ModelB": ModelB.self]]

    let encoded = try jsonEncoder.encode(payload)
    let decoded = try jsonDecoder.decode(ReplicationPayload.self, from: encoded)
    let actualModels = decoded.models["ModelA"]!.map { $0.model as! ModelA }
    let actualModelsB = decoded.models["ModelB"]!.map { $0.model as! ModelB }
    XCTAssertEqual(actualModels, payload.models["ModelA"]!.map { $0.model as! ModelA })
    XCTAssertEqual(actualModelsB, payload.models["ModelB"]!.map { $0.model as! ModelB })
    XCTAssertEqual(decoded.nodes, payload.nodes)
  }
}
