//
//  GameViewModel.swift
//  chapter-104
//
//  Created by 강준현 on 9/10/26.
//

// TODO, GameKit 모듈에는 어떤 기능이 들어있어? 언제 사용하는 기능이지?
import GameKit
import Observation
import SwiftUI

@Observable
final class GameViewModel {
    var playerMove: Move?
    var opponentMove: Move?

    var result: String = ""
    var playScore: Int = 0
    var opponentScore: Int = 0

    private let aiOpponent = GKRandomDistribution(
        lowestValue: 0,
        highestValue: 2
    )

    func play(_ move: Move) {
        playerMove = move
        opponentMove = getAIOpponentMove()
        result = determinewinner(playerMove: move, opponentMove: opponentMove!)
        updateScore()
    }

    func getAIOpponentMove() -> Move {
        let randomIndex = aiOpponent.nextInt()
        return Move.allCases[randomIndex]
    }

    func determinewinner(playerMove: Move, opponentMove: Move) -> String {
        if playerMove == opponentMove {
            return "It is a Tie"
        } else if playerMove.beats(opponentMove) {
            return "You Win"
        } else {
            return "You Lose"
        }
    }

    func updateScore() {
        if result == "You Win" {
            playScore += 1
        } else if result == "You Lose" {
            opponentScore += 1
        }
    }

    func resetGame() {
        playerMove = nil
        opponentMove = nil
        result = ""
    }
}
