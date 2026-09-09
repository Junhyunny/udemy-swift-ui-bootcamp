//
//  Course.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//
// TODO: [todos/foundation-framework.md](../../todos/foundation-framework.md)
import Foundation

struct Course: Identifiable {
    let id = UUID().uuidString
    var title: String
    var category: Category
    var duration: String
    var publishedDate: Date
    var description: String
    var price: Double
}

extension Course {
    static var sample: [Course] {
        [
            Course(
                title: "SwiftUI in Depth",
                category: .swiftUI,
                duration: "12h 20m",
                publishedDate: Date(),
                description:
                    "SwiftUI Course to explore all there is to know about SwiftUI including the latest released version of SwiftUI 3",
                price: 13.99
            ),
            Course(
                title: "Machine Learning in Depth",
                category: .machineLeanring,
                duration: "5h 10m",
                publishedDate: Date(),
                description: "iOS Machine Learning Course",
                price: 7.99
            ),
            Course(
                title: "What is new in iOS 15 and Swift 5.5",
                category: .swift,
                duration: "4h 50m",
                publishedDate: Date(),
                description: "New in iOS 15 and Swift 5.5",
                price: 10.99
            ),
        ]
    }
}
