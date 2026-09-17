//
//  ContentView.swift
//  chapter-09
//
//  Created by 강준현 on 9/3/26.
//

// TODO: [todos/111-combine.md](../../todos/111-combine.md)
internal import Combine
import SwiftUI

// FIXME: [Best Practice] 시작만 있고 멈추는 경로가 없어 Timer 가 영원히 살아남는다.
// - 문제: stop()/invalidate() 가 없어 View 가 사라져도 RunLoop 가 계속 타이머를 잡고 있고,
//         ViewModel 도 함께 해제되지 않아 배터리와 메모리를 낭비한다.
// - 개선: stop() 을 추가해 timer?.invalidate(); timer = nil 을 호출하고 deinit 에서도 정리한다.
//         View 에서는 .onDisappear { vm.stop() } 로 생명주기를 맞춘다.
// - 대안: iOS 17+ 라면 ObservableObject/@Published 대신 @Observable 매크로를 쓰고,
//         Timer 대신 .task { for await _ in Timer.publish(...).values } 형태가 더 안전하다.
final class StopWatchViewModel: ObservableObject {
    @Published var elapsedTime = 0
    var timer: Timer?
    func start() {
        if timer != nil {
            return
        }
        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true,
            block: { [weak self] _ in
                self?.elapsedTime += 1
            }
        )
    }
}

struct ContentView: View {
    @StateObject private var vm = StopWatchViewModel()
    var body: some View {
        VStack {
            Text("elapsed time: \(vm.elapsedTime)")
            Button("Start") {
                vm.start()
            }
        }
    }
}

#Preview {
    ContentView()
}
