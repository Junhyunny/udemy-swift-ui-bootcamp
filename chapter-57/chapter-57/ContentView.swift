//
//  ContentView.swift
//  chapter-57
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    // TODO: [todos/navigation-path-and-typed-array.md](../../todos/navigation-path-and-typed-array.md)
    @State private var path: [DevTechieCourse] = [
        DevTechieCourse.exampleData[0],
        DevTechieCourse.exampleData[1],
    ]
    var body: some View {
        NavigationStack(path: $path) {
            List(DevTechieCourse.exampleData) { course in
                NavigationLink(course.title, value: course)
            }
            .navigationDestination(for: DevTechieCourse.self) { value in
                Text(value.title)
            }
            .navigationTitle(Text("Navigation Example"))
        }
    }
}

struct NavigationStateExample: View {
    // TODO: [todos/navigation-stack-vs-navigation-view.md](../../todos/navigation-stack-vs-navigation-view.md)
    // TODO: [todos/swift-ios-device-compatibility.md](../../todos/swift-ios-device-compatibility.md)
    // TODO: [todos/navigation-path-and-typed-array.md](../../todos/navigation-path-and-typed-array.md)
    @State private var path = NavigationPath()
    var body: some View {
        // NavigationView {
        //     List {
        //         Text("Mastering SwiftUI")
        //         Text("Mastering iOS machine learning")
        //     }
        //     .navigationTitle(Text("DevTechie courses"))
        // }
        NavigationStack(path: $path) {
            List {
                // TODO: [todos/navigation-link-value-and-destination.md](../../todos/navigation-link-value-and-destination.md)
                NavigationLink(value: "Mastering iOS and UIKit") {
                    Text("Mastering iOS and UIKit")
                }
                NavigationLink("Mastering SwiftUI", value: Color.orange)
                Text("Mastering iOS machine learning")
            }
            .navigationTitle(Text("DevTechie courses"))
            .navigationDestination(
                for: String.self,
                destination: { title in
                    Text(title)
                    NavigationLink(
                        "Mastering Machine Learning in iOS",
                        value: "Mastering Machine Learning in iOS"
                    )
                    Button("Pop to root") {
                        path = NavigationPath()
                    }
                    .buttonStyle(.borderedProminent)
                }
            )
            .navigationDestination(for: Color.self) { value in
                Text("DevTechie")
                    .font(.largeTitle)
                    .foregroundStyle(value)
            }
        }
    }
}

struct DevTechieCourse: Identifiable, Hashable {
    let id = UUID()
    let title: String
}

extension DevTechieCourse {
    // TODO: [todos/static-stored-vs-computed-property.md](../../todos/static-stored-vs-computed-property.md)
    static var exampleData: [DevTechieCourse] {
        return [
            .init(title: "Mastering SwiftUI"),
            .init(title: "Build Disney Plus clone in SwiftUI"),
            .init(title: "Build Viedeo Player App in SwiftUI"),
        ]
    }
}

#Preview {
    ContentView()
}
