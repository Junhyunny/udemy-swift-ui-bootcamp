//
//  ContentView.swift
//  chapter-33
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // TODO: [todos/closures-and-view-builders.md](../../todos/closures-and-view-builders.md)
        ScrollView {
            VStack(spacing: 15) {
                Text("junhyunny.github.io")
                    .font(.largeTitle)
                ForEach(0..<30) { idx in
                    Text("item \(idx)")
                        .padding()
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(
                            .mint.opacity(0.2),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    ContentView()
}
