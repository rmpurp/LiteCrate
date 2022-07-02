//
//  File.swift
//
//
//  Created by Ryan Purpura on 7/3/22.
//

import Foundation
import LiteCrateCore

public protocol ForeignKeyProtocol<S> {
  associatedtype S: DatabaseCodable
  var columnName: String { get }
  func accept<V: ForeignKeyVisitor<S>>(_ visitor: V)
}

public enum OnDelete {
  case cascade
  case setNull
  case setDefault
  case restrict
  case noAction

  var clause: String {
    switch self {
    case .noAction: return "NO ACTION"
    case .restrict: return "RESTRICT"
    case .setNull: return "SET NULL"
    case .setDefault: return "SET DEFAULT"
    case .cascade: return "CASCADE"
    }
  }
}

public struct ForeignKey<S: DatabaseCodable, Destination: DatabaseCodable>: ForeignKeyProtocol {
  public let columnName: String
  public let action: OnDelete
  public let path: (S) -> Destination.Key

  public init(
    _: Destination.Type,
    columnName: String,
    action: OnDelete,
    path: @escaping (S) -> Destination.Key
  ) {
    self.columnName = columnName
    self.action = action
    self.path = path
  }

  internal var creationStatement: String {
    "FOREIGN KEY (\(columnName)) REFERENCES \(Destination.exampleInstance.tableName)(\(Destination.primaryKeyColumn)) ON DELETE \(action.clause)"
  }

  public func accept<V: ForeignKeyVisitor<S>>(_ visitor: V) {
    visitor.visit(self)
  }

  public func typeErase() -> AnyForeignKey<S> {
    ForeignKeyBox(self)
  }
}

// MARK: - Type Erasure

public class AnyForeignKey<S: DatabaseCodable>: ForeignKeyProtocol {
  public var columnName: String { fatalError() }
  init() {}
  public func accept<V>(_: V) where V: ForeignKeyVisitor, S == V.T {
    fatalError("Abstract method.")
  }
}

private class ForeignKeyBox<T: ForeignKeyProtocol>: AnyForeignKey<T.S> {
  typealias S = T.S

  let foreignKey: T

  override public var columnName: String {
    foreignKey.columnName
  }

  init(_ foreignKey: T) {
    self.foreignKey = foreignKey
    super.init()
  }

  override func accept<V: ForeignKeyVisitor<S>>(_ visitor: V) {
    foreignKey.accept(visitor)
  }
}

// MARK: - Constraint Wrapper

public struct FKConstraints<T: DatabaseCodable> {
  public private(set) var constraints: [AnyForeignKey<T>]

  public init() {
    constraints = []
  }

  public init(_ constraints: [AnyForeignKey<T>]) {
    self.constraints = constraints
  }

  public func visit<Visitor: ForeignKeyVisitor<T>>(by visitor: Visitor) {
    for constraint in constraints {
      constraint.accept(visitor)
    }
  }
}

// MARK: - Result Builder

@resultBuilder
public struct ConstraintBuilder<T: DatabaseCodable> {
  public static func buildBlock() -> FKConstraints<T> {
    FKConstraints([])
  }

  public static func buildBlock<D0>(_ c0: ForeignKey<T, D0>) -> FKConstraints<T> {
    FKConstraints<T>([c0.typeErase()])
  }

  public static func buildBlock<D0, D1>(_ c0: ForeignKey<T, D0>,
                                        _ c1: ForeignKey<T, D1>) -> FKConstraints<T>
  {
    FKConstraints<T>([c0.typeErase(), c1.typeErase()])
  }

  public static func buildBlock<D0, D1, D2>(
    _ c0: ForeignKey<T, D0>,
    _ c1: ForeignKey<T, D1>,
    _ c2: ForeignKey<T, D2>
  ) -> FKConstraints<T> {
    FKConstraints<T>([c0.typeErase(), c1.typeErase(), c2.typeErase()])
  }
}

public protocol ForeignKeyVisitor<T> {
  associatedtype T: DatabaseCodable
  func visit<Destination: DatabaseCodable>(_ element: ForeignKey<T, Destination>)
}
