//
//  ContentView.swift
//  chapter-60
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct DevTechieCourse: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    // TODO: [todos/hash-into-and-java-comparison.md](../../todos/hash-into-and-java-comparison.md)
    // func hash(into hasher: inout Hasher) {
    //     hasher.combine(id)
    // }
}

extension DevTechieCourse {
    static var sample: [DevTechieCourse] {
        return [
            .init(name: "Mastering SwiftData by Example in SwiftUI & iOS 18"),
            .init(name: "Mastering Machine Learning in iOS with SwiftUI"),
            .init(name: "Background Timer App in SwiftUI"),
            .init(name: "iOS 18 Healthkit Dashboard in SwiftUI"),
            .init(name: "Build a powerful document scanner with SwiftUI"),
        ]
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(DevTechieCourse.sample) { course in
                NavigationLink(course.name, value: course)
            }
            .listStyle(.plain)
            .navigationTitle("Courses")
            .navigationDestination(
                for: DevTechieCourse.self,
                destination: { course in
                    DestinationView(title: course.name)
                }
            )
        }
    }
}

struct DestinationView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    // TODO: [todos/some-keyword-opaque-types.md](../../todos/some-keyword-opaque-types.md)
    var body: some View {
        Text(title)
            .navigationBarBackButtonHidden()
            .onTapGesture {
                dismiss()
            }
    }
}

#Preview {
    ContentView()
}
