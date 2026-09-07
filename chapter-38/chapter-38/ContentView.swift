//
//  ContentView.swift
//  chapter-38
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var tipAmount = 10.0
    var body: some View {
        VStack {
            Text("Set tip amount")
            Text("Tip \(tipAmount.formatted(.currency(code: "usd")))")
            Slider(value: $tipAmount, in: 5...100)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
