//
//  CourseHome.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CourseHome: View {
    // FIXME: [Best Practice] View 의 일반 저장 프로퍼티로 참조 타입(Cart)을 소유하고 있다.
    // - 문제: View 는 struct 라 재생성될 때마다 새 Cart() 가 만들어질 수 있고,
    //         프로퍼티 래퍼가 없어 @Published 변경을 구독하지도 않는다.
    //         장바구니 담기가 화면에 반영되지 않거나 조용히 사라질 수 있다.
    // - 개선: @StateObject private var cart = Cart() 로 소유권을 명확히 하고,
    //         하위 뷰에는 @ObservedObject 또는 .environmentObject 로 전달한다.
    //         iOS 17+ 라면 @Observable + @State 조합이 더 낫다.
    var cart: Cart = Cart()
    var body: some View {
        TabView {
            // FIXME: [Best Practice] NavigationView 는 iOS 16 deprecated.
            // - 개선: NavigationStack 으로 교체한다. 아래 Cart 탭의 NavigationView 도 동일하다.
            NavigationView {
                // TODO: [todos/054-duplicate-id-in-list.md](../../todos/054-duplicate-id-in-list.md)
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
