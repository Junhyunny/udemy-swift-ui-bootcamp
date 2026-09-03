//
//  ContentView.swift
//  chapter-05
//
//  Created by 강준현 on 9/3/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // 글이 여러 줄인 경우에는 firstTextBaseline, lastTextBaseline의 정렬이 달라진다
        HStack(alignment: .top, spacing: 20) {
            // Rectangle().frame(width: 15, height: 100)
            Text("Hello Dev iOS Team")
                .foregroundStyle(Color.orange)
                .font(.largeTitle)
                .lineLimit(1)
                // layoutPriority 값을 지정하는 경우 레이아웃 스택에 있는 아이템 중 가장 중요한 아이템으로 취급하기 때문에 ... 으로 간소화 되거나 다른 텍스트에 의해 잘리지 않는다.
                // 우선순위가 낮은 텍스트들이 망가진다.
                .layoutPriority(1)
            Text("SwiftUI")

            Text("UIKit")
        }
        .frame(height: 150)
        .foregroundStyle(.secondary)
        .border(Color.black)
    }
}

#Preview {
    ContentView()
}
