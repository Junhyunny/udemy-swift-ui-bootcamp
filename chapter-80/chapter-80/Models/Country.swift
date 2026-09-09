//
//  Country.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

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
