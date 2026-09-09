//
//  chapter_94App.swift
//  chapter-94
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

@main
struct chapter_94App: App {

    @StateObject var viewModel = TimerViewModel()
    // TODO: [todos/environment-property-wrapper.md](../../todos/environment-property-wrapper.md)
    @Environment(\.scenePhase) var scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                // TODO: [todos/state-wrapper-decision-guide.md](../../todos/state-wrapper-decision-guide.md)
                // TODO: [todos/dependency-injection-for-testing.md](../../todos/dependency-injection-for-testing.md)
                .environmentObject(viewModel)
        }
        .onChange(of: scene) { _, newValue in
            // TODO: [todos/simulator-vs-device-behavior.md](../../todos/simulator-vs-device-behavior.md)
            #if !targetEnvironment(simulator)
                if newValue == .background {
                    viewModel.leftTime = Date()
                    print("App entered background")
                }
                if newValue == .active && viewModel.leftTime != nil {
                    let diffInTime = Date().timeIntervalSince(
                        viewModel.leftTime
                    )
                    let currentTime = viewModel.selectedTime - Int(diffInTime)
                    print("Diff in time", diffInTime)
                    print("Current time", currentTime)
                    if currentTime >= 0 {
                        withAnimation(.default) {
                            viewModel.selectedTime = currentTime
                        }
                    } else {
                        viewModel.resetView()
                    }
                }
            #endif
        }
    }
}
