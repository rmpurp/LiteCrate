//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/28/22.
//

import Foundation

protocol ChildReplicatingModel: ReplicatingModel {
  var parentDot: ForeignKeyDot { get set }
}
