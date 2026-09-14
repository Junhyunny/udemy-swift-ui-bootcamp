//
//  ContentView.swift
//  chapter-146
//
//  Created by 강준현 on 9/14/26.
//

import SwiftUI

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
