//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/22/22.
//

import Foundation

extension ReplicationController {
  /// Obtain the payload, only obtaining the changes not yet observed by the remote node according its version vector
  /// passed in as an argument.
  public func payload(remoteNodes: [Node]) throws -> ReplicationPayload {
    var models = [String: [any ModelDotPairProtocol]]()
    var localNodes = [Node]()
    var ranges = [EmptyRange]()
    try inTransaction { [unowned self] proxy in
      localNodes.append(contentsOf: try proxy.fetch(Node.self))
      let nodesForFetching = Node.mergeForEncoding(localNodes: localNodes, remoteNodes: remoteNodes)

      for table in tables.values {
        models[table.exampleInstance.tableName] = try fetch(proxy: proxy, type: table, nodes: nodesForFetching)
      }

      ranges.append(contentsOf: try fetchEmptyRanges(proxy: proxy, nodes: nodesForFetching))
    }
    return ReplicationPayload(models: models, nodes: localNodes, ranges: ranges)
  }

  /// Merge in the given payload.
  public func merge(_ payload: ReplicationPayload) throws {
    try inTransaction { [unowned self] localProxy in
      for modelDotPairs in payload.models.values {
        for pair in modelDotPairs {
          try merge(remoteModel: pair.model, dot: pair.dot, fkDots: pair.foreignKeyDots, proxy: localProxy)
        }
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

  private class DeletedByForeignKeyVisitor<T: ReplicatingModel>: ForeignKeyVisitor {
    func visit<Destination: DatabaseCodable>(_: ForeignKey<T, Destination>) {}
  }

  /// Check if the model with the corresponding dot has been observed to be deleted.
  private func isDeleted<T: ReplicatingModel>(proxy: LiteCrate.TransactionProxy, model _: T, dot: Dot,
                                              fkDots: [ForeignKeyDot]) throws -> Bool
  {
    for foreignKey in fkDots {
      if try proxy
        .fetch(
          EmptyRange.self,
          allWhere: "node = ?1 AND start <= ?2 AND ?2 <= end",
          [foreignKey.parentCreator, foreignKey.parentCreatedTime]
        )
        .first != nil
      {
        return true
      }
    }
    // Check if the model itself was deleted.
    return try proxy
      .fetch(
        EmptyRange.self,
        allWhere: "node = ?1 AND start <= ?2 AND ?2 <= end",
        [dot.creator, dot.createdTime]
      )
      .first != nil
  }

  /// Merge in the given remote model and its corresponding dot.
  private func merge<T: ReplicatingModel>(remoteModel: T, dot: Dot, fkDots: [ForeignKeyDot],
                                          proxy: LiteCrate.TransactionProxy) throws
  {
    guard try !isDeleted(proxy: proxy, model: remoteModel, dot: dot, fkDots: fkDots) else {
      return
    }
    let modelDotPair = ModelDotPair(model: remoteModel, dot: dot, foreignKeyDots: fkDots)
    // Get the local version; the one created later is the winner.
    guard let localModel = try proxy.fetch(ModelDotPair<T>.self, with: remoteModel.id) else {
      try proxy.saveIgnoringDelegate(modelDotPair)
      return
    }

    if localModel.dot < remoteModel.dot {
      if !localModel.dot.isSameVersion(as: remoteModel.dot) {
        try proxy.delete(localModel)
      }
      try proxy.saveIgnoringDelegate(modelDotPair)
    }
    // TODO: If we're newer and different versions I think you could to EmptyRange -- but it would eventually get
    // cleaned up after another round trip.
  }
}

/// Fetch the model-dot pairs for the given ReplicatingModel type.
private func fetch<T: ReplicatingModel>(proxy: LiteCrate.TransactionProxy, type _: T.Type,
                                        nodes: [Node]) throws -> [any ModelDotPairProtocol]
{
  var models: [any ModelDotPairProtocol] = []
  for node in nodes {
    models.append(contentsOf: try proxy.fetchIgnoringDelegate(
      ModelDotPair<T>.self,
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
