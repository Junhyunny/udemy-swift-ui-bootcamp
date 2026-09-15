//
//  ContentView.swift
//  chapter-156
//
//  Created by 강준현 on 9/15/26.
//

import SwiftUI

protocol SegmentItem: Hashable & CaseIterable & RawRepresentable
where RawValue == String {
    var icon: String { get }
    var color: Color { get }
}

enum AppTab: String, SegmentItem {
    case swiftUI = "SwiftUI"
    case iOS = "iOS"
    case uiKit = "UIKit"
    case ml = "ML"

    var color: Color {
        switch self {
        case .swiftUI: return .blue
        case .iOS: return .pink
        case .uiKit: return .purple
        case .ml: return .brown
        }
    }

    var icon: String {
        switch self {
        case .swiftUI: return "swift"
        case .iOS: return "apple.logo"
        case .uiKit: return "macwindow"
        case .ml: return "brain"
        }
    }
}

struct SegmentedControlSwiftUI: View {
    @State private var selectedTab: AppTab = .swiftUI
    // TODO: [todos/namespace-and-matched-geometry-effect.md](../../todos/namespace-and-matched-geometry-effect.md)
    @Namespace private var animation

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                VStack {
                    Image(systemName: selectedTab.icon)
                        .font(.system(size: 80))
                        .foregroundStyle(selectedTab.color)
                    Text(selectedTab.rawValue)
                        .font(.largeTitle.bold())
                }
                .padding(60)
                .frame(width: 300, height: 200)
                .background(
                    selectedTab.color.opacity(0.15).gradient,
                    in: .rect(cornerRadius: 20)
                )
                Spacer()
                // customSegmentedControl
                ReusableSegmentedControl(
                    selection: $selectedTab,
                    colorProvider: { $0.color }
                )
                Spacer()
            }
            .navigationTitle("DevTechine.com")
        }
    }

    @ViewBuilder
    var customSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                HStack(spacing: 8) {
                    Image(systemName: tab.icon)
                    Text(tab.rawValue)
                }
                .font(.headline)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .foregroundStyle(
                    tab == selectedTab ? .primary : .secondary
                )
                .background {
                    if selectedTab == tab {
                        // Capsule()
                        RoundedRectangle(cornerRadius: 5, style: .circular)
                            .frame(height: 3)
                            .offset(y: 15)
                            .foregroundStyle(selectedTab.color.gradient)
                            .matchedGeometryEffect(
                                id: "selected_tab",
                                in: animation
                            )
                    }
                }
                .contentShape(.rect)
                .onTapGesture { apGesture in
                    withAnimation(.snappy) {
                        self.selectedTab = tab
                    }
                }
            }
        }
        .padding(6)
        .background(.primary.opacity(0.08), in: .capsule)
        .padding(.horizontal)
    }
}

struct ContentView: View {
    var body: some View {
        SegmentedControlSwiftUI()
    }
}

#Preview {
    ContentView()
}

// TODO: [todos/protocol-composition-and-type-combining.md](../../todos/protocol-composition-and-type-combining.md)
struct ReusableSegmentedControl<T: SegmentItem>:
    View
// TODO: [todos/where-clause-usages.md](../../todos/where-clause-usages.md)
where T.RawValue == String {
    @Binding var selection: T
    private let items: [T] = T.allCases as! [T]
    @Namespace private var animation

    let colorProvider: (T) -> Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    // TODO: [todos/type-checker-timeout-error.md](../../todos/type-checker-timeout-error.md)
                    Image(systemName: item.icon)
                    Text(item.rawValue)
                }
                .font(.headline)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .foregroundStyle(selection == item ? .primary : .secondary)
                .background {
                    if selection == item {
                        Capsule()
                            .foregroundStyle(item.color.gradient)
                            .matchedGeometryEffect(
                                id: "reusable_segment_id",
                                in: animation
                            )
                    }
                }
                .contentShape(.rect)
                .onTapGesture {
                    withAnimation(.bouncy) {
                        selection = item
                    }
                }
            }
        }
        .padding(4)
        .background(
            .primary.opacity(0.08),
            in: .capsule
        )
    }
}
