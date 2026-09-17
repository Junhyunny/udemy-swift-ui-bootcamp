//
//  ContentView.swift
//  chapter-47
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

// TODO: [todos/067-preference-key-and-onpreferencechange.md](../../todos/067-preference-key-and-onpreferencechange.md)
struct SizePreferenceKey: PreferenceKey {
    // TODO: [todos/032-typealias-and-associated-type.md](../../todos/032-typealias-and-associated-type.md)
    typealias Value = CGSize

    static let defaultValue: Value = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// TODO: [todos/042-view-modifier-protocol.md](../../todos/042-view-modifier-protocol.md)
struct MeasuringSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        // TODO: [todos/035-metatype-and-self.md](../../todos/035-metatype-and-self.md)
                        // TODO: [todos/022-swift-memory-model.md](../../todos/022-swift-memory-model.md)
                        key: SizePreferenceKey.self,
                        value: proxy.size
                    )
            }
        )
    }
}

// TODO: [todos/014-extension-keyword.md](../../todos/014-extension-keyword.md)
extension View {
    // TODO: [todos/040-closures-and-view-builders.md](../../todos/040-closures-and-view-builders.md)
    // FIXME: [Best Practice] 공개 API 이름에 오타가 있다(measureSzie -> measureSize).
    // - 이유: 한 번 노출된 modifier 이름은 호출부 전체에 퍼지므로 오타는 계속 복사된다.
    // - 개선: 이름을 measureSize 로 고치고 호출부도 함께 정리한다.
    //         iOS 17+ 라면 PreferenceKey 조합 대신 .onGeometryChange(for:of:action:) 가 더 간단하다.
    func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
        // TODO: [todos/042-view-modifier-protocol.md](../../todos/042-view-modifier-protocol.md)
        modifier(MeasuringSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}

struct ContentView: View {
    @State private var viewSize: CGSize = CGSize(width: 200, height: 50)
    @State private var lastSize: CGSize = CGSize(width: 200, height: 50)

    var body: some View {
        // TODO: [todos/068-geometry-reader-performance.md](../../todos/068-geometry-reader-performance.md)
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
