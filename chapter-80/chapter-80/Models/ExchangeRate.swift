//
//  ExchangeRate.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

// TODO: [todos/118-optional-in-api-models.md](../../../todos/118-optional-in-api-models.md)
// FIXME: [Best Practice] Equatable 인데 매번 새로 생성되는 UUID 를 프로퍼티로 갖고 있다.
// - 문제: 내용이 완전히 같은 두 응답도 id 가 달라 항상 != 로 판정된다.
//         Equatable 을 붙인 의미가 사라지고, 불필요한 View 갱신을 유발한다.
// - 개선: id 를 빼고 date 를 식별자로 쓰거나(var id: String { date ?? "" }),
//         Equatable 합성에서 id 를 제외하도록 == 를 직접 구현한다.
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
        // TODO: [todos/035-metatype-and-self.md](../../../todos/035-metatype-and-self.md)
        Self(date: nil, rates: nil)
    }
}
