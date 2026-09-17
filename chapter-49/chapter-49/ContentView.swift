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
                // FIXME: [Best Practice] 스킴이 빠진 잘못된 URL 문자열을 강제 언래핑하고 있다.
                // - 문제: "httpsgoogle.com" 은 스킴이 없어 상대 URL 로 만들어지고, Link 로 열리지 않는다.
                //         문자열이 조금만 더 망가지면 URL(string:) 이 nil 을 돌려주고 즉시 크래시한다.
                // - 개선: "https://google.com" 으로 고치고, if let / guard let 으로 옵셔널을 안전하게 푼다.
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
