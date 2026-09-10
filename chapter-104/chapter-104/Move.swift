//
//  Move.swift
//  chapter-104
//
//  Created by 강준현 on 9/10/26.
//

import SwiftUI

// TODO, CaseIterable 프로토콜은 뭐야? Iterable 프로토콜이랑 뭐가 다르지?
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
