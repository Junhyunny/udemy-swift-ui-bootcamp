//
//  CourseDetailView.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CourseDetailView: View {

    var course: Course
    // FIXME: [Architecture] 공유 상태를 화면 계층마다 손으로 넘겨주는 prop drilling 구조다.
    // - 현상: CourseHome 이 만든 Cart 를 CourseDetailView, CartView, CheckoutView 까지
    //         생성자 인자로 계속 전달한다. 중간 화면은 Cart 가 필요 없어도 통로 역할을 해야 한다.
    // - 문제: 화면이 하나 늘 때마다 모든 중간 단계의 시그니처가 바뀐다.
    //         게다가 여기서는 @ObservedObject 없이 받아서 변경 알림도 못 받는다.
    // - 개선: 앱 전역에서 하나만 존재하는 상태이므로 .environmentObject(cart) 로 주입하고
    //         필요한 화면만 @EnvironmentObject var cart: Cart 로 꺼내 쓴다.
    //         iOS 17+ 라면 @Observable + .environment(cart) / @Environment(Cart.self) 조합을 쓴다.
    var cart: Cart
    // TODO: [todos/079-presentation-mode-vs-dismiss.md](../../todos/079-presentation-mode-vs-dismiss.md)
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                Image("DT_Dark")
                    .resizable()
                    .scaledToFit()
                    .blur(radius: 5)
                Text(course.title)
                    .bold()
                    .font(.title)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
            VStack(alignment: .leading) {
                Text(course.description)
                listItem(item: course.duration)
                listItem(item: course.category.rawValue)
                listItem(
                    item: course.publishedDate.formatted(
                        date: .abbreviated,
                        time: .omitted
                    )
                )
                listItem(item: course.price.formattedCurrency())
            }
            .padding()
            Text("Related Courses").bold()
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Course.sample) { relatedCourse in
                        if relatedCourse.category == course.category {
                            Text(relatedCourse.title)
                                .frame(width: 100, height: 100)
                                .padding()
                                .background(
                                    .ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 30)
                                )
                        }
                    }
                }
            }
            Spacer()
            Button(action: {
                cart.addCourse(course: course)
                presentationMode.wrappedValue.dismiss()
            }) {
                Label("Add to Cart for \(course.price.formattedCurrency())", systemImage: "cart")
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 2))
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
            }
            .padding(.bottom)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func listItem(item: String) -> some View {
        HStack {
            Circle()
                .frame(width: 10, height: 10)
            Text(item)
        }
    }
}

#Preview {
    CourseDetailView(course: Course.sample[2], cart: Cart())
}
