//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrate

public protocol ReplicatingModel: DatabaseCodable<UUID>, Identifiable {
  var dot: Dot { get set }
}


// MARK: - Type Erasure
public class AnyReplicatingModel: ReplicatingModel {
  fileprivate init() {}
  
  var dot: Dot {
    fatalError("Abstract")
  }
  
  func decodeWithSameType(container: KeyedDecodingContainer<TableNameCodingKey>) throws -> [AnyReplicatingModel] {
    fatalError("Abstract")
  }
  
  func fetchWithSameType(_ proxy: LiteCrate.TransactionProxy, allWhere: String? = nil, _ values: [SqliteRepresentable]) {
    fatalError("Abstract")
  }
}

fileprivate class AnyReplicatingModelBox<T: ReplicatingModel>: AnyReplicatingModelBase {
  private var model: T
  
  init<T: ReplicatingModel>(_ model: T) {
    self.model = model
  }
  
  var dot: Dot { model.dot }
  
  static var tableName: String { model.tableName }
  
  func decodeWithSameType(container: KeyedDecodingContainer<TableNameCodingKey>) throws -> [AnyReplicatingModel] {
    try container.decode([T].self, forKey: .init(stringValue: instance.tableName))
      .map { $0.typeErase() }
  }
  
  func encode(to encoder: Encoder) {
    model.encode(to: encoder)
  }
  
  func fetchWithSameType(_ proxy: LiteCrate.TransactionProxy, allWhere whereClause: String? = nil, _ values: [SqliteRepresentable]) -> [AnyReplicatingModel] {
    try! proxy.fetch(T.self, allWhere: whereClause, values)
      .map { $0.typeErase() }
  }
}

public extension ReplicatingModel {
  func typeErase() -> AnyReplicatingModel {
    return AnyReplicatingModelBox(self)
  }
}

extension LiteCrate.TransactionProxy {
  func fetch(withSameTypeAs model: AnyReplicatingModel, allWhere whereClause: String? = nil, _ values: [SqliteRepresentable]) -> AnyReplicatingModel {
  }
  
  func fetch(withSameTypeAs model: AnyReplicatingModel, allWhere whereClause: String? = nil, _ values: [SqliteRepresentable]) -> AnyReplicatingModel {
  }
}
