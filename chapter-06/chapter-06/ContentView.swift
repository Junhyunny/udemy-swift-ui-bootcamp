//
//  ContentView.swift
//  chapter-06
//
//  Created by 강준현 on 9/3/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // ZStack 레이아웃 컨테이너는 차지할 수 있는 최대한의 영역을 차지한다.
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.orange.opacity(0.8))
                .ignoresSafeArea()
            Rectangle()
                .fill(.indigo)
                .frame(width: 350, height: 200)
            Rectangle()
                .fill(.mint)
                .frame(width: 300, height: 100)
            Text("Hello Junhyunny")
        }
    }
}

#Preview {
    ContentView()
}
