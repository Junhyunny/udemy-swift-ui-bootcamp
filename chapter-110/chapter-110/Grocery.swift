//
//  Grocery.swift
//  chapter-110
//
//  Created by 강준현 on 9/10/26.
//

import Foundation
import SwiftData

// TODO: [todos/swiftdata-model-class-and-final.md](../../todos/swiftdata-model-class-and-final.md)
@Model
final class Grocery {
    var name: String
    var desc: String

    init(name: String, desc: String) {
        self.name = name
        self.desc = desc
    }
}
