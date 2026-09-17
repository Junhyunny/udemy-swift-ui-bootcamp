//
//  PianoViewModel.swift
//  chapter-140
//
//  Created by 강준현 on 9/11/26.
//

import AudioKit
import Combine
import Observation
import SwiftUI

// FIXME: [Architecture] 오디오 엔진 구현체에 컴파일 타임으로 묶여 있다.
// - 현상: private let audioManager: AudioManager = AudioManager.shared 로 구체 타입을 직접 잡는다.
// - 문제: PianoViewModel 을 테스트하려면 실제 AudioKit 엔진이 떠야 한다. 시뮬레이터/CI 에서는
//         오디오 세션 구성이 실패할 수 있어 테스트가 환경에 좌우된다.
//         '어떤 건반이 눌렸는가'라는 순수한 상태 로직조차 검증할 수 없다.
// - 개선: protocol AudioPlaying { func setAudio() async throws; func playNote(...) async; func stopNote(...) async }
//         를 두고 init(audioManager: AudioPlaying = AudioManager.shared) 로 주입받는다.
//         테스트에서는 호출 기록만 남기는 SpyAudioPlayer 를 넣으면 된다.
@MainActor
@Observable
final class PianoViewModel {
    // TODO: [todos/access-control.md](../../../todos/access-control.md)
    private(set) var activeNotes: Set<MIDINoteNumber> = []
    private let audioManager: AudioManager = AudioManager.shared

    // FIXME: [Best Practice] init 에서 Task 를 띄워 오디오 엔진을 초기화하고, 실패는 print 로 끝난다.
    // - 문제1: 초기화가 언제 끝나는지 알 수 없어, 그 사이에 건반을 누르면 소리가 나지 않는다.
    // - 문제2: 설정 실패가 화면에 전혀 드러나지 않아 사용자는 "고장난 앱"으로 인식한다.
    // - 개선: enum AudioState { case idle, ready, failed(Error) } 를 상태로 두고,
    //         준비는 View 의 .task { await viewModel.prepare() } 에서 수행한다.
    //         실패 시 배너나 재시도 버튼을 노출한다.
    init() {
        Task {
            do {
                try await audioManager.setAudio()
            } catch {
                print("Audio setup failed: \(error)")
            }
        }
    }

    func notePressed(_ note: PianoNote) {
        guard !activeNotes.contains(note.midiNote) else { return }
        activeNotes.insert(note.midiNote)
        Task {
            await audioManager.playNote(note: note.midiNote)
        }
    }

    func noteReleased(_ note: PianoNote) {
        activeNotes.remove(note.midiNote)
        Task {
            await audioManager.stopNote(note: note.midiNote)
        }
    }

    func isNoteActive(_ note: PianoNote) -> Bool {
        activeNotes.contains(note.midiNote)
    }
}
