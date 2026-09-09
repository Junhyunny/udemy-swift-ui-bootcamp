//
//  DoubleExtension.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import Foundation

extension Double {
    func formattedCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}
