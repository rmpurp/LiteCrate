//
//  Logger.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation

func lc_log(_ format: String, _ args: CVarArg...) {
#if DEBUG
  NSLog("LiteCrate: " + format, args)
#endif
}
