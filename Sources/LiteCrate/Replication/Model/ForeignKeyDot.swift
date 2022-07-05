//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/28/22.
//

import Foundation

struct ForeignKeyDot: Codable {
  var prefix: String
  var parentCreator: Node.Key
  var parentCreatedTime: Int64

  struct CodingKeys: CodingKey {
    var stringValue: String

    init?(stringValue: String) {
      self.stringValue = stringValue
    }

    var intValue: Int?

    init?(intValue _: Int) {
      nil
    }

    init(prefix: String, what: String) {
      stringValue = prefix + what
    }
  }

  init(parentCreator: Node.Key, parentCreatedTime: Int64, prefix: String = "parent") {
    self.parentCreator = parentCreator
    self.parentCreatedTime = parentCreatedTime
    self.prefix = prefix
  }

  init<T: ReplicatingModel>(parent: T, prefix: String = "parent") {
    parentCreator = parent.dot.creator
    parentCreatedTime = parent.dot.createdTime
    self.prefix = prefix
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(parentCreator, forKey: CodingKeys(prefix: prefix, what: "Creator"))
    try container.encode(parentCreatedTime, forKey: CodingKeys(prefix: prefix, what: "CreatedTime"))
  }

  init(from decoder: Decoder) throws {
    try self.init(from: decoder, prefix: "parent")
  }

  init(from decoder: Decoder, prefix: String) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    parentCreator = try container.decode(Node.Key.self, forKey: CodingKeys(prefix: prefix, what: "Creator"))
    parentCreatedTime = try container.decode(Int64.self, forKey: CodingKeys(prefix: prefix, what: "CreatedTime"))
    self.prefix = prefix
  }
}
