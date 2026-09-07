//
//  ContentView.swift
//  chapter-25
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Junhyunny teaches iOS development in Swift, SwfitUI, UIKit as well as WatchOS development in SwiftUI.")
                .font(.largeTitle) // largeTitle 같은 폰트 사이즈는 플랫폼마다 다르게 동작한다
                .foregroundStyle(.orange)
                // .frame(width: 200, height: 100)
                .lineSpacing(20)
                .lineLimit(2)
        }
    }
}

#Preview {
    ContentView()
}
