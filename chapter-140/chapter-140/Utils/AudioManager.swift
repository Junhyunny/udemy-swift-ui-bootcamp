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
// FIXME: [Architecture] 서비스 계층 타입이 Utils/ 에 들어가 있다.
// - 현상: AudioManager 는 오디오 엔진 수명주기를 소유하는 어엿한 서비스인데,
//         Color+Extensions.swift 같은 순수 확장과 같은 폴더에 있다.
// - 문제: Utils 는 분류를 미룬 코드의 창고가 되기 쉽다. 폴더 이름이 의존 방향을 설명해주지 못한다.
// - 개선: Services/AudioManager.swift 로 옮긴다(chapter-80, chapter-88 이 이미 쓰는 구조).
//         Utils/ 에는 Color+Extensions.swift 처럼 도메인을 모르는 것만 남긴다.
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
