//
//  ContentView.swift
//  chapter-161
//
//  Created by 강준현 on 9/16/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Group {
                Text("Hello, world!")
                    .font(.largeTitle)
                    .padding()
                Text("Hello, world!")
                    .font(.largeTitle)
                    .padding()
            }
            // .background(
            //     .black.opacity(0.4),
            //     in: .capsule
            // )
            // .glassEffect(.clear.tint(.orange.opacity(0.6)))
            .glassEffect(.clear.interactive())
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image(.background1)
                .resizable()
                .scaledToFill()
                .blur(radius: 1)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    ContentView()
}
