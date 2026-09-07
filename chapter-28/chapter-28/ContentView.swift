//
//  ContentView.swift
//  chapter-28
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            // range operator 를 사용한 날짜 표기
            Text(Date()...Date().addingTimeInterval(3600))
                .font(.largeTitle)
            Text(Date(), style: .offset)
                .font(.largeTitle)
            Text(Date(), style: .relative)
                .font(.largeTitle)
            Text(Date(), style: .timer)
                .font(.largeTitle)
            Text(Date(), style: .time)
                .font(.largeTitle)
            Text(Date(), style: .date)
                .font(.largeTitle)
        }
    }
}

#Preview {
    ContentView()
}
