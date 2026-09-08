//
//  ContentView.swift
//  chapter-59
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct NavigationLinkExample: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Dev Techie")
                    .font(.title)
                NavigationLink("first page") {
                    Text("Hello View")
                }
                NavigationLink("second page") {
                    Text("Next View")
                }
                // TODO: [todos/navigation-link-two-styles-mixed.md](../../todos/navigation-link-two-styles-mixed.md)
                NavigationLink(value: "New Page") {
                    Text("third page")
                }
            }
            .navigationDestination(for: String.self) { value in
                Text("Third View")
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationLinkExample()
    }
}

#Preview {
    ContentView()
}
