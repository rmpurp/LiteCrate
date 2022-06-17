//
//  File.swift
//  
//
//  Created by Ryan Purpura on 6/12/22.
//

import Foundation

@resultBuilder
struct MigrationStepBuilder {
  static func buildBlock(_ migrationActions: any MigrationAction...) -> [any MigrationAction] {
    migrationActions
  }
}

public struct MigrationStep {
  let actions: [any MigrationAction]

  init(@MigrationStepBuilder _ actions: @escaping () -> [any MigrationAction]) {
    self.actions = actions()
  }
}

@resultBuilder
struct MigrationBuilder {
  static func buildBlock(_ migrationSteps: MigrationStep...) -> Migration {
    Migration(steps: migrationSteps)
  }
}

public struct Migration {
  let steps: [MigrationStep]

  init(steps: [MigrationStep]) {
    self.steps = steps
  }
}
