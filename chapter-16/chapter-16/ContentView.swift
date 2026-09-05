//
//  ContentView.swift
//  chapter-16
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            // TODO: [todos/asset-catalog-universal-scale.md](../../todos/asset-catalog-universal-scale.md)
            Image(.photo1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                // .ignoresSafeArea()
                // .scaledToFit()
                .frame(width: 300, height: 300)
                // .clipped()
        }
        .padding()
    }
}

#Preview {
    // TODO: [todos/image-layout-and-preview-bounds.md](../../todos/image-layout-and-preview-bounds.md)
    ContentView()
}
