//
//  ContentView.swift
//  chapter-04
//
//  Created by 강준현 on 9/3/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 40) {
            Text("Hello, world!").foregroundStyle(Color.orange)
            Text("One place to learn all about iOS development")
            Text("Learn SwiftUI")
            Text("Learn SwiftUI")
        }
        .foregroundStyle(.secondary)
        .border(Color.black)
    }
}

#Preview {
    ContentView()
}
