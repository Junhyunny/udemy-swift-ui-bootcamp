//
//  TextCountdownModifier.swift
//  chapter-94
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct TextCountdownModifier: ViewModifier {
    @Binding var progrss: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + (0.3 * progrss))
            .opacity(0.5 + (0.5 + progrss))
            .foregroundStyle(progrss < 0.3 ? .red : .white)
            .rotationEffect(.degrees((1 - progrss) * 360))
            .animation(.spring(duration: 0.5), value: progrss)
    }
}

// TODO 어떤 함수들은 extension을 통해 확장하고 어떤 객체들은 그냥 클래스, struct 마다 함수를 지정하는데 그 이유가 있음? 명확한 기준이 있다면 이를 찾아서 정리해줘
extension View {
    func countdownStyle(_ progress: Binding<CGFloat>) -> some View {
        self.modifier(TextCountdownModifier(progrss: progress))
    }
}
