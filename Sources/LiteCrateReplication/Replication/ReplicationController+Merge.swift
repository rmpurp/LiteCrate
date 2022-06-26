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
    }
    return ReplicationPayload(models: models, nodes: localNodes, ranges: ranges)
  }

  public func merge(_ payload: ReplicationPayload) throws {
    try inTransaction { [unowned self] localProxy in
      for instance in exampleInstances {
        if let remoteModels = payload.models[instance.tableName] {
          try merge(models: remoteModels, localProxy: localProxy)
        }
      }

      let localNodes = try localProxy.fetch(Node.self)
      for node in Node.mergeForDecoding(nodeID: nodeID, localNodes: localNodes, remoteNodes: payload.nodes) {
        try localProxy.saveIgnoringDelegate(node)
      }
    }
  }

  /// If it exists, get the dot corresponding to the model with the same id and not null.
  private func getActiveWithSameID<T: ReplicatingModel>(proxy: LiteCrate.TransactionProxy, model: T) throws -> T? {
    try proxy.fetchIgnoringDelegate(T.self, allWhere: "modifiedTime IS NOT NULL AND id = ?", [model.dot.id]).first
  }

  private func knownToHaveBeenDeleted(_ proxy: LiteCrate.TransactionProxy, dot: Dot) throws -> Bool {
    try proxy
      .fetch(EmptyRange.self, allWhere: "node = ?1 AND start >= ?2 AND end <= ?2", [dot.creator, dot.createdTime])
      .first != nil
  }

  private func merge<T: Collection>(models _: T,
                                    localProxy: LiteCrate.TransactionProxy) throws where T.Element: ReplicatingModel
  {
    let nodes = try localProxy.fetchIgnoringDelegate(Node.self)
    let nodeDict = [UUID: Node](uniqueKeysWithValues: nodes.lazy.map { ($0.id, $0) })

    for remoteModel in remoteModels {}

    // TODO: sync stuff
  }
}

private func fetch<T: ReplicatingModel>(instance _: T, proxy: LiteCrate.TransactionProxy,
                                        nodes: [Node]) throws -> [any ReplicatingModel]
{
  var models: [T] = []
  for node in nodes {
    models.append(contentsOf: try proxy.fetchIgnoringDelegate(
      T.self,
      allWhere: "witnessedNode = ? AND witnessedTime >= ?",
      [node.id, node.time]
    ))
  }
  return models
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
