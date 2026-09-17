//
//  CheckoutView.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CheckoutView: View {
    // FIXME: [Best Practice] presentationMode 는 iOS 15 부터 dismiss 로 대체되었다.
    // - 개선: @Environment(\.dismiss) private var dismiss 로 바꾸고 dismiss() 를 호출한다.
    //         (CourseDetailView.swift 에도 같은 패턴이 있다)
    @Environment(\.presentationMode) var presentationMode
    var cart: Cart
    let paymentTypes = ["Cash", "Card", "Paypal"]
    @State private var seletedIndex = 0
    @State private var completePayment = false

    var body: some View {
        NavigationView {
            Form {
                Section("Cart") {
                    List(cart.courses) { course in
                        HStack {
                            Text(course.title)
                            Spacer()
                            Text(course.price.formattedCurrency())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                // FIXME: [Best Practice] 합계 계산 로직(reduce)이 body 안에 두 번 중복되어 있다.
                //        (여기와 아래 alert message)
                // - 문제: 계산식이 갈라지면 화면에 보이는 금액과 안내 문구의 금액이 달라진다.
                // - 개선: Cart 에 var totalPrice: Double { courses.reduce(0) { $0 + $1.price } } 를 두고 공유한다.
                Section("Total") {
                    HStack {
                        Text("Total amount")
                        Spacer()
                        Text(
                            cart.courses.reduce(
                                0,
                                { acc, current in acc + current.price }
                            ).formattedCurrency()
                        )
                    }
                }
                Section("Payment") {
                    Picker("Payment mode", selection: $seletedIndex) {
                        ForEach(paymentTypes.indices, id: \.self) { index in
                            Text(paymentTypes[index]).tag(index)
                        }
                    }
                }
                Section("Pay") {
                    Button(action: {
                        completePayment.toggle()
                    }) {
                        Label(
                            "Pay with \(paymentTypes[seletedIndex])",
                            systemImage: "dollarsign.square"
                        )
                    }
                    .alert("Thank you!", isPresented: $completePayment) {
                        Button("OK", role: .cancel) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    } message: {
                        Text(
                            """
                            Your \(paymentTypes[seletedIndex]) payment has been received!
                            Total amount is \(cart.courses.reduce(0, { $0 + $1.price}).formattedCurrency())
                            """
                        )
                    }
                }
            }
            .navigationTitle("Checkout")
        }
    }
}

#Preview {
    CheckoutView(cart: Cart())
}
