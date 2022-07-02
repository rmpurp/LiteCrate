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
  var models = [String: [any ModelDotPairProtocol]]()
  var nodes = [Node]()
  var ranges = [EmptyRange]()

  init(models: [String: [any ModelDotPairProtocol]], nodes: [Node], ranges: [EmptyRange]) {
    self.models = models
    self.nodes = nodes
    self.ranges = ranges
  }

  required init(from decoder: Decoder) throws {
    guard let tables = decoder.userInfo[CodingUserInfoKey(rawValue: "tables")!] as? [String: any ReplicatingModel.Type]
    else {
      preconditionFailure()
    }

    let container = try decoder.container(keyedBy: TableNameCodingKey.self)

    for table in tables.values {
      models[table.exampleInstance.tableName] = try decode(table, container: container)
    }

    nodes = try container.decode([Node].self, forKey: .init(stringValue: Node.exampleInstance.tableName))
    ranges = try container.decode([EmptyRange].self, forKey: .init(stringValue: EmptyRange.exampleInstance.tableName))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: TableNameCodingKey.self)
    for (tableName, instances) in models {
      var arrayContainer = container.nestedUnkeyedContainer(forKey: .init(stringValue: tableName))
      for instance in instances {
        try arrayContainer.encode(instance)
      }
    }
    try container.encode(nodes, forKey: .init(stringValue: Node.exampleInstance.tableName))
    try container.encode(ranges, forKey: .init(stringValue: EmptyRange.exampleInstance.tableName))
  }
}

private func decode<T: ReplicatingModel>(
  _ type: T.Type,
  container: KeyedDecodingContainer<TableNameCodingKey>
) throws -> [any ModelDotPairProtocol] {
  try container.decode([ModelDotPair<T>].self, forKey: .init(stringValue: type.exampleInstance.tableName))
}
