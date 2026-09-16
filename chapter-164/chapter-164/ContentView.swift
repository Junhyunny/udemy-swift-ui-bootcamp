//
//  ContentView.swift
//  chapter-164
//
//  Created by 강준현 on 9/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var expand = false

    var body: some View {
        NavigationStack {
            VStack {
                CircleShape(
                    radius: expand ? 50 : 10,
                    startAngle: expand ? 180 : 0,
                    endAngle: expand ? 360 : 180,
                    isClockWise: true
                )
                .stroke(.blue.gradient, lineWidth: 20)
                // .scaleEffect(expand ? 5 : 1)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeIn) {
                        expand.toggle()
                    }
                }
            }
            .navigationTitle("DevTehcie.com")
        }
    }
}

#Preview {
    ContentView()
}

// TODO: [todos/animatable-macro.md](../../todos/animatable-macro.md)
@Animatable
@MainActor
struct CircleShape: Shape {
    var radius: CGFloat
    var startAngle: Double
    var endAngle: Double
    // TODO: [todos/animatable-macro.md](../../todos/animatable-macro.md)
    @AnimatableIgnored
    var isClockWise: Bool // Boolean은 인터폴레이트 애니메이션 처리가 안된다.

    // TODO: [todos/animatable-data-and-interpolation.md](../../todos/animatable-data-and-interpolation.md)
    // var animatableData: CGFloat {
    //     get { radius }
    //     set { radius = newValue }
    // }

    // var animatableData: AnimatablePair<CGFloat, Double> {
    //     get { AnimatablePair(radius, startAngle) }
    //     set {
    //         radius = newValue.first
    //         startAngle = newValue.second
    //     }
    // }

    // TODO: [todos/nonisolated-keyword.md](../../todos/nonisolated-keyword.md)
    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(
                center: .init(x: rect.midX, y: rect.midY),
                radius: radius,
                startAngle: .init(degrees: startAngle),
                endAngle: .init(degrees: endAngle),
                clockwise: isClockWise
            )
        }
    }
}
