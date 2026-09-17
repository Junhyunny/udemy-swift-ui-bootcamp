//
//  Country.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

// FIXME: [Architecture] 모델이 데이터 소스 역할까지 겸하고 있다.
// - 현상: Country 는 값 타입 모델인데, 확장에서 30개 고정 목록(sample)과
//         조회 API(getCountryBy(name:/code:/currencyCode:))까지 제공한다.
//         사실상 '저장소(Repository)'가 모델 안에 숨어 있는 구조다.
// - 문제: 국가 목록을 나중에 서버/번들 JSON 에서 받아오게 바꾸려면 모델 정의를 고쳐야 한다.
//         정적 메서드라 호출부가 이 구현에 컴파일 타임으로 묶여 테스트 대역도 넣을 수 없다.
// - 개선: protocol CountryRepository { func country(forCurrency: String) -> Country? } 를 두고
//         InMemoryCountryRepository 가 이 목록을 갖게 한다. ViewModel 은 저장소를 주입받는다.
//         모델(Country)은 필드 정의만 남긴다.
struct Country {
    let countryName: String
    let countryCode: String
    let currencyCode: String
    let flagEmoji: String
}

extension Country {
    static var sample: [Country] {
        [
            Country(
                countryName: "South Korea",
                countryCode: "KR",
                currencyCode: "KRW",
                flagEmoji: "🇰🇷"
            ),
            Country(
                countryName: "Japan",
                countryCode: "JP",
                currencyCode: "JPY",
                flagEmoji: "🇯🇵"
            ),
            Country(
                countryName: "China",
                countryCode: "CN",
                currencyCode: "CNY",
                flagEmoji: "🇨🇳"
            ),
            Country(
                countryName: "Taiwan",
                countryCode: "TW",
                currencyCode: "TWD",
                flagEmoji: "🇹🇼"
            ),
            Country(
                countryName: "Hong Kong",
                countryCode: "HK",
                currencyCode: "HKD",
                flagEmoji: "🇭🇰"
            ),
            Country(
                countryName: "Singapore",
                countryCode: "SG",
                currencyCode: "SGD",
                flagEmoji: "🇸🇬"
            ),
            Country(
                countryName: "Thailand",
                countryCode: "TH",
                currencyCode: "THB",
                flagEmoji: "🇹🇭"
            ),
            Country(
                countryName: "Vietnam",
                countryCode: "VN",
                currencyCode: "VND",
                flagEmoji: "🇻🇳"
            ),
            Country(
                countryName: "Indonesia",
                countryCode: "ID",
                currencyCode: "IDR",
                flagEmoji: "🇮🇩"
            ),
            Country(
                countryName: "Malaysia",
                countryCode: "MY",
                currencyCode: "MYR",
                flagEmoji: "🇲🇾"
            ),
            Country(
                countryName: "Philippines",
                countryCode: "PH",
                currencyCode: "PHP",
                flagEmoji: "🇵🇭"
            ),
            Country(
                countryName: "India",
                countryCode: "IN",
                currencyCode: "INR",
                flagEmoji: "🇮🇳"
            ),
            Country(
                countryName: "United States",
                countryCode: "US",
                currencyCode: "USD",
                flagEmoji: "🇺🇸"
            ),
            Country(
                countryName: "Canada",
                countryCode: "CA",
                currencyCode: "CAD",
                flagEmoji: "🇨🇦"
            ),
            Country(
                countryName: "Mexico",
                countryCode: "MX",
                currencyCode: "MXN",
                flagEmoji: "🇲🇽"
            ),
            Country(
                countryName: "United Kingdom",
                countryCode: "GB",
                currencyCode: "GBP",
                flagEmoji: "🇬🇧"
            ),
            Country(
                countryName: "Germany",
                countryCode: "DE",
                currencyCode: "EUR",
                flagEmoji: "🇩🇪"
            ),
            Country(
                countryName: "France",
                countryCode: "FR",
                currencyCode: "EUR",
                flagEmoji: "🇫🇷"
            ),
            Country(
                countryName: "Italy",
                countryCode: "IT",
                currencyCode: "EUR",
                flagEmoji: "🇮🇹"
            ),
            Country(
                countryName: "Spain",
                countryCode: "ES",
                currencyCode: "EUR",
                flagEmoji: "🇪🇸"
            ),
            Country(
                countryName: "Portugal",
                countryCode: "PT",
                currencyCode: "EUR",
                flagEmoji: "🇵🇹"
            ),
            Country(
                countryName: "Netherlands",
                countryCode: "NL",
                currencyCode: "EUR",
                flagEmoji: "🇳🇱"
            ),
            Country(
                countryName: "Switzerland",
                countryCode: "CH",
                currencyCode: "CHF",
                flagEmoji: "🇨🇭"
            ),
            Country(
                countryName: "Sweden",
                countryCode: "SE",
                currencyCode: "SEK",
                flagEmoji: "🇸🇪"
            ),
            Country(
                countryName: "Norway",
                countryCode: "NO",
                currencyCode: "NOK",
                flagEmoji: "🇳🇴"
            ),
            Country(
                countryName: "Australia",
                countryCode: "AU",
                currencyCode: "AUD",
                flagEmoji: "🇦🇺"
            ),
            Country(
                countryName: "New Zealand",
                countryCode: "NZ",
                currencyCode: "NZD",
                flagEmoji: "🇳🇿"
            ),
            Country(
                countryName: "Brazil",
                countryCode: "BR",
                currencyCode: "BRL",
                flagEmoji: "🇧🇷"
            ),
            Country(
                countryName: "Argentina",
                countryCode: "AR",
                currencyCode: "ARS",
                flagEmoji: "🇦🇷"
            ),
            Country(
                countryName: "United Arab Emirates",
                countryCode: "AE",
                currencyCode: "AED",
                flagEmoji: "🇦🇪"
            ),
        ]
    }

    // TODO: [todos/swift-function-overloading.md](../../todos/swift-function-overloading.md)
    // FIXME: [Best Practice] 조회할 때마다 30개 배열을 새로 만들고(sample 이 계산 프로퍼티) 전체를 훑는다.
    // - 문제: filter 는 조건을 만족하는 모든 원소를 다 모은 뒤 first 를 꺼내므로 조기 종료도 못 한다.
    //         이 함수들은 List 의 모든 행에서 호출된다.
    // - 개선: sample 을 static let 으로 바꾸고, 조회는 first(where:) 로,
    //         반복 조회가 필요하면 static let byCurrencyCode: [String: Country] 딕셔너리를 만들어 O(1) 로 만든다.
    static func getCountryBy(name: String) -> Country? {
        sample.filter { country in
            country.countryName.lowercased() == name.lowercased()
        }
        .first
    }

    static func getCountryBy(code: String) -> Country? {
        sample.filter { country in
            country.countryCode.lowercased() == code.lowercased()
        }
        .first
    }

    static func getCountryBy(currencyCode: String) -> Country? {
        sample.filter { country in
            country.currencyCode.lowercased() == currencyCode.lowercased()
        }
        .first
    }
}
