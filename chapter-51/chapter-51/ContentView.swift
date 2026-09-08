//
//  ContentView.swift
//  chapter-51
//
//  Created by 강준현 on 9/8/26.
//

// TODO: [todos/observation-framework-and-observable.md](../../todos/observation-framework-and-observable.md)
import Observation
import SwiftUI

// TODO: [todos/enum-hashable-conformance.md](../../todos/enum-hashable-conformance.md)
enum Route: Hashable {
    case test
    case support
}

// TODO: [todos/observation-framework-and-observable.md](../../todos/observation-framework-and-observable.md)
@Observable
final class NavigationCoordinator {
    var path = NavigationPath()
    
    func handleDeepLinkURL(_ url: URL) {
        guard url.scheme == "devtechie" else { return }
        switch url.host {
        case "test":
            path.append(Route.test)
        case "support":
            path.append(Route.support)
        default:
            break
        }
    }
}

struct TestView: View {
    var body: some View {
        VStack {
            Text("🧪 Test View")
                .font(.largeTitle)
                .padding()
        }
    }
}

struct SupportView: View {
    var body: some View {
        VStack {
            Text("🎗️ Support View")
                .font(.largeTitle)
                .padding()
        }
    }
}

struct ContentView: View {
    @State private var text = ""
    @State private var coordinator = NavigationCoordinator()
    @State private var latestURL: URL?
    @State private var messageFromDeepLink: String?
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Junhyunny's example")
                    .font(.title)
                TextEditor(text: $text)
                    .frame(height: 300)
                    .border(.gray.opacity(0.5))
                    .onOpenURL { url in
                        latestURL = url
                        text += "\nOpened URL: \(url)"
                        coordinator.handleDeepLinkURL(url)
                    }
                if let message = messageFromDeepLink {
                    Text("Message from deep link: \(message)")
                        .foregroundStyle(.green)
                        .padding(.top)
                }
                Spacer()
            }
            .padding()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .test:
                    TestView()
                case .support:
                    SupportView()
                }
            }
        }
        .onChange(of: latestURL) { _, newValue in
            handleURL(newValue)
        }
        .padding()
    }
    
    func handleURL(_ url: URL?) {
        guard let url else { return }
        if url.scheme == "devtechie" {
            switch url.host {
            case "test":
                messageFromDeepLink = url.query
            case "support":
                messageFromDeepLink = "Deep link to support page received"
            default:
                messageFromDeepLink = "Unknown deep link received"
            }
        } else {
            messageFromDeepLink = "System URL: \(url.absoluteString)"
        }
    }
}

struct DeepLinkExample1: View {
    @State private var text = ""
    @State private var detectedURL: URL? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Junhyunny's Example")
                .font(.title)
            TextEditor(text: $text)
                .frame(height: 300)
                .border(.gray.opacity(0.5))
                .onChange(of: text) { _, _ in
                    detectedURL = extractFirstURL(from: text)
                }
            // TODO: [todos/deep-link-and-url-scheme.md](../../todos/deep-link-and-url-scheme.md)
            // TODO: [todos/url-scheme-resolution-and-conflicts.md](../../todos/url-scheme-resolution-and-conflicts.md)
                .onOpenURL { url in
                    text += "\nOpened URL: \(url.absoluteString)"
                }
            if let detectedURL {
                Link(
                    "Open detected url \(detectedURL.absoluteString)",
                    destination: detectedURL
                )
                .foregroundStyle(Color.blue)
                .underline(true)
            }
            Spacer()
        }
        .padding()
    }
    
    func extractFirstURL(from text: String) -> URL? {
        let types: NSTextCheckingResult.CheckingType = .link
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return nil
        }
        let matches = detector.matches(
            in: text,
            options: [],
            range: NSRange(
                location: 0,
                length: text.utf16.count
            )
        )
        return matches.first?.url
    }
}

#Preview {
    ContentView()
}
