//
//  ContentView.swift
//  chapter-44
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
    var body: some View {
        // TODO: [todos/geometry-reader-use-cases.md](../../todos/geometry-reader-use-cases.md)
        // TODO: [todos/coordinate-space-local-global-named.md](../../todos/coordinate-space-local-global-named.md)
         GeometryReader { geometry in
             VStack {
                 Text("Width: \(Int(geometry.size.width))")
                     .font(.headline)
                 Text("Height: \(Int(geometry.size.height))")
                     .font(.headline)
                 Rectangle()
                     .foregroundStyle(
                         LinearGradient(
                             colors: [.orange, .pink, .red],
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing
                         )
                     )
                     .frame(
                         width: geometry.size.width * 0.8,
                         height: geometry.size.height * 0.8
                     )
             }
             .frame(maxWidth: .infinity, maxHeight: .infinity)
         }
         .frame(height: 300)
         .border(.gray)
    }
}

struct GeometryReaderExample2: View {
    var body: some View {
        VStack {
            Text("Coordinator Spaces")
                .font(.headline)
                .padding()
            ZStack {
                Color.gray.opacity(0.2)
                GeometryReader { geometry in
                    Rectangle()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading) {
                        Text("Local: \(geometryString(geometry.frame(in: .local)))")
                            .font(.headline)
                        Text("Global: \(geometryString(geometry.frame(in: .global)))")
                            .font(.headline)
                    }
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                }
            }
            .frame(width: 300, height: 300)
        }
    }
    
    func geometryString(_ frame: CGRect) -> String {
        return "x: \(Int(frame.origin.x)), y: \(Int(frame.origin.y)), width: \(Int(frame.size.width)), height: \(Int(frame.size.height))"
    }
}

#Preview {
    ContentView()
}
