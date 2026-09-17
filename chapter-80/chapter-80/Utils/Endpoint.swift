//
//  Endpoint.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

// FIXME: [Architecture] 'Utils' 가 성격이 다른 두 관심사의 임시 보관소가 되었다.
// - 현상: 앱 설정(AppConfig)과 API 엔드포인트 정의(Endpoint)가 한 파일, 그것도 Utils/ 아래에 있다.
// - 문제: Utils 는 '분류하지 않은 것'이라는 뜻이라 계속 커지고, 나중에 누구도 정리하지 않는다.
//         설정은 앱 전역 관심사이고 엔드포인트는 네트워크 계층 관심사라 변경 이유도 다르다.
// - 개선: Configuration/AppConfig.swift 와 Services(또는 Networking)/Endpoint.swift 로 나눈다.
//         Utils/ 에는 URL+Extensions.swift 처럼 도메인 지식이 없는 순수 확장만 남긴다.
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

enum Endpoint {
    // TODO: [todos/012-backtick-reserved-keywords.md](../../../todos/012-backtick-reserved-keywords.md)
    case `default`
    case withSymbols

    private var baseURL: URL {
        URL(string: "https://api.exchangeratesapi.io/v1/latest")!
    }

    var url: URL? {
        baseURL.setQueries(query())
    }

    func query() -> [String: String] {
        switch self {
        case .default:
            return ["access_key": AppConfig.apiKey]
        case .withSymbols:
            return [
                "symbols": "GBP,JPY,USD,INR",
                "access_key": AppConfig.apiKey,
            ]
        }
    }
}
