//
//  WebView.swift
//  chapter-88
//
//  Created by 강준현 on 9/9/26.
//

import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let urlString: String?

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // TODO: [todos/guard-keyword.md](../../todos/guard-keyword.md)
        guard let urlString, let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

#Preview {
    WebView(urlString: "")
}
