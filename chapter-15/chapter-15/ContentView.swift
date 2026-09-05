//
//  ContentView.swift
//  chapter-15
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    @State private var value: Double = 0.0
    var body: some View {
        VStack {
            Image(
                systemName: "wifi.badge.lock",
                variableValue: value
            )
            .resizable()
            .scaledToFit()
            .padding()
            Slider(
                value: $value,
                in: 0...1
            )
        }
    }
}

#Preview {
    ContentView()
}
