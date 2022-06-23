//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/17/22.
//

import Foundation
import LiteCrate

struct TableNameCodingKey: CodingKey {
  var stringValue: String

  init(stringValue: String) {
    self.stringValue = stringValue
  }

  var intValue: Int?

  init?(intValue _: Int) {
    nil
  }
}

class ReplicationPayload: Codable {
  var models = [String: [any ReplicatingModel]]()
  var nodes = [Node]()

  init(models: [String: [any ReplicatingModel]], nodes: [Node]) {
    self.models = models
    self.nodes = nodes
  }

  required init(from decoder: Decoder) throws {
    guard let exampleInstances = decoder.userInfo[CodingUserInfoKey(rawValue: "instances")!] as? [any ReplicatingModel] else {
      preconditionFailure()
    }

    let container = try decoder.container(keyedBy: TableNameCodingKey.self)

    for instance in exampleInstances {
      models[instance.tableName] = try decode(instance: instance, container: container)
    }

    nodes = try container.decode([Node].self, forKey: .init(stringValue: Node.tableName))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TableNameCodingKey.self)
    for (tableName, instances) in models {
      var arrayContainer = container.nestedUnkeyedContainer(forKey: .init(stringValue: tableName))
      for instance in instances {
        try arrayContainer.encode(instance)
      }
    }
    try container.encode(nodes, forKey: .init(stringValue: Node.tableName))
  }
}

private func decode<T: ReplicatingModel>(instance: T, container: KeyedDecodingContainer<TableNameCodingKey>) throws -> [T] {
  try container.decode([T].self, forKey: .init(stringValue: instance.tableName))
}
