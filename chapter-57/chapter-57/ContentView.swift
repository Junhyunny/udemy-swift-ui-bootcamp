//
//  ContentView.swift
//  chapter-57
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    // TODO: [todos/075-navigation-path-and-typed-array.md](../../todos/075-navigation-path-and-typed-array.md)
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
    // TODO: [todos/073-navigation-stack-vs-navigation-view.md](../../todos/073-navigation-stack-vs-navigation-view.md)
    // TODO: [todos/074-swift-ios-device-compatibility.md](../../todos/074-swift-ios-device-compatibility.md)
    // TODO: [todos/075-navigation-path-and-typed-array.md](../../todos/075-navigation-path-and-typed-array.md)
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
                // TODO: [todos/076-navigation-link-value-and-destination.md](../../todos/076-navigation-link-value-and-destination.md)
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
    // TODO: [todos/016-static-stored-vs-computed-property.md](../../todos/016-static-stored-vs-computed-property.md)
    // FIXME: [Best Practice] 계산 프로퍼티라서 접근할 때마다 새 UUID 를 가진 배열이 만들어진다.
    // - 문제: 위 ContentView 의 path 초기값 exampleData[0], [1] 과 List 가 그리는
    //         exampleData 는 서로 다른 인스턴스다. DevTechieCourse 의 Hashable 합성에는
    //         id(UUID)가 들어가므로 두 값은 절대 같지 않고, 깊은 링크/경로 복원이 어긋난다.
    //         body 가 재평가될 때마다 List 의 모든 행 식별자도 바뀌어 diffing 이 무의미해진다.
    // - 개선: static let exampleData: [DevTechieCourse] = [...] 로 한 번만 만들어 공유한다.
    //         샘플 데이터가 id 를 고정해야 한다면 UUID 대신 안정적인 문자열 id 를 쓴다.
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
