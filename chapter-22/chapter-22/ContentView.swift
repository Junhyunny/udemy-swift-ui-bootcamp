//
//  ContentView.swift
//  chapter-22
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(0...200, id: \.self) { _ in
                    Text(
                        Date().formatted(date: .omitted, time: .standard)
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
