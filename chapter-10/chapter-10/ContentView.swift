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
        // FIXME: [Best Practice] 문자열 값 자체를 식별자로 쓰고 있다.
        // - 문제: 같은 이름의 항목("Milk")이 두 개 들어오면 ID 가 충돌해 SwiftUI 가 행을 잘못 재사용한다.
        //         항목 이름을 수정하면 "다른 행"으로 취급되어 애니메이션이 튄다.
        // - 개선: 항목을 Identifiable struct 로 감싸 고유 id 를 부여한다.
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
