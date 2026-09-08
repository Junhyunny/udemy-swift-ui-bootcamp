//
//  ContentView.swift
//  chapter-56
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    // TODO: [todos/image-resource-and-asset-symbols.md](../../todos/image-resource-and-asset-symbols.md)
    let photoCollection: [ImageResource] = [
        .pic1, .pic2, .pic3, .pic4, .pic5, .pic6,
    ]
    @State private var animate = false
    var body: some View {
        NavigationStack {
            ZStack {
                PhaseAnimator(
                    photoCollection,
                    trigger: animate
                ) { imageResource in
                    Image(imageResource)
                        .resizable()
                        .scaledToFill()
                        // TODO: [todos/scaled-to-fill-and-clipped.md](../../todos/scaled-to-fill-and-clipped.md)
                        .clipped()
                        .ignoresSafeArea()
                } animation: { _ in
                    Animation.snappy(duration: 2)
                }
                Text("Junhyunny Example")
                    .font(.title)
                    .frame(width: 300, height: 300)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 30))
            }
            .onTapGesture {
                animate.toggle()
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ContentView()
}
