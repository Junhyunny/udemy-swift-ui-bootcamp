//
//  PianoNote.swift
//  chapter-140
//
//  Created by 강준현 on 9/11/26.
//

import AudioKit
import Foundation

struct PianoNote: Identifiable, Hashable {
    let id = UUID()
    let midiNote: MIDINoteNumber
    let name: String
    let isBlackKey: Bool

    static let whiteKeys: [PianoNote] = [
        PianoNote(midiNote: 60, name: "C4", isBlackKey: false),
        PianoNote(midiNote: 62, name: "D4", isBlackKey: false),
        PianoNote(midiNote: 64, name: "E4", isBlackKey: false),
        PianoNote(midiNote: 65, name: "F4", isBlackKey: false),
        PianoNote(midiNote: 67, name: "G4", isBlackKey: false),
        PianoNote(midiNote: 69, name: "A4", isBlackKey: false),
        PianoNote(midiNote: 71, name: "B4", isBlackKey: false),
    ]
    
    static let blackKeys: [PianoNote] = [
        PianoNote(midiNote: 61, name: "C#4/Db4", isBlackKey: true),
        PianoNote(midiNote: 63, name: "D#4/Eb4", isBlackKey: true),
        PianoNote(midiNote: 66, name: "F#4/Gb4", isBlackKey: true),
        PianoNote(midiNote: 68, name: "G#4/Ab4", isBlackKey: true),
        PianoNote(midiNote: 70, name: "A#4/Bb4", isBlackKey: true),
    ]
}
