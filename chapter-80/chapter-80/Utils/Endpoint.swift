//
//  Endpoint.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

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
    // TODO: [todos/backtick-reserved-keywords.md](../../todos/backtick-reserved-keywords.md)
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
