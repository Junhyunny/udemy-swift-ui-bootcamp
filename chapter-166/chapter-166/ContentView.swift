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
    // FIXME: [Best Practice] 표시용 이름(name)을 그대로 식별자로 쓰고 있다.
    // - 문제: 강의명이 겹치면 id 가 충돌해 List/ForEach 가 행을 뒤섞고,
    //         이름을 수정하는 순간 선택 상태(selectedCourses)가 통째로 풀린다.
    // - 개선: let id = UUID() 나 서버가 주는 불변 식별자를 따로 둔다.
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
