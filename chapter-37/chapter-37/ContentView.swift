//
//  ContentView.swift
//  chapter-37
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // Label("junhyunny.com", systemImage: "star.fill")
        // Label("junhyunny.com", image: .photo1) // 이 방식은 사이즈 지정이 안 된다.
        Label {
            Text("junhyunny.com")
        } icon: {
            Image(.photo1)
                .resizable()
                .scaledToFit()
                .frame(height: 45)
                .clipShape(.circle)
        }
        // .labelStyle(
        //     CustomLabelStyle(
        //         iconColor: .red,
        //         titleColor: .blue,
        //         backgroundColor: .yellow
        //     )
        // )
        .labelStyle(.automatic)
        
        List {
            Text("Dev Courses")
                .font(.largeTitle)
            HStack {
                Image(systemName: "person.circle")
                Text("Mastering SwfitUI")
            }
            HStack {
                Image(systemName: "envelope")
                Text("SwiftUI Deep Dive")
            }
            HStack {
                Image(systemName: "calendar.day.timeline.right")
                Text("Core Image with SwiftUI")
            }
        }
        
        List {
            Text("Dev Courses")
                .font(.largeTitle)
            Label {
                Text("Mastering SwfitUI")
            } icon: {
                Image(systemName: "person.circle")
            }
            Label {
                Text("SwiftUI Deep Dive")
            } icon: {
                Image(systemName: "envelope")
            }
            Label {
                Text("Mastering SwfitUI")
            } icon: {
                Image(systemName: "calendar.day.timeline.right")
            }
        }
    }
}

struct CustomLabelStyle: LabelStyle {
    let iconColor: Color
    let titleColor: Color
    let backgroundColor: Color

    /*
     @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
     @MainActor @preconcurrency public protocol LabelStyle {

         /// A view that represents the body of a label.
         associatedtype Body : View

         /// Creates a view that represents the body of a label.
         ///
         /// The system calls this method for each ``Label`` instance in a view
         /// hierarchy where this style is the current label style.
         ///
         /// - Parameter configuration: The properties of the label.
         @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Self.Configuration) -> Self.Body

         /// The properties of a label.
         typealias Configuration = LabelStyleConfiguration
     }
     */
    // TODO: [todos/protocol-requirements-and-style-protocols.md](../../todos/protocol-requirements-and-style-protocols.md)
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center) {
            configuration.icon
                .foregroundStyle(iconColor.gradient)
            configuration.title
                .foregroundStyle(titleColor.gradient)
                .font(.title2)
            configuration.icon
                .foregroundStyle(iconColor.gradient)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 45)
                .fill(backgroundColor.gradient)
        )
    }
}

#Preview {
    ContentView()
}
