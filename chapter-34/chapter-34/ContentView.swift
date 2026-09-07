//
//  ContentView.swift
//  chapter-34
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            Text("Courses").font(.title)
            ForEach(0..<4) { idx in
                CardView(course: DTCourse.sample[idx])
            }
        }
    }
}

struct CardView: View {
    var course: DTCourse
    
    var body: some View {
        VStack {
            Image(course.image)
                .resizable()
                .scaledToFit()
            HStack {
                VStack(alignment: .leading) {
                    Text(course.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(course.title)
                        .font(.title3.bold())
                    HStack {
                        Spacer()
                        Text(course.courseDetail)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
        }
        .clipShape(.rect(cornerRadius: 20))
        // TODO: [todos/overlay-and-shape-fill.md](../../todos/overlay-and-shape-fill.md)
        .overlay(
            content: {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.gray.opacity(0.4), lineWidth: 2)
                    .shadow(color: .red, radius: 4)
            }
        )
        .padding()
    }
}

struct DTCourse: Identifiable {
    let id = UUID()
    var image: ImageResource
    var title: String
    var subtitle: String
    var courseDetail: String
}

// TODO: [todos/extension-keyword.md](../../todos/extension-keyword.md)
extension DTCourse {
    // TODO: [todos/static-type-properties-and-implicit-init.md](../../todos/static-type-properties-and-implicit-init.md)
    static var sample: [DTCourse] {
        [
            .init(
                image: .photo1,
                title: "SwiftUI Bootcamp: Hands-On Project for iOS 18 Development",
                subtitle: "Practical iOS learning",
                courseDetail: "40+ hours of iOS learning content"
            ),
            .init(
                image: .photo2,
                title: "Mastering SwfitData in iOS 18",
                subtitle: "Everything about SwiftData",
                courseDetail: "20+ lessons"
            ),
            .init(
                image: .photo1,
                title: "SwiftUI Bootcamp: Hands-On Project for iOS 18 Development",
                subtitle: "Practical iOS learning",
                courseDetail: "40+ hours of iOS learning content"
            ),
            .init(
                image: .photo2,
                title: "Mastering SwfitData in iOS 18",
                subtitle: "Everything about SwiftData",
                courseDetail: "20+ lessons"
            )
        ]
    }
}

#Preview {
    ContentView()
}
