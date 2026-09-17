//
//  Course.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//
// TODO: [todos/foundation-framework.md](../../todos/foundation-framework.md)
import Foundation

// FIXME: [Architecture] 모델이 데이터 공급까지 겸하고, View 가 그것을 직접 참조한다.
// - 현상: Course.sample 을 CourseHome 의 List 와 CourseDetailView 의 '관련 강의' 목록이
//         각각 직접 읽는다. 데이터 출처가 화면 코드에 하드코딩된 셈이다.
// - 문제: 목록을 서버에서 받아오게 바꾸는 순간 두 화면을 모두 고쳐야 한다.
//         '같은 카테고리 강의 찾기' 같은 규칙도 View 의 ForEach 안 if 문으로 흩어져 있다.
// - 개선: protocol CourseRepository { func allCourses() -> [Course]; func related(to: Course) -> [Course] }
//         를 두고 ViewModel 이 주입받게 한다. 화면은 완성된 배열만 받는다.
//         (chapter-80 Country.swift 에도 같은 구조 문제가 있다)
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
