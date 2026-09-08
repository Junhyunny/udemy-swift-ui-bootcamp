//
//  ContentView.swift
//  chapter-47
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

// TODO: [todos/preference-key-and-onpreferencechange.md](../../todos/preference-key-and-onpreferencechange.md)
struct SizePreferenceKey: PreferenceKey {
    // TODO: [todos/typealias-and-associated-type.md](../../todos/typealias-and-associated-type.md)
    typealias Value = CGSize

    static let defaultValue: Value = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// TODO: [todos/view-modifier-protocol.md](../../todos/view-modifier-protocol.md)
struct MeasuringSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        // TODO: [todos/metatype-and-self.md](../../todos/metatype-and-self.md)
                        // TODO: [todos/swift-memory-model.md](../../todos/swift-memory-model.md)
                        key: SizePreferenceKey.self,
                        value: proxy.size
                    )
            }
        )
    }
}

// TODO: [todos/extension-keyword.md](../../todos/extension-keyword.md)
extension View {
    // TODO: [todos/closures-and-view-builders.md](../../todos/closures-and-view-builders.md)
    func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
        // TODO: [todos/view-modifier-protocol.md](../../todos/view-modifier-protocol.md)
        modifier(MeasuringSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}

struct ContentView: View {
    @State private var viewSize: CGSize = CGSize(width: 200, height: 50)
    @State private var lastSize: CGSize = CGSize(width: 200, height: 50)

    var body: some View {
        // TODO: [todos/geometry-reader-performance.md](../../todos/geometry-reader-performance.md)
        VStack {
            ZStack(alignment: .bottomTrailing) {
                Text("This view knows its own size.")
                    .frame(width: viewSize.width, height: viewSize.height)
                    .background(.yellow)
                    .clipShape(.rect(cornerRadius: 10))
                    .measureSzie { size in
                        viewSize = size
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "square.resize")
                            .resizable()
                            .rotationEffect(.degrees(90))
                            .foregroundStyle(.yellow)
                            .frame(width: 20, height: 20)
                            .background(.white.gradient)
                            .offset(x: 5, y: 5)
                            .gesture(
                                DragGesture()
                                    .onChanged({ gesture in
                                        let newWidth = max(
                                            100,
                                            lastSize.width
                                                + gesture.translation.width
                                        )
                                        let newHeight = max(
                                            40,
                                            lastSize.height
                                                + gesture.translation.height
                                        )
                                        viewSize = CGSize(width: newWidth, height: newHeight)
                                    })
                                    .onEnded { _ in
                                        lastSize = viewSize
                                    }
                            )
                    }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
