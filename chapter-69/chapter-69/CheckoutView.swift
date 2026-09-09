//
//  CheckoutView.swift
//  chapter-69
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

struct CheckoutView: View {
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
