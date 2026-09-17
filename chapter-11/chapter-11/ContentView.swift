//
//  ContentView.swift
//  chapter-11
//
//  Created by 강준현 on 9/5/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ColorMixerApp()
    }
}

// TODO: [todos/019-struct-vs-class.md](../../todos/019-struct-vs-class.md)
struct ColorMixerApp: View {
    @State private var red: Double = 0
    @State private var green: Double = 0
    @State private var blue: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        Color(red: red, green: green, blue: blue)
                    )
                    .frame(height: 300)
                Text("Color Preview")
                    .foregroundStyle(Color.white)
                    .bold()
                    .shadow(radius: 5)
            }
            VStack {
                SliderView(value: $red, name: "Red", color: .red)
                SliderView(value: $green, name: "Green", color: .green)
                SliderView(value: $blue, name: "Blue", color: .blue)
            }
            .padding()
        }
        .padding()
    }
}

struct SliderView: View {
    // TODO: [todos/017-access-control.md](../../todos/017-access-control.md)
    @Binding var value: Double
    // TODO: [todos/002-let-vs-var.md](../../todos/002-let-vs-var.md)
    let name: String
    let color: Color

    var body: some View {
        HStack {
            Text(name)
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(color)
            // TODO: [todos/044-property-wrapper-dollar-sign.md](../../todos/044-property-wrapper-dollar-sign.md)
            Slider(value: $value)
            Text(String(format: "%.2f", value))
        }
    }
}

#Preview {
    ContentView()
}
