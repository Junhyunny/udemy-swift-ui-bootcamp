//
//  ContentView.swift
//  chapter-10
//
//  Created by 강준현 on 9/5/26.
//

internal import Combine
import SwiftUI

final class CartViewModel: ObservableObject {
    @Published var items = ["Bread", "Milk"]
}

struct CartView: View {
    @ObservedObject var cart: CartViewModel
    var body: some View {
        List(cart.items, id: \.self) { item in
            Text(item)
        }
    }
}

struct ContentView: View {
    @StateObject var cart: CartViewModel = CartViewModel()
    var body: some View {
        CartView(cart: cart)
    }
}

#Preview {
    ContentView()
}
