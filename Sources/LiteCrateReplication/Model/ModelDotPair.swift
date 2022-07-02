//
//  File.swift
//
//
//  Created by Ryan Purpura on 7/2/22.
//

import Foundation
import LiteCrate

protocol ModelDotPairProtocol: DatabaseCodable {
  var model: any ReplicatingModel { get }
  var dot: Dot { get }
  var foreignKeyDots: [ForeignKeyDot] { get }
}

private class ForeignKeyConverter<T: ReplicatingModel>: ForeignKeyVisitor {
  var newFKs: [AnyForeignKey<ModelDotPair<T>>] = []

  func visit<Destination: DatabaseCodable>(_ element: ForeignKey<T, Destination>) {
    let newFK = ForeignKey<ModelDotPair<T>, Destination>(
      Destination.self,
      columnName: element.columnName,
      action: element.action,
      path: { element.path($0._model) }
    )
    newFKs.append(newFK.typeErase())
  }
}

struct ModelDotPair<T: ReplicatingModel>: ModelDotPairProtocol {
  var primaryKeyValue: UUID { _model.primaryKeyValue }
  typealias Key = UUID

  static var primaryKeyColumn: String { "id" }

  static var exampleInstance: ModelDotPair {
    let foreignKeyDots = T.exampleInstance.foreignKeyConstraints.constraints.map { fk in
      ForeignKeyDot(parentCreator: UUID(), parentCreatedTime: 0, prefix: fk.columnName)
    }
    return ModelDotPair(model: T.exampleInstance, dot: Dot(id: UUID()), foreignKeyDots: foreignKeyDots)
  }

  var tableName: String { model.tableName }
  var foreignKeyDots: [ForeignKeyDot]
  var _model: T

  var model: any ReplicatingModel {
    _model
  }

  var foreignKeyConstraints: FKConstraints<Self> {
    let converter = ForeignKeyConverter<T>()
    _model.foreignKeyConstraints.visit(by: converter)
    return FKConstraints(converter.newFKs)
  }

  var dot: Dot

  init(model: T, dot: Dot, foreignKeyDots: [ForeignKeyDot]) {
    _model = model
    self.dot = dot
    self.foreignKeyDots = foreignKeyDots
  }

  init(from decoder: Decoder) throws {
    _model = try T(from: decoder)
    dot = try Dot(from: decoder)
    foreignKeyDots = []
    for foreignKey in _model.foreignKeyConstraints.constraints {
      foreignKeyDots.append(try ForeignKeyDot(from: decoder, prefix: foreignKey.columnName))
    }
  }

  func encode(to encoder: Encoder) throws {
    try model.encode(to: encoder)
    try dot.encode(to: encoder)
    for fk in foreignKeyDots {
      try fk.encode(to: encoder)
    }
  }
}

extension ReplicatingModel {
  func toErasedModelDot(dot: Dot, fkDots: [ForeignKeyDot]) -> any DatabaseCodable {
    ModelDotPair(model: self, dot: dot, foreignKeyDots: fkDots)
  }
}
