//
//  ContentView.swift
//  chapter-40
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var colorExample = Color.orange
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(colorExample)
                .overlay {
                    Text("Junhyunny")
                        .font(.custom("Chalkduster", size: 24))
                        .foregroundStyle(.white)
                }
                .frame(height: 200)
            ColorPicker(
                "Pick a color",
                selection: $colorExample,
                // supportsOpacity: false
            )
            .labelsHidden()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
