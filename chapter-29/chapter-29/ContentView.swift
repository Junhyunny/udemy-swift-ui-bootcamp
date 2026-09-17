//
//  ContentView.swift
//  chapter-29
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

// TODO: [todos/025-identifiable-protocol.md](../../todos/025-identifiable-protocol.md)
// TODO: [todos/020-swift-type-system-and-inheritance.md](../../todos/020-swift-type-system-and-inheritance.md)
struct Courses: Identifiable {
    let id = UUID()
    var title: String
    var numberOfLessons: Int
}

struct ContentView: View {
    // TODO: [todos/043-state-wrapper-type-and-binding.md](../../todos/043-state-wrapper-type-and-binding.md)
    @State var courses = [
        Courses(title: "Mastering CoreImage", numberOfLessons: 15),
        Courses(title: "Mastering WidgetKit", numberOfLessons: 18)
    ]
    var body: some View {
        // TODO: [todos/072-navigation-stack-and-title.md](../../todos/072-navigation-stack-and-title.md)
        NavigationStack {
            List($courses, editActions: .delete) { $course in
                HStack(alignment: .center) {
                    Text(course.title)
                        .font(.headline)
                    Spacer()
                    Text(course.numberOfLessons.description + " lessons")
                        .font(.subheadline)
                }
            }
            .navigationTitle("Junhyunny's Courses")
        }
        NavigationStack {
            List {
                ForEach(courses) { course in
                    HStack(alignment: .center) {
                        Text(course.title)
                            .font(.headline)
                        Spacer()
                        Text(course.numberOfLessons.description + " lessons")
                            .font(.subheadline)
                    }
                }
                // TODO: [todos/008-argument-labels-and-indexset.md](../../todos/008-argument-labels-and-indexset.md)
                .onDelete(perform: delete(at:))
            }
            .navigationTitle("Junhyunny's Second Courses")
        }
    }
    
    // TODO: [todos/008-argument-labels-and-indexset.md](../../todos/008-argument-labels-and-indexset.md)
    // TODO: [todos/045-mutating-and-state-mutation.md](../../todos/045-mutating-and-state-mutation.md)
    func delete(at offsets: IndexSet) {
        print("deleting this offset: ", offsets)
        courses.remove(atOffsets: offsets)
    }
}

#Preview {
    ContentView()
}
