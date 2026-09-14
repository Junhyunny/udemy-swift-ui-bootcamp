//
//  AnimatedPageIndicator.swift
//  chapter-146
//
//  Created by 강준현 on 9/14/26.
//

import SwiftUI

struct AnimatedPageIndicator: View {
    let totalPages: Int
    let currentIndex: Int
    let indicatorSpacing: CGFloat = 12
    let indicatorHeight: CGFloat = 7
    let activeIndicatorWidth: CGFloat = 20
    let inactiveIndicatorWidth: CGFloat = 7

    var body: some View {
        HStack(spacing: indicatorSpacing) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .foregroundStyle(.white)
                    .frame(
                        width: currentIndex == index
                            ? activeIndicatorWidth : inactiveIndicatorWidth,
                        height: indicatorHeight
                    )
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
    }
}

#Preview {
    AnimatedPageIndicator(
        totalPages: 0,
        currentIndex: 0
    )
}
