//
//  File.swift
//  
//
//  Created by Ryan Purpura on 10/16/22.
//

import Foundation

protocol Entity: Codable {
  var id: UUID { get }
}
