//
//  ContentView.swift
//  chapter-35
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var randomData = Array(0..<5)
    var body: some View {
        NavigationStack {
            List {
                ForEach(randomData, id: \.self) { item in
                    Text("Item \(item + 1)")
                }
            }
            .navigationTitle("Random List")
            .refreshable {
                await fetchData()
            }
        }
    }
    
    // TODO: [todos/swift-async-await-model.md](../../todos/swift-async-await-model.md)
    private func fetchData() async {
        // TODO: [todos/swift-error-handling-forms.md](../../todos/swift-error-handling-forms.md)
        // try? await Task.sleep(for: .seconds(2))
        do {
            let (_, _) = try await URLSession.shared.data(
                from: URL(string: "https://httpbin.org/delay/5")!
            )
            randomData.append(Int.random(in: 10...10000))
        } catch {
            print("error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
