//
//  ContentView.swift
//  chapter-165
//
//  Created by 강준현 on 9/16/26.
//

import SwiftUI

struct StarRatingView: View {
    var rating: Double
    @State private var animatedRating: Double = 0.0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                Text("index\(index)")
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            StarRatingView(rating: 4.7)
            StarRatingView(rating: 3.5)
            StarRatingView(rating: 2.2)
            StarRatingView(rating: 1)
            StarRatingView(rating: 1.9)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
