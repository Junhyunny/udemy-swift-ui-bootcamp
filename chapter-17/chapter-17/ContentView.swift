//
//  ContentView.swift
//  chapter-17
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(.photo1)
                .resizable()
                .scaledToFit()
                .frame(width: 300)
                .clipShape(
                    .rect(
                        topLeadingRadius: 50,
                        bottomTrailingRadius: 50
                    )
                )
                .opacity(0.7)
                // .clipShape(.capsule)
                // .clipShape(.rect(cornerRadius: 100))
                // .clipShape(.circle)
        }
    }
}

#Preview {
    ContentView()
}
