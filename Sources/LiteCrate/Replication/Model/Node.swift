//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/17/22.
//

import Foundation

struct Node: DatabaseCodable, Identifiable {
  var id: UUID
  var minTime: Int64
  var time: Int64
  
  static var table: Table {
    #warning("Remove this")
    fatalError()
  }

  static var exampleInstance: Node = .init(id: UUID(), minTime: 0, time: 0)

  mutating func mergeForDecoding(_ other: Node) {
    assert(other.id == id)
    minTime = max(minTime, other.minTime)
    time = max(time, other.time)
  }

  mutating func mergeForEncoding(_ other: Node?) {
    assert(other.flatMap { $0.id == id } ?? true)
    minTime = max(minTime, other?.minTime ?? 0)
    time = min(time, other?.time ?? 0)
  }

  /// Merge the given version vectors when merging a remote node into
  /// this node: each node will have its max time seen set.
  ///
  /// nodeID is "this" node, and its time will be set to the max
  /// time seen across both.
  static func mergeForDecoding(nodeID: UUID, localNodes: [Node], remoteNodes: [Node]) -> [Node] {
    var mergedNodes = remoteNodes.toDict()

    for node in localNodes {
      mergedNodes[node.id, default: node].mergeForDecoding(node)
    }

    let maxTime = mergedNodes.values.lazy.map(\.time).max() ?? 0
    mergedNodes[nodeID]?.time = maxTime

    return [Node](mergedNodes.values)
  }

  /// Merge the given version vectors for the purposes of collecting items to
  /// send to the remote Node. This is only used for comparing times witnessed,
  /// and is not saved into any database. Therefore, any Nodes in the remoteNode
  /// array that is unknown to the localNode is not included in the output.
  static func mergeForEncoding(localNodes: [Node], remoteNodes: [Node]) -> [Node] {
    var mergedNodes = [UUID: Node]()
    let remoteNodes = remoteNodes.toDict()
    for var node in localNodes {
      node.mergeForEncoding(remoteNodes[node.id])
      mergedNodes[node.id] = node
    }
    return [Node](mergedNodes.values)
  }
}

private extension Collection where Element == Node {
  func toDict() -> [UUID: Node] {
    var dict = [UUID: Node]()
    for node in self {
      dict[node.id] = node
    }
    return dict
  }
}
