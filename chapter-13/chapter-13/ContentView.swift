//
//  ContentView.swift
//  chapter-13
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Image(systemName: "square.and.arrow.up")
            .resizable()
            .scaledToFit()
            .padding()
            .foregroundStyle(Color.red)
        Image(systemName: "heart.circle.fill")
            .font(.largeTitle)
            // .font(Font.system(size: 100))
    }
}

#Preview {
    ContentView()
}
