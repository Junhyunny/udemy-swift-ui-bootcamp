//
//  ContentView.swift
//  chapter-03
//
//  Created by 강준현 on 9/3/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // HStack
        // VStack
        // ZStack
        ZStack {
            Rectangle()
                .fill(.mint)
                .frame(width: 400, height: 400)
                .overlay {
                    Text("1").foregroundStyle(Color.white)
                }
            Rectangle()
                .fill(.orange)
                .frame(width: 300, height: 300)
                .overlay {
                    Text("2").foregroundStyle(Color.white)
                }
            Rectangle()
                .fill(.indigo)
                .frame(width: 200, height: 200)
                .overlay {
                    Text("3").foregroundStyle(Color.white)
                }
        }
    }
}

#Preview {
    ContentView()
}
