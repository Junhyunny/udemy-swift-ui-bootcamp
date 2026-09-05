//
//  ContentView.swift
//  chapter-21
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            // TODO, LazyVStack 사용 용도와 어느 시점에 Lazy 렌더링 되는 것인지 정확히 이해할 수 있는 예제 를 찾아줘.
            LazyVStack(spacing: 10) {
                ForEach(0..<200, id: \.self) { _ in
                    Text(
                        Date()
                            .formatted(date: .omitted, time: .standard)
                    )
                    .font(.largeTitle)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
