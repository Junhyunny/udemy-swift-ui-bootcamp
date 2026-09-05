//
//  ContentView.swift
//  chapter-09
//
//  Created by 강준현 on 9/3/26.
//

// TODO: [todos/combine.md](../../todos/combine.md)
internal import Combine
import SwiftUI

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
