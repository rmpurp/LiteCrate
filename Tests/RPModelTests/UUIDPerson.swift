//
//  UUIDPerson.swift
//
//
//  Created by Ryan Purpura on 12/5/20.
//

import Foundation
import RPModel

struct UUIDPerson: RPModel {
  @Column var id: Int64?
  @Column var specialID: UUID
  @Column var optionalID: UUID?
}
