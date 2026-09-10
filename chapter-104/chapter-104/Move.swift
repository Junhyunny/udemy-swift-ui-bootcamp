//
//  Move.swift
//  chapter-104
//
//  Created by 강준현 on 9/10/26.
//

import SwiftUI

// TODO: [todos/caseiterable-and-sequence.md](../../todos/caseiterable-and-sequence.md)
enum Move: String, CaseIterable {
    case rock = "🪨"
    case paper = "📝"
    case scissors = "✂️"

    func beats(_ move: Move) -> Bool {
        switch self {
        case .rock:
            return move == .scissors
        case .paper:
            return move == .rock
        case .scissors:
            return move == .paper
        }
    }
}
