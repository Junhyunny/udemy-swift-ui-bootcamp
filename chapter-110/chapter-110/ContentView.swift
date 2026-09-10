//
//  ContentView.swift
//  chapter-110
//
//  Created by 강준현 on 9/10/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {

    @Environment(\.modelContext) var modelContext
    // TODO: [todos/swiftdata-query-and-debugging.md](../../todos/swiftdata-query-and-debugging.md)
    // TODO: [todos/swiftdata-relationships-and-fetching.md](../../todos/swiftdata-relationships-and-fetching.md)
    @Query private var groceries: [Grocery]

    var body: some View {
        // TODO: [todos/swiftdata-container-context-and-configuration.md](../../todos/swiftdata-container-context-and-configuration.md)
        // Text(modelContext.container.configurations.debugDescription)
        CreateNewGroceryView()
        List(groceries) { grocery in
            VStack(alignment: .leading) {
                Text(grocery.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(grocery.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
