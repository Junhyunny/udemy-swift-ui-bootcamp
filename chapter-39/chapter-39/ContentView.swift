//
//  ContentView.swift
//  chapter-39
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    @State private var agreePrivacy: Bool = false
    @State private var car = false
    @State private var plane = false
    @State private var bike = false
    var body: some View {
        VStack {
            Text("Please accept our terms of use and privacy policies")
                .font(.largeTitle)
            Toggle(isOn: $agreePrivacy) {
                Text("Terms of use & Privacy")
            }
            Button("Submit") {
                print("submit")
            }
            .disabled(!agreePrivacy)
        }
        .padding()
        HStack {
            Toggle("Car", isOn: $car)
            Toggle("Plane", isOn: $plane)
            Toggle("Bike", isOn: $bike)
        }
        .toggleStyle(.button)
    }
}

#Preview {
    ContentView()
}
