//
//  ContentView.swift
//  chapter-104
//
//  Created by 강준현 on 9/10/26.
//

import SwiftUI

struct ContentView: View {

    @State private var viewModel = GameViewModel()
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Rock Papager Scissors")
                .font(.largeTitle)
                .padding()

            HStack {
                Text("Player: \(viewModel.playScore)")
                Spacer()
                Text("AI: \(viewModel.opponentScore)")
            }
            .padding()

            if let playerMove = viewModel.playerMove,
                let opponentMove = viewModel.opponentMove
            {
                VStack {
                    Text("You choose: \(playerMove.rawValue)")
                        .font(.title)
                        // TODO: [todos/swiftui-transition-composition.md](../../todos/swiftui-transition-composition.md)
                        .transition(.scale.combined(with: .opacity))
                    Text("Opponent choose: \(opponentMove.rawValue)")
                        .font(.title)
                        .transition(.scale.combined(with: .opacity))
                    Text(viewModel.result)
                        .font(.title)
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                    Button("Play again") {
                        withAnimation(
                            .spring(
                                response: 0.6,
                                dampingFraction: 0.8,
                                blendDuration: 0
                            )
                        ) {
                            viewModel.resetGame()
                        }
                    }
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 20))
                    .shadow(radius: 10)
                    // TODO: [todos/swiftui-transition-composition.md](../../todos/swiftui-transition-composition.md)
                    .transition(
                        .move(edge: .bottom).combined(with: .opacity)
                    )
                }
            } else {
                ForEach(Move.allCases, id: \.self) { move in
                    Button(action: {
                        withAnimation(.easeIn(duration: 0.5)) {
                            viewModel.play(move)
                        }
                    }) {
                        Text(move.rawValue)
                            .font(.system(size: 50))
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(.rect(cornerRadius: 10))
                            .scaleEffect(isAnimating ? 1.2 : 1)
                            .animation(
                                Animation.easeIn(duration: 0.5)
                                    .repeatCount(3, autoreverses: true),
                                value: isAnimating
                            )
                    }
                    .padding()
                    .onAppear {
                        isAnimating = true
                    }
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

#Preview {
    ContentView()
}
