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
// FIXME: [Best Practice] 이 파일 하나에 View, 모델(News/Article/Source), 네트워크 계층,
//        에러 타입, 설정(AppConfig)이 전부 들어 있다(266줄).
// - 문제: 관심사가 섞여 재사용/테스트가 불가능하고, 어떤 변경이든 이 파일을 건드리게 된다.
// - 개선: Models/, Services/, Utils/, Views/ 로 분리한다.
//         (같은 저장소의 chapter-80, chapter-146 이 이미 그 구조를 쓰고 있다)
struct ContentView: View {
    // FIXME: [Best Practice] View 가 "빈 응답" 더미를 직접 만들어 상태로 들고 있다.
    // - 문제: 로딩 중 / 성공 / 실패를 구분할 수 없어 실패해도 사용자는 빈 화면만 본다.
    //         같은 더미 생성 코드가 fetchNews() 안에도 한 번 더 중복된다.
    // - 개선: 화면에 필요한 최소 상태(@State private var articles: [Article] = [])만 두고,
    //         enum LoadState { case loading, loaded([Article]), failed(Error) } 로 표현한다.
    //         네트워크 호출은 @Observable ViewModel 로 옮긴다.
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
                    // FIXME: [Best Practice] 서버가 준 문자열을 검증 없이 강제 언래핑한다.
                    // - 문제: API 가 빈 문자열이나 깨진 URL 을 내려주면 그 즉시 앱이 죽는다. 외부 입력은 항상 의심해야 한다.
                    // - 개선: 모델에서 url 을 URL 타입으로 디코딩하거나, if let 으로 풀고 실패 시 대체 화면을 보여준다.
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
            // FIXME: [Best Practice] 같은 강제 언래핑 문제. urlToImage 는 원래 옵셔널이었는데
            //        호출부에서 ?? "" 로 빈 문자열을 넘기고, 여기서 다시 ! 로 풀고 있다.
            // - 개선: imageURL 을 URL? 로 받아 AsyncImage(url:) 에 그대로 넘긴다.
            //         AsyncImage 는 nil URL 을 placeholder 로 처리해준다.
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
// FIXME: [Best Practice] Codable 타입에 let id = UUID() 기본값을 넣었다.
// - 문제: 디코딩할 때마다 새 id 가 생겨 "같은 기사"를 다시 받아도 다른 항목으로 취급된다.
//         리스트가 통째로 다시 그려지고 스크롤 위치가 튄다. Equatable 을 붙이면 영원히 불일치한다.
// - 개선: 서버가 주는 안정적인 키(Article 이면 url)를 id 로 쓴다. -> var id: String { url }
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

// FIXME: [Architecture] 범용 네트워크 계층인데 싱글턴으로만 접근 가능하고, View 가 직접 사용한다.
// - 현상: static let shared / private init 이라 인스턴스를 만들 수 없다.
//         호출 경로는 ContentView -> News.fetchNews() -> NetworkingManager.shared 로,
//         View 와 모델이 전송 계층에 직접 의존한다. 사이에 ViewModel 이 없다.
// - 문제: 통신을 가로채 가짜 응답을 줄 방법이 없어 화면 테스트가 불가능하다.
//         URLSession 을 주입받게만 해도 URLProtocol 스텁으로 테스트할 수 있다.
// - 개선: init(session: URLSession = .shared) 를 열고,
//         protocol NewsFetching 을 통해 @Observable NewsViewModel 에 주입한다.
//         View 는 ViewModel 만, ViewModel 은 프로토콜만 알게 해서 의존 방향을 한쪽으로 정리한다.
struct NetworkingManager {
    static let shared = NetworkingManager()
    private init() {}

    // TODO: [todos/swift-generics.md](../../todos/swift-generics.md)
    func request<T: Decodable>(
        // FIXME: [Best Practice] 엔드포인트를 String 으로 받아 매번 URL(string:) 으로 파싱한다.
        // - 문제: 쿼리 인코딩, 경로 조합, 키 주입을 호출부가 문자열 보간으로 직접 해야 한다.
        //         오타나 인코딩 누락을 컴파일러가 잡아줄 수 없다.
        // - 개선: chapter-80 의 Endpoint enum 처럼 URLComponents 기반 타입으로 받는다.
        //         -> func request<T: Decodable>(_ endpoint: Endpoint, ...)
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
            // FIXME: [Best Practice] API 키를 URL 쿼리스트링에 그대로 실어 보낸다.
            // - 문제: 쿼리스트링은 서버 액세스 로그, 프록시, 리퍼러에 평문으로 남는다.
            //         Info.plist 의 API_KEY 도 앱 번들을 풀면 그대로 읽힌다.
            // - 개선: 최소한 헤더(Authorization / X-Api-Key)로 옮기고,
            //         실제 서비스라면 키를 서버 측 프록시에 두고 클라이언트에는 두지 않는다.
            // - 추가: 네트워크 호출이 모델 타입(News)의 static 메서드로 들어가 있다.
            //         모델은 데이터 표현만 맡고, 호출은 Service/Repository 계층으로 분리한다.
            let news = try await NetworkingManager.shared.request(
                endpoint:
                    "https://newsapi.org/v2/top-headlines?sources=techcrunch&apiKey=\(AppConfig.apiKey)",
                responseType: News.self
            )
            return news
        // FIXME: [Best Practice] 빈 catch 블록. 모든 에러를 조용히 버린다.
        // - 문제: 네트워크 실패인지 디코딩 실패인지 알 수 없고, 화면은 영원히 빈 리스트다.
        // - 개선: throws 를 그대로 전파하거나 Result 로 돌려주고, 호출부에서 사용자에게 알린다.
        } catch {}
        return nil
    }
}

#Preview {
    ContentView()
}
