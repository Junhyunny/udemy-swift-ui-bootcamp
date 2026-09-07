//
//  ContentView.swift
//  chapter-29
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

// TODO: [todos/identifiable-protocol.md](../../todos/identifiable-protocol.md)
// TODO: [todos/swift-type-system-and-inheritance.md](../../todos/swift-type-system-and-inheritance.md)
struct Courses: Identifiable {
    let id = UUID()
    var title: String
    var numberOfLessons: Int
}

struct ContentView: View {
    // TODO: [todos/state-wrapper-type-and-binding.md](../../todos/state-wrapper-type-and-binding.md)
    @State var courses = [
        Courses(title: "Mastering CoreImage", numberOfLessons: 15),
        Courses(title: "Mastering WidgetKit", numberOfLessons: 18)
    ]
    var body: some View {
        // TODO: [todos/navigation-stack-and-title.md](../../todos/navigation-stack-and-title.md)
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
                // TODO: [todos/argument-labels-and-indexset.md](../../todos/argument-labels-and-indexset.md)
                .onDelete(perform: delete(at:))
            }
            .navigationTitle("Junhyunny's Second Courses")
        }
    }
    
    // TODO: [todos/argument-labels-and-indexset.md](../../todos/argument-labels-and-indexset.md)
    // TODO: [todos/mutating-and-state-mutation.md](../../todos/mutating-and-state-mutation.md)
    func delete(at offsets: IndexSet) {
        print("deleting this offset: ", offsets)
        courses.remove(atOffsets: offsets)
    }
}

#Preview {
    ContentView()
}
