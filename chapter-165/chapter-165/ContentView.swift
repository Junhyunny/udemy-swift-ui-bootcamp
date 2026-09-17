//
//  ContentView.swift
//  chapter-165
//
//  Created by 강준현 on 9/16/26.
//

import SwiftUI

struct StarRatingView: View {
    var rating: Double
    @State private var animatedRating: Double = 0.0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                starView(for: index)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedRating = rating
            }
        }
        // FIXME: [Best Practice] newRating 을 받아놓고 클로저 안에서는 rating 을 다시 읽는다.
        // - 문제: 지금은 값이 같아 동작하지만, onChange 의 계약(새 값은 파라미터로 받는다)을 어긴다.
        //         읽지 않는 파라미터가 남아 의도가 모호해진다.
        // - 개선: animatedRating = newRating 으로 파라미터를 사용한다.
        .onChange(of: rating) { _, newRating in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedRating = rating
            }
        }
    }

    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let fillAmount = min(max(animatedRating - Double(index), 0), 1)

        ZStack {
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.gray.gradient.opacity(0.5))
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                // TODO: [todos/mask-and-alpha-channel.md](../../todos/mask-and-alpha-channel.md)
                .mask {
                    GeometryReader { geometry in
                        Rectangle()
                            .frame(width: geometry.size.width * fillAmount)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
        }
        .frame(width: 30, height: 30)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            StarRatingView(rating: 4.7)
            StarRatingView(rating: 3.5)
            StarRatingView(rating: 2.2)
            StarRatingView(rating: 1)
            StarRatingView(rating: 2.9)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
