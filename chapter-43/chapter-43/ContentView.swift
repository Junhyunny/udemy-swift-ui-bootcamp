//
//  ContentView.swift
//  chapter-43
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

// TODO: [todos/swift-fundamental-types-and-comparison.md](../../todos/swift-fundamental-types-and-comparison.md)
struct Snowflake: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var scale: Double
    var speed: Double
}

struct ContentView: View {
    @State var snowflakes: [Snowflake] = []
    @State var timer: Timer?
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(
                    colors: [.blue, .indigo]
                ),
                startPoint: .top,
                endPoint: .bottom

            )
            .ignoresSafeArea()
            Canvas { context, size in
                for snowflake in snowflakes {
                    context.draw(
                        Text("❄️")
                            .font(.system(size: 10 * snowflake.scale)),
                        at: CGPoint(
                            x: snowflake.x * size.width,
                            y: snowflake.y * size.height
                        ),
                    )
                }
            }
            .ignoresSafeArea()

            Text("Junhyunny")
                .font(.custom("Noteworthy", size: 70))
                .foregroundStyle(.white)
        }
        .onAppear(perform: startSnowfall)
        .onDisappear {
            timer?.invalidate()
        }
    }

    func startSnowfall() {
        for _ in 0..<50 {
            snowflakes.append(
                Snowflake(
                    // TODO: [todos/canvas-coordinate-space-and-normalization.md](../../todos/canvas-coordinate-space-and-normalization.md)
                    x: .random(in: 0...1),
                    y: .random(in: -0.2...0),
                    scale: .random(in: 0.5...1.5),
                    speed: .random(in: 0.001...0.003)
                )
            )
        }
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.016,
            repeats: true,
            block: { _ in
                for i in snowflakes.indices {
                    snowflakes[i].y += snowflakes[i].speed
                    // TODO: [todos/canvas-coordinate-space-and-normalization.md](../../todos/canvas-coordinate-space-and-normalization.md)
                    if snowflakes[i].y > 1.2 {
                        snowflakes[i].y = -0.2
                        snowflakes[i].x = Double.random(in: 0...1)
                    }
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
