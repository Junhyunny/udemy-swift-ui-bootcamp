//
//  PianoKeyView.swift
//  chapter-140
//
//  Created by 강준현 on 9/11/26.
//
import AudioKit
import SwiftUI

/// 건반 하나의 모양만 담당한다.
/// 터치 판정과 연주는 `ContentView`의 키보드 전체 gesture가 처리한다.
struct PianoKeyView: View {
    let note: PianoNote
    let isActive: Bool

    private var baseColor: Color {
        note.isBlackKey ? .black.opacity(0.6) : .gray.opacity(0.3)
    }

    private var keyColor: Color {
        isActive
            ? .pianoHighlightColor.opacity(0.8)
            : (note.isBlackKey ? .pianoBlackKey : .pianoWhiteKey)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(baseColor)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 3)
                .offset(y: 3)
            Rectangle()
                .fill(keyColor)
                .overlay {
                    Rectangle()
                        .stroke(
                            .black.opacity(0.2),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: .black.opacity(0.2),
                    radius: isActive ? 0 : 1,
                    x: 0,
                    y: isActive ? 0 : -1
                )
                .offset(y: isActive ? 0 : -2)
        }
    }
}

#Preview {
    PianoKeyView(
        note: PianoNote(midiNote: 0, name: "C4", isBlackKey: true),
        isActive: false
    )
}
