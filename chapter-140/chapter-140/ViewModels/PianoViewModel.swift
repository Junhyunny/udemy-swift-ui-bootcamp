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

@MainActor
@Observable
final class PianoViewModel {
    // TODO: [todos/access-control.md](../../../todos/access-control.md)
    private(set) var activeNotes: Set<MIDINoteNumber> = []
    private let audioManager: AudioManager = AudioManager.shared

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
