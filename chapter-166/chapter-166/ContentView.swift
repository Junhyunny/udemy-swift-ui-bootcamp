//
//  ContentView.swift
//  chapter-166
//
//  Created by 강준현 on 9/16/26.
//

import Observation
import SwiftUI

struct ContentView: View {

    @State private var model = CourseStore()
    @State private var selectedCourses: Set<String> = []

    var body: some View {
        NavigationStack {
            List(selection: $selectedCourses) {
                ForEach(model.data) { course in
                    HStack {
                        Text(course.emoji)
                        Text(course.name)
                    }
                    .selectionDisabled(!course.published)
                }
            }
            .navigationTitle("Jun Examples")
            // TODO: [todos/toolbar-api-use-cases.md](../../todos/toolbar-api-use-cases.md)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // TODO: [todos/builtin-swiftui-buttons.md](../../todos/builtin-swiftui-buttons.md)
                    EditButton()
                }
            }
        }
    }
}

struct CourseModel: Identifiable, Hashable {
    var name: String
    var published: Bool
    var emoji: String
    var id: String {
        name
    }
}

@Observable
class CourseStore {
    var data: [CourseModel] = [
        CourseModel(
            name: "SwiftUI 기초",
            published: true,
            emoji: "🍎"
        ),
        CourseModel(
            name: "Swift Concurrency",
            published: true,
            emoji: "⚡️"
        ),
        CourseModel(
            name: "iOS Networking",
            published: false,
            emoji: "🌐"
        ),
        CourseModel(
            name: "Core Data",
            published: false,
            emoji: "💾"
        ),
        CourseModel(
            name: "Testing in iOS",
            published: true,
            emoji: "🧪"
        ),
    ]
}

#Preview {
    ContentView()
}
