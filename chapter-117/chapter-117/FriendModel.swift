//
//  File.swift
//  chapter-117
//
//  Created by 강준현 on 9/10/26.
//

import Foundation
import SwiftData

@Model
final class FriendModel {
    var firstName: String
    var lastName: String

    init(firstName: String, lastName: String) {
        self.firstName = firstName
        self.lastName = lastName
    }
}

extension FriendModel {
    @MainActor
    static var preview: ModelContainer {
        // FIXME: [Best Practice] try! 강제 실행. 실패 원인을 남기지 않고 즉시 크래시한다.
        // - 개선: do/catch 로 감싸 실패 이유를 메시지에 담는다. (chapter-115 Todo.swift 와 동일 이슈)
        let container = try! ModelContainer(
            for: FriendModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        container.mainContext.insert(
            FriendModel(firstName: "John", lastName: "Doe")
        )
        container.mainContext.insert(
            FriendModel(firstName: "Jane", lastName: "Smith")
        )
        container.mainContext.insert(
            FriendModel(firstName: "Mike", lastName: "Johnson")
        )
        container.mainContext.insert(
            FriendModel(firstName: "Bob", lastName: "Brown")
        )
        return container
    }
}
