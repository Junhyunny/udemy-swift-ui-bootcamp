//
//  ContentView.swift
//  chapter-41
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var flag: Bool = false
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.orange.gradient)
                .frame(width: 200, height: 100)
                .overlay {
                    Text("Junhyunny")
                }
                .offset(y: flag ? 400 : 0)
            // TODO: [todos/animation-value-trigger.md](../../todos/animation-value-trigger.md)
            // .animation(.easeInOut(duration: 2), value: flag)
            Spacer()
            Button("Toggle") {
                // TODO: [todos/implicit-vs-explicit-animation.md](../../todos/implicit-vs-explicit-animation.md)
                withAnimation(
                    // .bouncy().repeatForever()
                    .bouncy().repeatCount(3, autoreverses: true)
                ) {
                    flag.toggle()
                }
                // completion: {
                //     withAnimation {
                //         flag.toggle()
                //     }
                // }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
