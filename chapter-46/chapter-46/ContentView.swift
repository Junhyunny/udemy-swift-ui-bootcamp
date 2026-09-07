//
//  ContentView.swift
//  chapter-46
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var tabs = ["Home", "Explore", "Notifications", "Profile"]
    @State private var selectedTab = 0
    var body: some View {
        VStack {
            Spacer()
            GeometryReader { geometry in
                let tabWidth = geometry.size.width / CGFloat(tabs.count)
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white)
                        .frame(height: 80)
                        .shadow(radius: 10)
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 10,
                        topTrailingRadius: 10
                    )
                    .stroke(.blue, lineWidth: 1)
                    .frame(width: tabWidth, height: 80)
                    .offset(x: CGFloat(selectedTab) * tabWidth, y: 0)
                    .animation(.spring(), value: selectedTab)
                    HStack(spacing: 0) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Button(action: {
                                selectedTab = index
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: tabIcon(for: index))
                                        .font(.system(size: 20))
                                    Text(tabs[index])
                                        .font(.caption)
                                }
                            }
                            .frame(width: tabWidth, height: 80)
                            .foregroundStyle(
                                selectedTab == index ? .blue : .gray
                            )
                        }
                    }
                }
            }
            .frame(height: 80)
        }
    }

    func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "house.fill"
        case 1: return "magnifyingglass"
        case 2: return "bell.fill"
        case 3: return "person.fill"
        default: return "circle.fill"
        }
    }
}

#Preview {
    ContentView()
}
