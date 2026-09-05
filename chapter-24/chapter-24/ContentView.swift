//
//  ContentView.swift
//  chapter-24
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    // TODO: [todos/multi-row-grid-composition.md](../../todos/multi-row-grid-composition.md)
    let rows = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows) {
                ForEach(1...100, id: \.self) { idx in
                    Image(systemName: "\(idx).circle.fill")
                        .font(.largeTitle)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
