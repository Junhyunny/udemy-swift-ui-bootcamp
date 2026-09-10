//
//  chapter_110App.swift
//  chapter-110
//
//  Created by 강준현 on 9/10/26.
//

import SwiftUI
import SwiftData

@main
struct chapter_110App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // TODO: [todos/swiftdata-container-context-and-configuration.md](../../todos/swiftdata-container-context-and-configuration.md)
        // TODO: [todos/swiftdata-storage-security-and-performance.md](../../todos/swiftdata-storage-security-and-performance.md)
        .modelContainer(for: Grocery.self)
    }
}
