//
//  ContentView.swift
//  chapter-115
//
//  Created by 강준현 on 9/10/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    // TODO: [todos/swiftdata-preview-mock-container.md](../../todos/swiftdata-preview-mock-container.md)
    @Environment(\.modelContext) var modelContext
    @Query var todos: [Todo]
    var body: some View {
        NavigationStack {
            VStack {
                List(todos) { todo in
                    Text(todo.title)
                        .font(.title)
                        .strikethrough(
                            todo.isCompleted,
                            pattern: .dash,
                            color: .red
                        )
                }
                Button("Add") {
                    modelContext.insert(Todo(title: "World", isCompleted: false))
                }
            }
            .navigationTitle("To Do List")
        }
    }
}

#Preview {
    ContentView()
        // TODO: [todos/swiftdata-preview-mock-container.md](../../todos/swiftdata-preview-mock-container.md)
        .modelContainer(Todo.mock)
}
