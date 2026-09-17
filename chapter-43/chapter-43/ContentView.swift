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

    // FIXME: [Best Practice] onAppear 마다 눈송이 50개를 더 붙이고 타이머도 새로 만든다.
    // - 문제1: 화면을 다시 들어올 때마다 snowflakes 가 50개씩 누적되고, 기존 timer 를
    //          invalidate 하지 않은 채 새 타이머를 대입해 이전 타이머가 좀비로 남는다.
    // - 문제2: 0.016초마다 @State 배열 전체를 갱신하면 매 프레임 View 트리가 무효화된다.
    //          애니메이션 루프는 Timer 가 아니라 TimelineView(.animation) 안에서
    //          Canvas 가 경과 시간으로 위치를 계산하게 하는 것이 SwiftUI 방식이다.
    // - 개선: snowflakes 가 비었을 때만 생성하고, 타이머 대신 TimelineView 를 사용한다.
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
