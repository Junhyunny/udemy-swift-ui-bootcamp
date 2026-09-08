//
//  ContentView.swift
//  chapter-61
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI
// TODO: [todos/uiviewrepresentable-and-uikit-bridge.md](../../todos/uiviewrepresentable-and-uikit-bridge.md)
import WebKit

// TODO: [todos/api-key-security-and-environment-variables.md](../../todos/api-key-security-and-environment-variables.md)
enum AppConfig {
    static let apiKey: String = {
        guard
            let value =
                Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String
        else {
            fatalError("API_KEY is missing")
        }

        return value
    }()
}

// TODO: [todos/api-key-security-and-environment-variables.md](../../todos/api-key-security-and-environment-variables.md)
struct ContentView: View {
    @State private var news: News = .init(
        status: "",
        totalResults: 0,
        articles: []
    )
    var body: some View {
        NavigationStack {
            List(news.articles) { article in
                ZStack {
                    // TODO: [todos/swiftui-hit-testing-vs-dom-events.md](../../todos/swiftui-hit-testing-vs-dom-events.md)
                    NavigationLink(value: article.url) {
                        EmptyView()
                    }
                    .opacity(0.0)
                    CardView(
                        title: article.title,
                        desc: article.description ?? "",
                        author: article.author ?? "",
                        imageURL: article.urlToImage ?? ""
                    )
                }
            }
            .navigationTitle("News")
            .listStyle(.plain)
            .onAppear {
                fetchNews()
            }
            .refreshable {
                fetchNews()
            }
            .navigationDestination(
                for: String.self,
                destination: { url in
                    WebView(url: URL(string: url)!)
                }
            )
        }
        // TODO: [todos/task-modifier-and-async-lifecycle.md](../../todos/task-modifier-and-async-lifecycle.md)
        .task {
            print("fetching news")
            // print(await News.fetchNews())
        }
        .padding()
    }

    func fetchNews() {
        // TODO: [todos/task-modifier-and-async-lifecycle.md](../../todos/task-modifier-and-async-lifecycle.md)
        Task {
            news =
                await News.fetchNews()
                ?? .init(
                    status: "",
                    totalResults: 0,
                    articles: []
                )
        }
    }
}

// TODO: [todos/uiviewrepresentable-and-uikit-bridge.md](../../todos/uiviewrepresentable-and-uikit-bridge.md)
struct WebView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        .init()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

struct CardView: View {
    var title: String
    var desc: String
    var author: String
    var imageURL: String

    var body: some View {
        VStack {
            // TODO: [todos/async-image.md](../../todos/async-image.md)
            AsyncImage(url: URL(string: imageURL)!) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
            }
            .clipped()
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(author)
                    .font(.subheadline)
                Text(desc)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.leading)
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 30))
        .background {
            RoundedRectangle(cornerRadius: 30)
                .foregroundStyle(.white)
                .shadow(radius: 5)
        }
        .padding(5)
    }
}

// TODO: [todos/codable-and-codingkey.md](../../todos/codable-and-codingkey.md)
struct News: Codable, Identifiable {
    let id = UUID()
    let status: String
    let totalResults: Int
    let articles: [Article]

    // TODO: [todos/enum-raw-values.md](../../todos/enum-raw-values.md)
    // TODO: [todos/codable-and-codingkey.md](../../todos/codable-and-codingkey.md)
    enum CodingKeys: String, CodingKey {
        case status
        case totalResults
        case articles
    }
}

struct Article: Codable, Identifiable {
    let id = UUID()
    let source: Source
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?

    enum CodingKeys: CodingKey {
        case source
        case author
        case title
        case description
        case url
        case urlToImage
        case publishedAt
        case content
    }
}

struct Source: Codable {
    let id: String?
    let name: String
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum NetworkError: Error {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingError
    case unknownError
}

struct NetworkingManager {
    static let shared = NetworkingManager()
    private init() {}

    // TODO: [todos/swift-generics.md](../../todos/swift-generics.md)
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        responseType: T.Type,
        // TODO: [todos/async-throws-and-custom-errors.md](../../todos/async-throws-and-custom-errors.md)
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            // TODO: [todos/async-throws-and-custom-errors.md](../../todos/async-throws-and-custom-errors.md)
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        headers?.forEach({ key, value in
            request.setValue(value, forHTTPHeaderField: key)
        })
        // TODO: [todos/if-conditions-and-optional-binding.md](../../todos/if-conditions-and-optional-binding.md)
        if let parameters = parameters, method != .get {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: parameters,
                options: []
            )
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        // TODO: [todos/if-conditions-and-optional-binding.md](../../todos/if-conditions-and-optional-binding.md)
        if let httpResponse = response as? HTTPURLResponse,
            !(200...299).contains(httpResponse.statusCode)
        {
            throw NetworkError.requestFailed(
                statusCode: httpResponse.statusCode
            )
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}

extension News {
    static func fetchNews() async -> News? {
        do {
            let news = try await NetworkingManager.shared.request(
                endpoint:
                    "https://newsapi.org/v2/top-headlines?sources=techcrunch&apiKey=\(AppConfig.apiKey)",
                responseType: News.self
            )
            return news
        } catch {}
        return nil
    }
}

#Preview {
    ContentView()
}
