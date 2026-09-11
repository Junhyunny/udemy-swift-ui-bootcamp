//
//  AudioManager.swift
//  chapter-140
//
//  Created by 강준현 on 9/11/26.
//

// TODO: [todos/avfoundation-framework.md](../../../todos/avfoundation-framework.md)
import AVFoundation
import AudioKit
import Foundation
import SwiftUI

enum AudioError: Error {
    case setupFailed
}

// TODO: [todos/swift-actor-type.md](../../../todos/swift-actor-type.md)
actor AudioManager {
    private var engine: AudioEngine?
    private var mixer: Mixer?
    private var sampler: MIDISampler?
    static let shared = AudioManager()
    private init() {}

    func setAudio() throws {
        guard engine == nil else { return }
        engine = AudioEngine()
        mixer = Mixer()
        guard let mixer = mixer else {
            throw AudioError.setupFailed
        }
        sampler = MIDISampler(name: "Piano")
        if let sampler = sampler {
            mixer.addInput(sampler)
            engine?.output = mixer
        }
        try engine?.start()
    }

    func playNote(note: MIDINoteNumber, velocity: MIDIVelocity = 127) {
        sampler?.play(noteNumber: note, velocity: velocity, channel: .min)
    }

    func stopNote(note: MIDINoteNumber) {
        sampler?.stop(noteNumber: note, channel: .min)
    }
}
