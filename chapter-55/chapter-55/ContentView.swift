//
//  ContentView.swift
//  chapter-55
//
//  Created by 강준현 on 9/8/26.
//

import SwiftUI

struct ContentView: View {
    @State private var animate = false
    var dtArray = ["d", "e", "v", "t", "e", "c", "h", "i", "e"]
    var body: some View {
        NavigationStack {
            PhaseAnimator(dtArray, trigger: animate) { char in
                ZStack {
                     Circle()
                        .fill(.orange.gradient.opacity(0.5))
                        .frame(width: 200)
                    Image(systemName: char.lowercased())
                        .symbolVariant(.circle)
                        .font(.system(size: 200))
                        .foregroundStyle(.indigo.gradient)
                }
            } animation: { char in
                switch char {
                case "d": return .bouncy.speed(0.2)
                case "e": return .easeIn.speed(0.3)
                case "v": return .easeInOut.speed(0.5)
                case "t": return .easeOut.speed(0.4)
                case "c": return .spring.speed(0.5)
                case "h": return .snappy.speed(0.6)
                case "i": return .smooth.speed(0.7)
                default : return .bouncy.speed(0.8)
                }
            }
            .onTapGesture {
                animate.toggle()
            }
        }
    }
}

#Preview {
    ContentView()
}
