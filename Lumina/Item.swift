//
//  Item.swift
//  Lumina
//
//  Created by Andrii Shafar on 03.06.2026.
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
