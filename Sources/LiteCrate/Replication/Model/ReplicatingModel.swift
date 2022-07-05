//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

public protocol ReplicatingModel: DatabaseCodable<UUID>, Identifiable {
  var dot: Dot { get set }
  /// Whether the model has foreign keys referring to it.
  var isParent: Bool { get }
}

public extension ReplicatingModel {
  var id: UUID { dot.id }
  var isParent: Bool { false }
}
