//
//  ContentView.swift
//  chapter-140
//
//  Created by 강준현 on 9/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = PianoViewModel()
    @State private var currentDragNote: PianoNote?

    var body: some View {
        VStack {
            Text("Piano App")
                .font(.title)
                .padding()
            pianoKeyboard()
        }
        .background(
            Color(UIColor.systemBackground)
        )
        .ignoresSafeArea()
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }

    private func pianoKeyboard() -> some View {
        GeometryReader { keyboardGeometry in
            let metrics = KeyboardMetrics(size: keyboardGeometry.size)
            ZStack(alignment: .topLeading) {
                HStack(spacing: metrics.whiteKeySpacing) {
                    ForEach(PianoNote.whiteKeys, id: \.self) { note in
                        PianoKeyView(
                            note: note,
                            isActive: viewModel.isNoteActive(note)
                        )
                    }
                }
                .frame(height: metrics.whiteKeyHeight)
                ForEach(
                    Array(PianoNote.blackKeys.enumerated()),
                    id: \.element
                ) { index, note in
                    PianoKeyView(
                        note: note,
                        isActive: viewModel.isNoteActive(note)
                    )
                    .frame(
                        width: metrics.blackKeyWidth,
                        height: metrics.blackKeyHeight
                    )
                    .offset(x: metrics.blackKeyOriginX(at: index))
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(
                    minimumDistance: 0,
                    coordinateSpace: .local
                )
                .onChanged { value in
                    handleDrag(to: value.location, in: metrics)
                }
                .onEnded { _ in
                    releaseCurrentNote()
                }
            )
        }
    }

    private func handleDrag(to location: CGPoint, in metrics: KeyboardMetrics) {
        let note = metrics.note(at: location)
        guard note != currentDragNote else { return }
        if let previousNote = currentDragNote {
            viewModel.noteReleased(previousNote)
        }
        currentDragNote = note
        if let note {
            viewModel.notePressed(note)
        }
    }

    private func releaseCurrentNote() {
        guard let note = currentDragNote else { return }
        viewModel.noteReleased(note)
        currentDragNote = nil
    }
}

/// 건반을 그리는 좌표와 터치를 판정하는 좌표를 한 곳에서 계산한다.
/// 두 계산이 갈라지면 보이는 건반과 소리 나는 건반이 어긋난다.
private struct KeyboardMetrics {
    let size: CGSize
    let whiteKeySpacing: CGFloat = 1

    /// 검은 건반은 흰 건반 i번과 i+1번의 경계 위에 놓인다.
    private static let blackKeyBoundaries = [0, 1, 3, 4, 5]

    var whiteKeyWidth: CGFloat {
        let count = CGFloat(PianoNote.whiteKeys.count)
        return (size.width - whiteKeySpacing * (count - 1)) / count
    }

    /// 흰 건반 하나가 차지하는 간격. 건반 너비에 사이 여백을 더한 값이다.
    var whiteKeyStride: CGFloat {
        whiteKeyWidth + whiteKeySpacing
    }

    var whiteKeyHeight: CGFloat {
        size.height * 0.8
    }

    var blackKeyWidth: CGFloat {
        whiteKeyWidth * 0.6
    }

    var blackKeyHeight: CGFloat {
        size.height * 0.5
    }

    func blackKeyOriginX(at index: Int) -> CGFloat {
        guard Self.blackKeyBoundaries.indices.contains(index) else { return 0 }
        let boundary = CGFloat(Self.blackKeyBoundaries[index] + 1)
            * whiteKeyStride - whiteKeySpacing / 2
        return boundary - blackKeyWidth / 2
    }

    func blackKeyRect(at index: Int) -> CGRect {
        CGRect(
            x: blackKeyOriginX(at: index),
            y: 0,
            width: blackKeyWidth,
            height: blackKeyHeight
        )
    }

    /// 검은 건반이 흰 건반 위에 겹쳐 있으므로 검은 건반을 먼저 판정한다.
    func note(at location: CGPoint) -> PianoNote? {
        for index in PianoNote.blackKeys.indices
        // TODO: [todos/where-clause-usages.md](../../todos/where-clause-usages.md)
        where blackKeyRect(at: index).contains(location) {
            return PianoNote.blackKeys[index]
        }
        guard location.x >= 0,
            location.y >= 0,
            location.y <= whiteKeyHeight
        else { return nil }
        let index = Int(location.x / whiteKeyStride)
        guard PianoNote.whiteKeys.indices.contains(index) else { return nil }
        return PianoNote.whiteKeys[index]
    }
}

#Preview {
    ContentView()
}
