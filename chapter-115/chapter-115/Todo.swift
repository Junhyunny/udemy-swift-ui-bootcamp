//
//  Todo.swift
//  chapter-115
//
//  Created by 강준현 on 9/10/26.
//

import Foundation
import SwiftData

// TODO: [todos/swift-macros-and-build-pipeline.md](../../todos/swift-macros-and-build-pipeline.md)
// TODO: [todos/swiftdata-identity-and-updates.md](../../todos/swiftdata-identity-and-updates.md)
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
        let container = try! ModelContainer(
            for: Todo.self,
            // TODO: [todos/swiftdata-container-context-and-configuration.md](../../todos/swiftdata-container-context-and-configuration.md)
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // TODO: [todos/swiftdata-concurrency-and-context-isolation.md](../../todos/swiftdata-concurrency-and-context-isolation.md)
        // TODO: [todos/swift-macros-and-build-pipeline.md](../../todos/swift-macros-and-build-pipeline.md)
        container.mainContext.insert(Todo(title: "Hello", isCompleted: false))
        container.mainContext.insert(Todo(title: "World", isCompleted: true))
        container.mainContext.insert(
            Todo(title: "Junhyunny", isCompleted: false)
        )
        return container
    }
}
