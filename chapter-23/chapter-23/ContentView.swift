//
//  ContentView.swift
//  chapter-23
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    // TODO: [todos/grid-item-sizing.md](../../todos/grid-item-sizing.md)
    // .flexible
    // .adaptive
    // .fixed
    let columns = [
        GridItem(.adaptive(minimum: 50)),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(0...100, id: \.self) { idx in
                    Image(systemName: "\(idx).circle.fill")
                        .font(.largeTitle)
                        .background(.orange)
                        .padding()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
