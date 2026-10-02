//
//  Item.swift
//  StickerShelf
//
//  Created by Kei on 2026/10/02.
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
