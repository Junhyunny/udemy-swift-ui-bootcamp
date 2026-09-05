//
//  ContentView.swift
//  chapter-14
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Image(systemName: "square.and.arrow.up.badge.checkmark")
            .resizable()
            .scaledToFit()
            .padding()
            // TODO: [todos/symbol-rendering-mode.md](../../todos/symbol-rendering-mode.md)
            // .symbolRenderingMode(.multicolor)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.indigo, .mint)
    }
}

#Preview {
    ContentView()
}
