//
//  ContentView.swift
//  chapter-48
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct OpenURLExample: View {
    // TODO: [todos/environment-property-wrapper.md](../../todos/environment-property-wrapper.md)
    @Environment(\.openURL) private var openURL
    var body: some View {
        Button("Visit Junhyunny's blog") {
            openURL(
                URL(string: "https://junhyunny.github.io")!
            )
        }
    }
}

struct ExternalLink: View {
    let url: URL
    let label: String
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Button(action: {
            openURL(url)
        }) {
            Text(label)
        }
    }
}

struct ContentView: View {
    var body: some View {
        List {
            OpenURLExample()
            ExternalLink(url: URL(string: "https://google.com")!, label: "google homepage")
        }
    }
}

#Preview {
    ContentView()
}
