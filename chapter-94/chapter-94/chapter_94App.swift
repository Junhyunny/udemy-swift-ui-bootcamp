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
        // FIXME: [Architecture] 앱 진입점이 도메인 계산을 직접 수행한다.
        // - 현상: 백그라운드 진입 시각을 기록하고, 복귀 시 경과 시간을 빼서 남은 시간을 재계산하는
        //         로직이 App 구조체의 onChange 클로저 안에 있다.
        // - 문제: App 은 앱 생명주기를 '연결'하는 자리이지 규칙을 '구현'하는 자리가 아니다.
        //         여기 있는 한 이 계산은 테스트할 수 없고, ViewModel 의 상태를 외부에서 직접 주무르는
        //         형태라 캡슐화도 깨진다(viewModel.leftTime, viewModel.selectedTime 을 밖에서 대입).
        // - 개선: TimerViewModel 에 func applicationDidEnterBackground(at: Date) 와
        //         func applicationWillEnterForeground(at: Date) 를 두고 App 은 호출만 한다.
        //         Date 를 인자로 받으면 시간 흐름을 주입할 수 있어 단위 테스트가 가능해진다.
        .onChange(of: scene) { _, newValue in
            // TODO: [todos/simulator-vs-device-behavior.md](../../todos/simulator-vs-device-behavior.md)
            // FIXME: [Best Practice] 백그라운드 복귀 로직 전체를 시뮬레이터에서만 제외하고 있다.
            // - 문제: 시뮬레이터에서는 이 코드가 아예 컴파일되지 않아 검증할 수 없고,
            //         실기기에서만 동작하는 "테스트되지 않는 경로"가 된다.
            // - 개선: 조건부 컴파일 대신 시간 계산 로직을 ViewModel 의 순수 함수로 빼서 단위 테스트한다.
            //         Scene 단계 처리 자체는 양쪽에서 동일하게 실행되게 둔다.
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
