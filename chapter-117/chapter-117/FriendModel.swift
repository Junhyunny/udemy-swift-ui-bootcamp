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
