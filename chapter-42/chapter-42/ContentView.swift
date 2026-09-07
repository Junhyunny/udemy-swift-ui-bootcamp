//
//  ContentView.swift
//  chapter-42
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var valueTranslation = CGSize.zero
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Image(.cfgdBack)
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 417)
                .overlay {
                    Rectangle()
                        .fill(.black)
                        .frame(width: 300, height: 50)
                        .colorInvert()
                        .blur(radius: 100)
                        .offset(
                            x: -valueTranslation.width / 1.5,
                            y: -valueTranslation.height / 1.5
                        )

                }
                .clipped()
            Image(.cfgdFront)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 200)
                // TODO: [todos/chained-offset-modifiers.md](../../todos/chained-offset-modifiers.md)
                .offset(y: 20)
                .offset(
                    x: valueTranslation.width / 30,
                    y: valueTranslation.height / 30
                )
        }
        .frame(width: 1000, height: 1000)
        .background(.black)
        // TODO: [todos/rotation3d-axis-and-card-tilt.md](../../todos/rotation3d-axis-and-card-tilt.md)
        .rotation3DEffect(
            .degrees(isDragging ? 10 : 0),
            axis: (
                x: -valueTranslation.height,
                y: valueTranslation.width,
                z: 0.0
            )
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation {
                        valueTranslation = value.translation
                        isDragging = true
                    }
                }
                .onEnded { _ in
                    withAnimation {
                        valueTranslation = .zero
                        isDragging = false
                    }
                }
        )
        .padding()
    }
}

#Preview {
    ContentView()
}
