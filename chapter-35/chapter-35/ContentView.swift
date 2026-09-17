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
    
    // TODO: [todos/101-swift-async-await-model.md](../../todos/101-swift-async-await-model.md)
    private func fetchData() async {
        // TODO: [todos/100-swift-error-handling-forms.md](../../todos/100-swift-error-handling-forms.md)
        // try? await Task.sleep(for: .seconds(2))
        do {
            let (_, _) = try await URLSession.shared.data(
                // FIXME: [Best Practice] URL 강제 언래핑(!)은 문자열 오타 하나로 앱을 크래시시킨다.
                // - 개선: guard let url = URL(string: ...) else { return } 로 풀거나,
                //         iOS 16+ 의 URL(string:encodingInvalidCharacters:) / 상수 URL 을 별도 enum 에 모아둔다.
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
