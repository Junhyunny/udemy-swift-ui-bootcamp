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

    var currentStep: OnboardingStep {
        guard let currentIndex = currentIndex else {
            return steps.first!
        }
        return steps[safe: currentIndex] ?? steps.first!
    }

    func updateScreenSize(_ size: CGSize) {
        self.screenSize = size
    }

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

extension Array {
    // TODO: [todos/subscript-keyword.md](../../../todos/subscript-keyword.md)
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
