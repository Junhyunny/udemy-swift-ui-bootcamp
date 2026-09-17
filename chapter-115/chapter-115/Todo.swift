//
//  Todo.swift
//  chapter-115
//
//  Created by 강준현 on 9/10/26.
//

import Foundation
import SwiftData

// TODO: [todos/037-swift-macros-and-build-pipeline.md](../../todos/037-swift-macros-and-build-pipeline.md)
// TODO: [todos/129-swiftdata-identity-and-updates.md](../../todos/129-swiftdata-identity-and-updates.md)
@Model
final class Todo {
    var title: String
    var isCompleted: Bool

    init(title: String, isCompleted: Bool) {
        self.title = title
        self.isCompleted = isCompleted
    }
}

extension Todo {

    @MainActor
    static var mock: ModelContainer {
        // FIXME: [Best Practice] try! 는 실패 시 무조건 크래시다.
        // - 참고: Preview 전용 코드라 실무 영향은 작지만, 같은 패턴이 앱 본체로 복사되기 쉽다.
        // - 개선: do/catch 로 감싸고 실패 시 fatalError("...구체적 원인: \(error)") 처럼
        //         원인을 남기거나, Preview 라면 빈 컨테이너로 폴백한다.
        let container = try! ModelContainer(
            for: Todo.self,
            // TODO: [todos/127-swiftdata-container-context-and-configuration.md](../../todos/127-swiftdata-container-context-and-configuration.md)
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // TODO: [todos/132-swiftdata-concurrency-and-context-isolation.md](../../todos/132-swiftdata-concurrency-and-context-isolation.md)
        // TODO: [todos/037-swift-macros-and-build-pipeline.md](../../todos/037-swift-macros-and-build-pipeline.md)
        container.mainContext.insert(Todo(title: "Hello", isCompleted: false))
        container.mainContext.insert(Todo(title: "World", isCompleted: true))
        container.mainContext.insert(
            Todo(title: "Junhyunny", isCompleted: false)
        )
        return container
    }
}
