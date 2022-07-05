//
//  File.swift
//
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

@resultBuilder
public enum MigrationStepBuilder {
  static func buildBlock(_ migrationActions: any MigrationAction...) -> [any MigrationAction] {
    migrationActions
  }
}

public protocol MigrationStep {
  var asGroup: MigrationGroup { get }
}

public struct MigrationGroup: MigrationStep {
  public let actions: [any MigrationAction]

  init(@MigrationStepBuilder _ actions: @escaping () -> [any MigrationAction]) {
    self.actions = actions()
  }

  public var asGroup: MigrationGroup { self }
}

@resultBuilder
public enum MigrationBuilder {
  static func buildBlock(_ migrationSteps: MigrationStep...) -> Migration {
    Migration(steps: migrationSteps.map(\.asGroup))
  }
}

public struct Migration {
  let steps: [MigrationGroup]

  init(steps: [MigrationGroup]) {
    self.steps = steps
  }
}
