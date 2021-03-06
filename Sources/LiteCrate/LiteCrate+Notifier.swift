//
//  File.swift
//  File
//
//  Created by Ryan Purpura on 7/17/21.
//

import Foundation
import FMDB

extension LiteCrate {
  internal class Notifier {
    private var subscribers = [TableSubscription]()
    
    private var lock = NSLock()
    
    func notify(_ tableName: String) {
      lock.lock()
      defer { lock.unlock() }
      
      for subscriber in subscribers {
        subscriber.action(tableName)
      }
    }
    
    func subscribe(for text: String) -> TableSubscription {
      lock.lock()
      defer { lock.unlock() }
      
      let subscription = TableSubscription(text)
      subscribers.append(subscription)
      return subscription
    }
    
    func unsubscribe(_ subscription: TableSubscription) {
      lock.lock()
      defer { lock.unlock() }
      
      subscribers.removeAll { $0 === subscription }
    }
  }
}
