//
//  ViewModel.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Combine
import Foundation
import Observation

@Observable
final class ViewModel {
    var exchangeRate: ExchangeRate? = nil
    // TODO: [todos/combine-cancellable-and-store.md](../../todos/combine-cancellable-and-store.md)
    private var cancellableSet: Set<AnyCancellable> = []

    init() {
        fetchRates()
    }

    func fetchRates() {
        ExchangeRateService.shared.getExchangeRate()
            // TODO: [todos/combine-operators.md](../../todos/combine-operators.md)
            .replaceError(with: ExchangeRate.placeholder)
            // TODO: [todos/weak-self-and-deinit.md](../../todos/weak-self-and-deinit.md)
            .sink { [weak self] in
                print($0)
                self?.exchangeRate = $0
            }
            // TODO: [todos/combine-cancellable-and-store.md](../../todos/combine-cancellable-and-store.md)
            .store(in: &cancellableSet)
    }

    // TODO: [todos/weak-self-and-deinit.md](../../todos/weak-self-and-deinit.md)
    deinit {
        cancellableSet.forEach { $0.cancel() }
    }
}

extension ViewModel {
    func validateOutput() -> [Dictionary<String, Double>.Keys.Element] {
        guard let output = exchangeRate?.rates?.keys.sorted() else {
            return []
        }
        return output
    }

    func emojiFlag(_ currencyCode: String) -> String {
        guard let country = Country.getCountryBy(currencyCode: currencyCode)
        else {
            return
                // TODO: [todos/flag-emoji-from-unicode-scalars.md](../../todos/flag-emoji-from-unicode-scalars.md)
                currencyCode
                .dropLast()
                .unicodeScalars
                .map({ 127397 + $0.value })
                .compactMap(UnicodeScalar.init)
                .map(String.init)
                .joined()
        }
        return country.flagEmoji
    }

    func countryName(_ currencyCode: String) -> String? {
        Country.getCountryBy(currencyCode: currencyCode)?.countryName
    }

    func formatRateForLocale(for key: String) -> String {
        guard let mainRates = exchangeRate?.rates else { return "" }
        let rate = mainRates[key] ?? 1.0
        // TODO: [todos/computed-property-with-closure-body.md](../../todos/computed-property-with-closure-body.md)
        var formatter: NumberFormatter {
            let fm = NumberFormatter()
            fm.numberStyle = .currency
            fm.locale = Locale(
                identifier: key.dropLast() + "_" + key.dropLast().uppercased()
            )
            return fm
        }
        return formatter.string(from: NSNumber(value: rate))!
    }
}
