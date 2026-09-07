//
//  ContentView.swift
//  chapter-36
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var counter = 0
    @State private var disable = true
    var body: some View {
        NavigationStack {
            VStack {
                Text("Button was tapped \(counter) times.")
                // Button("Click Me") {
                //     counter += 1
                // }
                // Button("Click Me", action: {
                //     counter += 1
                // })
                // Button("Click Me", action: increaseCount)
                HStack {
                    // Button(
                    //     action: increaseCount,
                    //     label: {
                    //         // buttonBody(isUp: true)
                    //         Text("Up")
                    //     }
                    // )
                    // .buttonStyle(.borderedProminent)
                    // Button(
                    //     action: decreaseCount,
                    //     label: {
                    //         // buttonBody(isUp: false
                    //         Text("Down")
                    //     }
                    // )
                    // .buttonStyle(.bordered)
                    // TODO: [todos/closures-and-view-builders.md](../../todos/closures-and-view-builders.md)
                    Button(role: .confirm) {
                        increaseCount()
                    } label: {
                        Text("Up")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                    .disabled(disable)
                    // .controlSize(.regular)
                    // .tint(.mint)
                    Button(role: .destructive) {
                        decreaseCount()
                    } label: {
                        Text("Down")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                    .disabled(disable)
                }
                Button(disable ? "Enable" : "Disable") {
                    disable.toggle()
                }
            }
            .navigationTitle("Junhyunny App")
        }
    }

    private func increaseCount() {
        counter += 1
    }

    private func decreaseCount() {
        counter -= 1
    }

    // TODO: [todos/viewbuilder-vs-view-struct.md](../../todos/viewbuilder-vs-view-struct.md)
    @ViewBuilder
    func buttonBody(isUp: Bool) -> some View {
        VStack {
            Image(systemName: "arrowtriangle.\(isUp ? "up" : "down").fill")
            Text("Tap to count")
        }
        .padding()
        .foregroundStyle(.white)
        .background(isUp ? .orange : .mint, in: .rect(cornerRadius: 10))
    }
}

#Preview {
    ContentView()
}
