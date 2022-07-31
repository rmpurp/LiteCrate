//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation
import LiteCrateCore

public protocol DatabaseCodable: Codable {
  static var table: Table { get }
}
