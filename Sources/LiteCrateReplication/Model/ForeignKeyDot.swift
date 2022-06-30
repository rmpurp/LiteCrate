//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/28/22.
//

import Foundation

struct ForeignKeyDot: Codable {
  var parentCreator: Node.Key
  var parentCreatedTime: Int64

  init(parentCreator: Node.Key, parentCreatedTime: Int64) {
    self.parentCreator = parentCreator
    self.parentCreatedTime = parentCreatedTime
  }

  init<T: ReplicatingModel>(parent: T) {
    parentCreator = parent.dot.creator
    parentCreatedTime = parent.dot.createdTime
  }
}
