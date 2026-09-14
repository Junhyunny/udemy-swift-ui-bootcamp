//
//  OnboardingView.swift
//  chapter-146
//
//  Created by 강준현 on 9/14/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    init(steps: [OnboardingStep], onComplete: @escaping () -> Void = {}) {
        // TODO: [todos/state-property-wrapper-backing-storage.md](../../../todos/state-property-wrapper-backing-storage.md)
        self._viewModel = State(
            wrappedValue: .init(steps: steps, onComplete: onComplete)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerView
                contentScrollView
                bottomNavigationView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .onAppear {
                viewModel.updateScreenSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newValue in
                viewModel.updateScreenSize(newValue)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerView: some View {
        HStack {
            Spacer()
            Button("Skip") {
                dismiss()
            }
            .foregroundStyle(.white)
            .font(.body.weight(.medium))
            .padding()
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var contentScrollView: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) {
                    index,
                    step in
                    OnboardingStepView(
                        step: step,
                        screenSize: viewModel.screenSize
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $viewModel.currentIndex)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollDisabled(false)
        .onScrollTargetVisibilityChange(idType: Int.self) { visibleIds in
            print("currentIndex \(viewModel.currentIndex)")
            // TODO: [todos/scroll-position-binding.md](../../../todos/scroll-position-binding.md)
            //            if let lastVisibleId = visibleIds.last {
            //                viewModel.updateCurrentIndex(lastVisibleId)
            //            }
        }
    }

    private var bottomNavigationView: some View {
        HStack(alignment: .bottom, spacing: 24) {
            AnimatedPageIndicator(
                totalPages: viewModel.steps.count,
                currentIndex: viewModel.currentIndex ?? 0
            )
            Spacer()
            OnboardingNavigationButton(
                action: viewModel.navigateToNext,
                backgroundColor: viewModel.currentStep.accentColor,
                iconName: viewModel.isLastStep ? "checkmark" : "chevron.right",
                accessibilityLabel: viewModel.isLastStep
                    ? "Complete onboarding" : "Next step"
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    OnboardingView(steps: [], onComplete: {})
}
