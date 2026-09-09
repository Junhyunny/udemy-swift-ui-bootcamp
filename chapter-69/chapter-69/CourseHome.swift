//
//  CourseHome.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CourseHome: View {
    var cart: Cart = Cart()
    var body: some View {
        TabView {
            NavigationView {
                // TODO: [todos/duplicate-id-in-list.md](../../todos/duplicate-id-in-list.md)
                List(Course.sample) { course in
                    ZStack {
                        NavigationLink(
                            destination: CourseDetailView(
                                course: course,
                                cart: cart
                            )
                        ) {
                            EmptyView()
                        }.opacity(0)
                        CourseCardView(course: course)
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .navigationTitle("Jun's Courses")
            }
            .tabItem {
                Label("Courses", systemImage: "list.bullet.circle")
            }
            NavigationView {
                CartView(cart: cart)
            }
            .tabItem {
                Label("Cart", systemImage: "cart.circle")
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    CourseHome()
}
