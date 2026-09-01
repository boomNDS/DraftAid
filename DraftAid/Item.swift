//
//  Item.swift
//  DraftAid
//
//  Created by Pa Sri on 2/9/2569 BE.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
