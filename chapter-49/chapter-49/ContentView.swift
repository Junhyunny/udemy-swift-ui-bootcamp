//
//  ContentView.swift
//  chapter-49
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        List {
            ExternalLink(
                url: URL(string: UIApplication.openSettingsURLString)!,
                label: "Settings"
            )
            ExternalLink(
                url: URL(string: "mailto:hello@gmail.com")!,
                label: "wrong protocol"
            )
            ExternalLink(
                url: URL(string: "httpsgoogle.com")!,
                label: "wrong url"
            )
        }
    }
}

struct ExternalLink: View {
    let url: URL
    let label: String
    @Environment(\.openURL) private var openURL
    @State private var showAlert = false
    var body: some View {
        Button(action: {
            openURL(url) { accepted in
                if !accepted {
                    showAlert = true
                }
            }
        }) {
            Text(label)
        }
        .alert("Unable to open URL", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please check your url \(url.absoluteString)")
        }
    }
}

#Preview {
    ContentView()
}
