//
//  ContentView.swift
//  chapter-58
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    @State private var counter = 0
    @State private var triggerAnimation = false
    @State private var selected: Int? = 0
    var body: some View {
        // FIXME: [Best Practice] NavigationView 는 iOS 16 에서 deprecated 되었다.
        // - 개선: NavigationStack(path:) + navigationDestination(for:) 으로 옮긴다.
        //         아래의 NavigationLink(_:destination:isActive:) 와
        //         NavigationLink(_:destination:tag:selection:) 도 같은 시점에 deprecated 되었으며,
        //         상태 기반 이동은 path 배열에 값을 append/remove 하는 방식으로 대체한다.
        NavigationView {
            VStack {
                Text("Hello World")
                    .font(.largeTitle)
                Button("Increase count") {
                    counter += 1
                }
                .buttonStyle(.bordered)
                // NavigationLink {
                //     // Destination
                //     // Text("You reached here via NavigationLink")
                //     NavigationDestinationView(counter: counter)
                // } label: {
                //     Label("Click Me", systemImage: "computermouse")
                // }
                // TODO: [todos/077-deprecated-navigation-link-initializers.md](../../todos/077-deprecated-navigation-link-initializers.md)
                NavigationLink(
                    "Click Me",
                    destination: NavigationDestinationView(counter: counter),
                    isActive: $triggerAnimation
                )
                .padding()
                Button("Trigger Navigation") {
                    triggerAnimation.toggle()
                }
                VStack {
                    // TODO: [todos/077-deprecated-navigation-link-initializers.md](../../todos/077-deprecated-navigation-link-initializers.md)
                    NavigationLink(
                        "View 1",
                        destination: Text("View 1")
                            .navigationBarBackButtonHidden(),
                        tag: 1,
                        selection: $selected
                    )
                    NavigationLink(
                        "View 2",
                        destination: Text("View 2"),
                        tag: 2,
                        selection: $selected
                    )
                    NavigationLink(
                        "View 3",
                        destination: DestView(title: "View 3"),
                        tag: 3,
                        selection: $selected
                    )
                }
                .padding()
                .buttonStyle(.bordered)
                HStack {
                    Button("Trigger 1") {
                        selected = 1
                    }
                    Button("Trigger 2") {
                        selected = 2
                    }
                    Button("Trigger 3") {
                        selected = 3
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("NavigationLink Example")
        }
    }
}

struct DestView: View {
    // TODO: [todos/048-environment-property-wrapper.md](../../todos/048-environment-property-wrapper.md)
    @Environment(\.dismiss) var dismiss
    var title: String
    var body: some View {
        Text(title)
            .navigationBarBackButtonHidden()
            .font(.largeTitle)
            .onTapGesture { _ in
                dismiss()
            }
    }
}

struct NavigationDestinationView: View {
    var counter: Int
    var body: some View {
        Text("Destination View \(counter)")
            .navigationTitle(Text("Destination View"))
            .navigationBarBackButtonHidden()
    }
}

#Preview {
    ContentView()
}
