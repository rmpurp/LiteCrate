//
//  File.swift
//
//
//  Created by Ryan Purpura on 7/31/22.
//

import Foundation

public protocol ReplicatingModel: Codable, Identifiable where ID == UUID {
  static var table: Table { get }
}
