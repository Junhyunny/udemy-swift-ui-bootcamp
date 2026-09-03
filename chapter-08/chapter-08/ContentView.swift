//
//  ContentView.swift
//  chapter-08
//
//  Created by 강준현 on 9/3/26.
//

import SwiftUI

struct ContentView: View {

    @State private var text = ""
    @State private var progress = 0.0

    var body: some View {
        VStack {
            // 같은 progress @State 객체를 사용하고 있기 때문에 값이 연동된다.
            ProgressView(value: progress).padding()
            SliderView(progress: $progress)
            // binding with dollar keyword
            TextField("Enter name", text: $text)
                .textFieldStyle(.roundedBorder)
            Text("Welcome, \(text)!")
        }
        .padding()
    }
}

struct SliderView: View {
    // @Binding 프로퍼티 래퍼를 사용해서 외부 컴포넌트에서 관리 중인 값을 연결 가능
    @Binding var progress: Double
    var body: some View {
        Slider(value: $progress, in: 0...1)
    }
}

#Preview {
    ContentView()
}
