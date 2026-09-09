//
//  CourseCardView.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CourseCardView: View {
    var course: Course

    var body: some View {
        VStack(alignment: .leading) {
            Text(course.title)
                .bold()
                .font(.title2)
            Text(course.description)
                .lineLimit(2)
            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                Text(course.duration)
                Circle()
                    .frame(width: 10, height: 10)
                // TODO: [todos/enum-raw-values.md](../../todos/enum-raw-values.md)
                Text(course.category.rawValue)
                    .lineLimit(1)
                Circle()
                    .frame(width: 10, height: 10)
                Text(course.publishedDate.formatted(date: .abbreviated, time: .omitted))
                Spacer()
            }
            .padding(.top, 10)
            .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).stroke(.gray))
    }
}

#Preview {
    CourseCardView(course: Course.sample[0])
}
