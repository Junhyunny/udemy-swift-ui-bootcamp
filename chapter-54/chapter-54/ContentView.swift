//
//  ContentView.swift
//  chapter-54
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Image(systemName: "clock.fill")
                    .resizable()
                    .foregroundStyle(.orange.gradient)
                    .frame(width: 200, height: 200)
                VStack(spacing: 0) {
                    Rectangle()
                        .frame(width: 1, height: 150)
                    Circle()
                        .fill(.brown.gradient)
                        .frame(height: 25)
                }
                // TODO: [todos/animation-api-comparison.md](../../todos/animation-api-comparison.md)
                .phaseAnimator([45.0, -45.0]) { view, phase in
                    view.rotationEffect(
                        .degrees(phase),
                        anchor: .top
                    )
                } animation: { phase in
                    switch phase {
                    case -45.0:
                        return .snappy
                    default:
                        return .spring(dampingFraction: 0.1)
                    }
                    // .easeInOut.speed(0.5)
                }
            }
            .padding(25)
            .background(
                .indigo.gradient,
                in: RoundedRectangle(cornerRadius: 10).stroke(lineWidth: 4)
            )
        }
        .navigationTitle("Junhyunny Example")
    }
}

#Preview {
    ContentView()
}
