//
//  OnboardingStepView.swift
//  chapter-146
//
//  Created by 강준현 on 9/14/26.
//

import SwiftUI

struct OnboardingStepView: View {
    let step: OnboardingStep
    let screenSize: CGSize
    var body: some View {
        VStack(spacing: 22) {
            Image(step.imageName)
                .resizable()
                .frame(height: screenSize.height / 3)
                .clipShape(.rect(cornerRadius: 20))
                .accessibilityLabel("Onboarding Illustration")
            VStack(alignment: .leading, spacing: 16) {
                Text(step.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text(step.description)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .frame(width: screenSize.width)
    }
}

#Preview {
    OnboardingStepView(
        step: .init(
            imageName: "food1",
            title: "hello",
            description: "world",
            accentColor: .black
        ),
        screenSize: CGSize(width: 400, height: 900)
    )
}
