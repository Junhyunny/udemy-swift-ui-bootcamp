//
//  ExchangeRate.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

// TODO: [todos/optional-in-api-models.md](../../todos/optional-in-api-models.md)
struct ExchangeRate: Codable, Identifiable, Equatable {
    let id = UUID()
    let date: String?
    let rates: [String: Double]?

    private enum CodingKeys: String, CodingKey {
        case date, rates
    }
}

extension ExchangeRate {
    static var placeholder: ExchangeRate {
        // TODO: [todos/metatype-and-self.md](../../todos/metatype-and-self.md)
        Self(date: nil, rates: nil)
    }
}
