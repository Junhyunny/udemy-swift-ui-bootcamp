//
//  ContentView.swift
//  chapter-45
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // GeometryReaderExample1()
        GeometryReaderExample2()
    }
}

struct GeometryReaderExample1: View {
    // TODO: [todos/closure-shorthand-argument-names.md](../../todos/closure-shorthand-argument-names.md)
    let items = Array(1...20).map { "Item \($0)" }
    let columns = 3
    // TODO: [todos/coregraphics-types-and-cgfloat.md](../../todos/coregraphics-types-and-cgfloat.md)
    let spacing: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                let itemWidth = (geometry.size.width - (spacing * CGFloat(columns - 1))) / CGFloat(columns)
                LazyVGrid(
                    columns: gridItems(width: itemWidth),
                    spacing: spacing
                ) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .background(.blue.opacity(0.2))
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
    }
    
    func gridItems(width: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(.fixed(width), spacing: spacing),
            count: columns
        )
    }
}

struct GeometryReaderExample2: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Image(.photo1)
                    .resizable()
                    .scaledToFill()
                    .frame(height: geometry.size.height * 0.6)
                    .clipped()
                VStack(alignment: .leading) {
                    Text("Junhyunny.com")
                        .font(.headline)
                    Text("This is a card with proportional sizing based on the available space in the GeometryReader. The image takes 60% and content takes remaining 40%.")
                        .font(.subheadline)
                        .foregroundStyle(.orange.shadow(.drop(radius: 2)))
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Learn More")
                            .font(.caption)
                            .foregroundStyle(.blue.gradient)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.blue.opacity(0.2))
                            .clipShape(.rect(cornerRadius: 4))
                    }
                }
                .padding()
                .frame(height: geometry.size.height * 0.4)
            }
            .background(.white)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(radius: 5)
        }
        .frame(height: 500)
        .padding()
    }
}

#Preview {
    ContentView()
}
