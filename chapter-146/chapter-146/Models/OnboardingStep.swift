//
//  OnboardingStep.swift
//  chapter-146
//
//  Created by 강준현 on 9/14/26.
//

import Foundation
import SwiftUI

struct OnboardingStep: Identifiable, Equatable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
    let accentColor: Color

    static func == (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.id == rhs.id
    }
}

extension OnboardingStep {
    static var sampleSteps: [OnboardingStep] {
        [
            .init(
                imageName: "food1",
                title: "Welcome",
                description: "Welcome to the app",
                accentColor: .blue
            ),
            .init(
                imageName: "food2",
                title: "Features",
                description: "Discover new features",
                accentColor: .yellow
            ),
            .init(
                imageName: "food3",
                title: "Fast & Reliable Delivery",
                description:
                    "Your food is prepared with care and delivered quickly to your doorstep.",
                accentColor: .pink
            ),
        ]
    }

}
