//
//  chapter_115App.swift
//  chapter-115
//
//  Created by 강준현 on 9/10/26.
//

import SwiftUI
import SwiftData

@main
struct chapter_115App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Todo.self)
    }
}
