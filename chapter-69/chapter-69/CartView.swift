//
//  CartView.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CartView: View {

    @ObservedObject var cart: Cart
    @State private var isPresented: Bool = false

    var body: some View {
        if cart.courses.isEmpty {
            Text("Your cart is empty. Let's add something here")
                .foregroundStyle(.secondary)
                .navigationTitle("Cart")
        } else {
            ZStack(alignment: .bottom) {
                List {
                    ForEach(cart.courses) { course in
                        Text(course.title)
                    }
                    .onDelete { idSet in cart.deleteCourse(idSet: idSet) }
                }
                Button(action: {
                    isPresented.toggle()
                }) {
                    Label("Checkout", systemImage: "dollarsign.circle")
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 2))
                        .foregroundStyle(.white)
                        .contentShape(Rectangle())
                }
                // TODO: [todos/sheet-ondismiss-and-result.md](../../todos/sheet-ondismiss-and-result.md)
                // FIXME: [Best Practice] onDismiss 에서 결제 성공 여부와 무관하게 장바구니를 비운다.
                // - 문제: 사용자가 결제를 취소하고 시트를 내려도(스와이프 포함) 담아둔 강의가 전부 날아간다.
                // - 개선: CheckoutView 가 결제 결과를 @Binding 이나 콜백으로 돌려주게 하고,
                //         성공일 때만 cart.courses 를 비운다.
                .sheet(isPresented: $isPresented) {
                    cart.courses = []
                } content: {
                    CheckoutView(cart: cart)
                }
            }
            .navigationTitle("Cart")
        }
    }
}

#Preview {
    CartView(cart: Cart())
}
