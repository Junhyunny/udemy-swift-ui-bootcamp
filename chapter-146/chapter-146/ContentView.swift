//
//  ContentView.swift
//  chapter-146
//
//  Created by 강준현 on 9/14/26.
//

import SwiftUI

// FIXME: [Architecture] 온보딩 노출 여부를 결정할 곳이 없어 View 가 임시로 떠맡고 있다.
// - 현상: onAppear 에서 무조건 true 로 만들어 시트를 띄우고, 완료 콜백에는
//         "set user defaults to not show the flow again" 이라는 주석만 남아 있다.
//         즉 '한 번만 보여준다'는 규칙의 구현체가 아직 없다.
// - 문제: 나중에 UserDefaults 를 View 안에서 직접 읽고 쓰기 시작하면 영속성 접근이
//         화면 곳곳에 흩어진다. 테스트도 전역 UserDefaults 에 의존하게 된다.
// - 개선: @AppStorage("hasSeenOnboarding") 로 간단히 처리하거나,
//         규칙이 더 생길 여지가 있다면 protocol OnboardingStateStore 를 두고 주입한다.
//         노출 판단은 onAppear 가 아니라 상태의 초기값으로 표현하는 편이 깜빡임도 없다.
struct ContentView: View {
    @State private var presentOnboardingFlow: Bool = false
    var body: some View {
        HomeView()
            .sheet(isPresented: $presentOnboardingFlow) {
                OnboardingView(steps: OnboardingStep.sampleSteps) {
                    presentOnboardingFlow = false
                    // set user defaults to not show the flow again
                }
                .interactiveDismissDisabled(true)
            }
            .onAppear {
                presentOnboardingFlow = true
            }
    }
}

#Preview {
    ContentView()
}
