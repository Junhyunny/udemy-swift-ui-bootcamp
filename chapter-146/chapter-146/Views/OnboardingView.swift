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
        // TODO: [todos/046-state-property-wrapper-backing-storage.md](../../../todos/046-state-property-wrapper-backing-storage.md)
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
            // FIXME: [Best Practice] Skip 은 dismiss() 만 호출하고 onComplete 를 부르지 않는다.
            // - 문제: 호출부(ContentView)가 "온보딩을 다시 보여주지 않음"을 기록하는 지점이 onComplete 인데,
            //         Skip 경로만 그 기록을 건너뛴다. 앱을 다시 켜면 온보딩이 또 뜬다.
            // - 개선: 완료 처리(viewModel.completeOnboarding)를 거쳐 한 경로로 모은다.
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
            // TODO: [todos/081-scroll-position-binding.md](../../../todos/081-scroll-position-binding.md)
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
