//
//  ContentView.swift
//  chapter-50
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    @State private var text = ""
    @State private var detectedURL: URL? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DevTechie.com")
                .font(.largeTitle)
            TextEditor(text: $text)
                .frame(height: 150)
                .border(.gray.opacity(0.5))
                // TODO: [todos/onchange-old-new-value.md](../../todos/onchange-old-new-value.md)
                .onChange(of: text) { oldValue, newValue in
                    detectedURL = extractFirstURL(from: text)
                }
            if let detectedURL {
                Link(
                    "Open detected url: \(detectedURL.absoluteString)",
                    destination: detectedURL
                )
                .foregroundStyle(.blue)
                .underline()
            }
            Spacer()
        }
        .padding()
    }

    // TODO: [todos/nsdatadetector-and-url-detection.md](../../todos/nsdatadetector-and-url-detection.md)
    func extractFirstURL(from text: String) -> URL? {
        // TODO: [todos/ns-prefix-foundation-classes.md](../../todos/ns-prefix-foundation-classes.md)
        let types: NSTextCheckingResult.CheckingType = .link
        // TODO: [todos/guard-keyword.md](../../todos/guard-keyword.md)
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return nil
        }
        // TODO: [todos/nsdatadetector-and-url-detection.md](../../todos/nsdatadetector-and-url-detection.md)
        let matches = detector.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: text.utf16.count)
        )
        return matches.first?.url
    }
}

#Preview {
    ContentView()
}
