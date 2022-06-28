//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/22/22.
//

import Foundation
import LiteCrate

extension ReplicationController {
  public func payload(remoteNodes: [Node]) throws -> ReplicationPayload {
    var models = [String: [any ReplicatingModel]]()
    var localNodes = [Node]()
    var ranges = [EmptyRange]()
    try inTransaction { [unowned self] proxy in
      localNodes.append(contentsOf: try proxy.fetch(Node.self))
      let nodesForFetching = Node.mergeForEncoding(localNodes: localNodes, remoteNodes: remoteNodes)

      for exampleInstance in exampleInstances {
        models[exampleInstance.tableName] = try fetch(instance: exampleInstance, proxy: proxy, nodes: nodesForFetching)
      }

      ranges.append(contentsOf: try fetchEmptyRanges(proxy: proxy, nodes: nodesForFetching))
    }
    return ReplicationPayload(models: models, nodes: localNodes, ranges: ranges)
  }

  public func merge(_ payload: ReplicationPayload) throws {
    try inTransaction { [unowned self] localProxy in
      for instance in exampleInstances {
        try merge(model: instance, nodeID: nodeID, time: time, localProxy: localProxy, payload: payload)
      }

      let localNodes = try localProxy.fetch(Node.self)
      for node in Node.mergeForDecoding(nodeID: nodeID, localNodes: localNodes, remoteNodes: payload.nodes) {
        try localProxy.saveIgnoringDelegate(node)
      }

      for emptyRange in payload.ranges {
        try addAndMerge(localProxy, range: emptyRange, deleteModels: true)
      }
    }
  }

  private func isDeleted(proxy: LiteCrate.TransactionProxy, dot: Dot) throws -> Bool {
    try proxy
      .fetch(EmptyRange.self, allWhere: "node = ?1 AND start <= ?2 AND ?2 <= end", [dot.creator, dot.createdTime])
      .first != nil
  }

  private func merge<T: ReplicatingModel>(model _: T,
                                          nodeID _: UUID,
                                          time _: Int64,
                                          localProxy: LiteCrate.TransactionProxy,
                                          payload: ReplicationPayload) throws
  {
    let remoteModels = payload.models[T.tableName]! // TODO: Throw error.

    for remoteModel in remoteModels {
      guard try !isDeleted(proxy: localProxy, dot: remoteModel.dot) else {
        continue
      }
      // Get the local version; the one created later is the winner.
      guard let localModel = try localProxy.fetch(T.self, with: remoteModel.id) else {
        try localProxy.saveIgnoringDelegate(remoteModel)
        continue
      }

      if localModel.dot < remoteModel.dot {
        if !localModel.dot.isSameVersion(as: remoteModel.dot) {
          try localProxy.delete(localModel)
        }
        try localProxy.saveIgnoringDelegate(remoteModel)
      }
      // TODO: If we're newer and different versions I think you could to EmptyRange -- but it would eventually get
      // cleaned up after another round trip.
    }
  }
}

private func fetch<T: ReplicatingModel>(instance _: T, proxy: LiteCrate.TransactionProxy,
                                        nodes: [Node]) throws -> [any ReplicatingModel]
{
  var models: [T] = []
  for node in nodes {
    models.append(contentsOf: try proxy.fetchIgnoringDelegate(
      T.self,
      allWhere: "lastModifier = ? AND sequenceNumber >= ?",
      [node.id, node.time]
    ))
  }
  return models
}

// TODO: somehow combine with above.
private func fetchEmptyRanges(proxy: LiteCrate.TransactionProxy,
                              nodes: [Node]) throws -> [EmptyRange]
{
  var ranges: [EmptyRange] = []
  for node in nodes {
    ranges.append(contentsOf: try proxy.fetchIgnoringDelegate(
      EmptyRange.self,
      allWhere: "lastModifier = ? AND sequenceNumber >= ?",
      [node.id, node.time]
    ))
  }
  return ranges
}

private func populate<T: ReplicatingModel>(
  instance _: T,
  proxy: LiteCrate.TransactionProxy,
  container: KeyedDecodingContainer<TableNameCodingKey>
) throws {
  let instances = try container.decode([T].self, forKey: TableNameCodingKey(stringValue: T.tableName))
  for instance in instances {
    try proxy.saveIgnoringDelegate(instance)
  }
}
