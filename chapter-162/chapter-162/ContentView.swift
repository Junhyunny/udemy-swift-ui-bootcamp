//
//  ContentView.swift
//  chapter-162
//
//  Created by 강준현 on 9/16/26.
//

import SwiftUI

struct ContentView: View {
    @Namespace private var namespace
    @State private var isExpanded = false

    var body: some View {
        // GlassEffectContainerExample()
        ZStack(alignment: .bottomTrailing) {
            GlassEffectContainer(spacing: 60) {
                VStack(alignment: .center, spacing: 20) {
                    if isExpanded {
                        Image(systemName: "folder.fill.badge.plus")
                            .frame(width: 80, height: 80)
                            .font(.system(size: 36))
                            .glassEffect(.clear)
                            .glassEffectID("newFolder", in: namespace)
                        Image(
                            systemName: "pencil.tip.crop.circle.badge.plus.fill"
                        )
                        .frame(width: 80, height: 80)
                        .font(.system(size: 36))
                        .glassEffect(.clear)
                        .glassEffectID("pencil", in: namespace)

                        Image(systemName: "widget.small.badge.plus")
                            .frame(width: 80, height: 80)
                            .font(.system(size: 36))
                            .glassEffect(.clear)
                            .glassEffectID("pencil", in: namespace)

                        Image(
                            systemName: "person.crop.circle.fill.badge.plus"
                        )
                        .frame(width: 80, height: 80)
                        .font(.system(size: 36))
                        .glassEffect(.clear)
                        .glassEffectID("pencil", in: namespace)
                    }
                    Button {
                        withAnimation(.interactiveSpring(duration: 1.5, extraBounce: 0.5)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(
                            systemName: isExpanded
                                ? "xmark" : "line.3.horizontal"
                        )
                        .frame(width: 80, height: 80)
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                        .glassEffect(.clear)
                        .glassEffectID("Close Button", in: namespace)
                    }
                }
            }
        }
        .padding(.trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .background(
            Image(.background)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .blur(radius: isExpanded ? 10 : 0)
        )
    }
}

struct GlassEffectContainerExample: View {
    @Namespace private var namespace
    @State private var animate = false

    var body: some View {
        GlassEffectContainer(spacing: 30) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .padding()
                    .glassEffect(.clear)
                    .glassEffectID("sun.max.fill", in: namespace)
                if animate {
                    Image(systemName: "moon.stars.fill")
                        .padding()
                        .glassEffect(.clear)
                        .glassEffectID("moon.stars.fill", in: namespace)
                    Image(systemName: "cloud.rain.fill")
                        .padding()
                        .glassEffect(.clear)
                        .glassEffectID("cloud.rain.fill", in: namespace)
                }
            }
            Button("Animiate") {
                withAnimation(.bouncy(duration: 1.5)) {
                    animate.toggle()
                }
            }
            .controlSize(.large)
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image(.background)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
    }
}

#Preview {
    ContentView()
}
