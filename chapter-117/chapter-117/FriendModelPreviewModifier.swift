//
//  FriendModelPreviewModifier.swift
//  chapter-117
//
//  Created by 강준현 on 9/10/26.
//

import Foundation
import SwiftData
import SwiftUI

// TODO: [todos/preview-modifier-and-shared-context.md](../../todos/preview-modifier-and-shared-context.md)
struct FriendModelPreviewModifier: PreviewModifier {
    typealias Context = ModelContainer

    static func makeSharedContext() async throws -> ModelContainer {
        FriendModel.preview
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content
            .modelContainer(context)
    }
}
