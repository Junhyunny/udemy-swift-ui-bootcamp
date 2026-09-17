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
            // FIXME: [Best Practice] 인덱스 하드코딩(0..<4) + 매 반복마다 계산 프로퍼티 재호출.
            // - 문제: DTCourse.sample 은 계산 프로퍼티라 4번 접근하면 배열을 4번 새로 만든다.
            //         또 샘플 개수가 바뀌면 0..<4 가 범위를 벗어나 크래시한다.
            // - 개선: static let sample 으로 바꾸고 ForEach(DTCourse.sample) { course in ... } 처럼
            //         Identifiable 컬렉션을 직접 순회한다.
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
        // TODO: [todos/060-overlay-and-shape-fill.md](../../todos/060-overlay-and-shape-fill.md)
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

// TODO: [todos/014-extension-keyword.md](../../todos/014-extension-keyword.md)
extension DTCourse {
    // TODO: [todos/015-static-type-properties-and-implicit-init.md](../../todos/015-static-type-properties-and-implicit-init.md)
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
