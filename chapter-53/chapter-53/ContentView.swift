//
//  ContentView.swift
//  chapter-53
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    @State private var animate = false

    var body: some View {
        NavigationStack {
            VStack {
                Circle()
                    .fill(.red.gradient)
                Circle()
                    .fill(.orange.gradient)
                Circle()
                    .fill(.green.gradient)
            }
            // .scaleEffect(animate ? 1.0 : 0.5)
            .navigationTitle("Junhyunny's Example")
            .onTapGesture {
                animate.toggle()
            }
            // TODO: [todos/phase-animator-parameters-and-phase-types.md](../../todos/phase-animator-parameters-and-phase-types.md)
            .phaseAnimator(
                [1.0, 0.5],
                trigger: animate,
                content: { view, phase in
                    view
                        .scaleEffect(phase)
                        .opacity(phase)
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
