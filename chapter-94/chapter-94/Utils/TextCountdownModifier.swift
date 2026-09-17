//
//  TextCountdownModifier.swift
//  chapter-94
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct TextCountdownModifier: ViewModifier {
    // FIXME: [Best Practice] 프로퍼티 이름 오타(progrss -> progress)가 공개 API 로 굳어졌다.
    // - 추가 버그: 아래 .opacity(0.5 + (0.5 + progrss)) 는 progress 가 0 일 때도 1.0 이라
    //            페이드 효과가 전혀 나지 않는다. 의도한 식은 0.5 + (0.5 * progrss) 로 보인다.
    // - 개선: 이름을 progress 로 고치고 곱셈 연산자로 바로잡는다.
    //         또 이 modifier 는 값을 읽기만 하므로 @Binding 이 필요 없다. 그냥 let progress: CGFloat 로 충분하다.
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
