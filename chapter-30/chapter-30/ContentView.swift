//
//  ContentView.swift
//  chapter-30
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct Course: Identifiable {
    let id = UUID()
    var title: String
    var numberOfLessons: Int
    var image: ImageResource
}

struct ContentView: View {
    @State var courses = [
        Course(
            title: "Mastering CoreImage",
            numberOfLessons: 15,
            image: .photo1
        ),
        Course(
            title: "Mastering WidgetKit",
            numberOfLessons: 18,
            image: .photo2
        ),
    ]

    var body: some View {
        NavigationStack {
            List($courses, editActions: .delete) { $course in
                ListRowView(course: course)
                    // .listRowInsets(
                    //     EdgeInsets(
                    //         top: 20, leading: 20, bottom: 0, trailing: 0
                    //     )
                    // )
                    // .listRowSeparator(.visible, edges: .all)
                    // .listRowSeparatorTint(.red)
                // .listRowBackground(
                //     Ellipse()
                //         .background(.clear)
                //         .foregroundColor(.purple)
                //         .opacity(0.3)
                // )
            }
            // .listStyle(.insetGrouped)
            // .listRowSpacing(10)
            .background {
                Image(.BG)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay {
                        Rectangle()
                            .fill(.black.opacity(0.5))
                            .ignoresSafeArea()
                    }
                    .opacity(0.5)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Courses")
        }
    }
}

struct ListRowView: View {
    let course: Course

    var body: some View {
        HStack {
            Image(course.image)
                .resizable()
                .scaledToFit()
                .frame(width: 50)
            VStack(alignment: .leading) {
                Text(course.title)
                    .font(.headline)
                Text("\(course.numberOfLessons) lessons")
                    .font(.footnote)
            }
        }
    }
}

#Preview {
    ContentView()
}
