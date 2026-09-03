//
//  ContentView.swift
//  chapter-07
//
//  Created by 강준현 on 9/3/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Mastering PDFKit")
                .font(.largeTitle)
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.orange)
                    Text("SwiftUI")
                        .font(.title.bold())
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.mint)
                    Text("PDFKit")
                        .font(.title3.bold())
                }
            }
            .foregroundStyle(.white)
            .frame(height: 200)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
