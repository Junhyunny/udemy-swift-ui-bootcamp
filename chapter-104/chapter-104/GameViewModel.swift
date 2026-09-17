//
//  GameViewModel.swift
//  chapter-104
//
//  Created by 강준현 on 9/10/26.
//

// TODO: [todos/gamekit-and-gameplaykit.md](../../todos/gamekit-and-gameplaykit.md)
import GameKit
import Observation
import SwiftUI

// FIXME: [Architecture] 난수 생성기를 구체 타입으로 직접 들고 있어 게임 로직을 테스트할 수 없다.
// - 현상: private let aiOpponent = GKRandomDistribution(...) 를 프로퍼티로 고정했다.
// - 문제: '가위바위보 승패 판정'은 순수 함수인데, 상대 수가 무작위라 결과를 예측할 수 없어
//         determineWinner/updateScore 를 검증하는 테스트를 쓸 수 없다.
//         GameplayKit 프레임워크 의존도 ViewModel 에 새어 들어왔다.
// - 개선: protocol MoveProviding { func nextMove() -> Move } 를 두고
//         init(opponent: MoveProviding = RandomMoveProvider()) 로 주입한다.
//         테스트에서는 항상 .rock 을 돌려주는 대역을 넣어 모든 분기를 검증할 수 있다.
// - 구조: 이 프로젝트는 파일이 전부 루트에 평평하게 놓여 있다.
//         Models/(Move) ViewModels/(GameViewModel) Views/(ContentView) 로 나누면
//         chapter-80, chapter-146 과 구조가 통일된다.
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
        // FIXME: [Best Practice] 방금 대입한 옵셔널을 다시 강제 언래핑(!)하고 있다.
        // - 개선: let opponent = getAIOpponentMove(); opponentMove = opponent 처럼
        //         비옵셔널 지역 상수를 만들어 넘긴다. 함수명 오타(determinewinner -> determineWinner)도 함께 고친다.
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

    // FIXME: [Best Practice] 승패를 화면 표시용 문자열("You Win")로 비교하고 있다.
    // - 문제: 문구를 다듬거나 다국어를 붙이는 순간 점수 계산이 조용히 망가진다.
    //         도메인 로직이 UI 문자열에 묶여 테스트도 어렵다.
    // - 개선: enum GameResult { case win, lose, tie } 를 만들어 상태로 보관하고,
    //         화면에는 result.description 같은 표현 계층을 따로 둔다.
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
