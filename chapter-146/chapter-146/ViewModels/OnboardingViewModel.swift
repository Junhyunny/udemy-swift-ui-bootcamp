//
//  OnboardingViewModel.swift
//  chapter-146
//
//  Created by 강준현 on 9/14/26.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    var currentIndex: Int? = 0
    // FIXME: [Architecture] 레이아웃 수치가 ViewModel 상태로 올라와 있다.
    // - 현상: GeometryReader 가 측정한 크기를 updateScreenSize 로 ViewModel 에 밀어 넣고,
    //         OnboardingStepView 는 다시 viewModel.screenSize 를 받아 이미지 높이를 계산한다.
    // - 문제: 화면 크기는 SwiftUI 레이아웃 시스템이 이미 알고 있는 값이다. 이를 상태로 복제하면
    //         회전/분할화면에서 한 프레임 늦게 반영되고, 크기 변경이 ViewModel 변경으로 번져
    //         관련 없는 뷰까지 다시 그려진다.
    // - 개선: screenSize 를 제거하고 자식 뷰가 .containerRelativeFrame 이나 자체 GeometryReader,
    //         혹은 maxWidth/aspectRatio 로 스스로 크기를 정하게 한다.
    //         ViewModel 에는 currentIndex 같은 '화면에 독립적인 상태'만 남긴다.
    var screenSize: CGSize = .zero
    let steps: [OnboardingStep]
    private let onboadingCompletion: () -> Void

    init(steps: [OnboardingStep], onComplete: @escaping () -> Void = {}) {
        self.steps = steps
        self.onboadingCompletion = onComplete
    }

    var isLastStep: Bool {
        guard let currentIndex = currentIndex else { return false }
        return currentIndex >= steps.count - 1
    }

    // FIXME: [Best Practice] steps 가 비면 steps.first! 에서 크래시한다.
    // - 문제: 바로 아래 #Preview 의 OnboardingView(steps: []) 가 정확히 이 경로를 밟는다.
    //         "비어 있을 수 없다"는 가정을 강제 언래핑으로 표현하면 컴파일러가 도와주지 못한다.
    // - 개선: currentStep 을 OnboardingStep? 로 만들어 호출부에서 처리하거나,
    //         init 에서 guard !steps.isEmpty 로 빈 배열을 애초에 막는다(비어 있지 않음을 타입으로 보장).
    var currentStep: OnboardingStep {
        guard let currentIndex = currentIndex else {
            return steps.first!
        }
        return steps[safe: currentIndex] ?? steps.first!
    }

    func updateScreenSize(_ size: CGSize) {
        self.screenSize = size
    }

    // FIXME: [Best Practice] 디버깅용 print 가 제품 코드에 남아 있다(이 파일에만 4곳).
    // - 문제: print 는 릴리스 빌드에서도 실행되어 콘솔을 오염시키고 성능을 깎는다.
    //         개인정보가 섞이면 로그 유출 경로가 된다.
    // - 개선: 제거하거나 os.Logger 로 교체한다. -> Logger(subsystem:category:).debug("...")
    func updateCurrentIndex(_ index: Int) {
        guard index >= 0 && index < steps.count else { return }
        if index != currentIndex {
            print("updateCurrentIndex ? \(currentIndex) -> \(index)")
            currentIndex = index
        }
    }

    func navigateToNext() {
        guard !isLastStep else {
            completeOnboarding()
            return
        }
        print("currentIndex \(currentIndex)")
        let current = currentIndex ?? 0
        let nextIndex = min(current + 1, steps.count - 1)
        print("nextIndex \(nextIndex)")
        withAnimation(.easeInOut(duration: 0.3)) {
            print("change it from \(currentIndex) to \(nextIndex)")
            currentIndex = nextIndex
        }
    }

    private func completeOnboarding() {
        onboadingCompletion()
    }
}

// FIXME: [Best Practice] 범용 Array 확장이 특정 ViewModel 파일 안에 숨어 있다.
// - 문제: 모듈 전체에 노출되는 API 인데 찾을 수 없는 위치에 있어 중복 정의를 부른다.
// - 개선: Extensions/Array+Safe.swift 같은 전용 파일로 분리한다.
//         (chapter-80 의 URL+Extensions.swift 처럼 파일 이름 규칙을 맞춘다)
extension Array {
    // TODO: [todos/013-subscript-keyword.md](../../../todos/013-subscript-keyword.md)
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
