//
//  ContentView.swift
//  chapter-21
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            // TODO: [todos/lazy-stack-rendering.md](../../todos/lazy-stack-rendering.md)
            LazyVStack(spacing: 10) {
                ForEach(0..<200, id: \.self) { _ in
                    Text(
                        Date()
                            .formatted(date: .omitted, time: .standard)
                    )
                    .font(.largeTitle)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
