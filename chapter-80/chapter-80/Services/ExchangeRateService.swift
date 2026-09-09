//
//  ExchangeRateService.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Combine
import Foundation

final class ExchangeRateService {
    static let shared = ExchangeRateService()
    private init() {}

    // TODO: [todos/combine.md](../../todos/combine.md)
    func getExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
        return urlSession(ExchangeRate.self, with: Endpoint.withSymbols.url!)
    }

    func urlSession<T: Codable>(
        _ type: T.Type,
        with url: URL
    ) -> AnyPublisher<T, Error> {
        URLSession
            .shared
            // TODO: [todos/combine-vs-async-await.md](../../todos/combine-vs-async-await.md)
            .dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: type.self, decoder: JSONDecoder())
            // TODO: [todos/combine-operators.md](../../todos/combine-operators.md)
            .receive(on: RunLoop.main)
            .print()
            .eraseToAnyPublisher()
    }
}
