# AVFoundation은 무슨 모듈인가

## 질문이 나온 코드

`chapter-140/chapter-140/Utils/AudioManager.swift`

```swift
import AVFoundation
import AudioKit
import Foundation
import SwiftUI

actor AudioManager {
    private var engine: AudioEngine?
    private var mixer: Mixer?
    private var sampler: MIDISampler?
    ...
}
```

`AVFoundation`이 무슨 모듈인지가 질문이다.

## 공부할 내용

### 한 줄 정의

**AVFoundation은 Apple 플랫폼에서 시간 기반 시청각 미디어(audiovisual media)를 다루는 프레임워크**다. 녹음·재생·편집·촬영·내보내기를 모두 포함한다.

`Foundation`이 문자열·날짜·파일 같은 기본 자료형을 담당한다면([Foundation 문서](./foundation-framework.md)), AVFoundation은 **소리와 영상**을 담당한다. 이름의 `AV`는 Audio/Video다.

### 무엇이 들어 있나

AVFoundation은 하나의 거대한 우산이고 그 아래에 역할별 영역이 있다.

| 영역 | 대표 타입 | 하는 일 |
|---|---|---|
| 미디어 자산 | `AVAsset`, `AVURLAsset` | 파일·스트림을 미디어로 표현하고 메타데이터를 읽는다 |
| 재생 | `AVPlayer`, `AVPlayerItem` | 영상·오디오 재생과 시간 제어 |
| 촬영 | `AVCaptureSession`, `AVCaptureDevice` | 카메라·마이크 입력 |
| 편집·내보내기 | `AVMutableComposition`, `AVAssetExportSession` | 자르기, 합치기, 파일로 출력 |
| 오디오 엔진 | `AVAudioEngine`, `AVAudioUnitSampler` | 실시간 오디오 그래프 구성과 처리 |
| 오디오 세션 | `AVAudioSession` | 앱의 오디오 동작 방식을 시스템에 선언 |
| 간단 재생 | `AVAudioPlayer`, `AVAudioRecorder` | 파일 단위 재생·녹음 |

이 중 오디오 쪽은 **AVFAudio**라는 하위 프레임워크로 분리되어 있다. `import AVFoundation`을 하면 AVFAudio도 함께 들어온다.

```text
AVFoundation
 ├── AVFAudio            오디오 (AVAudioEngine, AVAudioSession, AVAudioPlayer ...)
 ├── 재생/편집           AVAsset, AVPlayer, AVComposition ...
 └── 촬영                AVCaptureSession ...

AVKit                    위 기능을 위한 표준 UI (별도 프레임워크)
```

화면에 재생 컨트롤을 띄우는 `VideoPlayer`나 `AVPlayerViewController`는 AVFoundation이 아니라 **AVKit**에 있다. 데이터·엔진 계층과 UI 계층이 나뉘어 있다.

### 이 프로젝트에서의 위치

이 앱은 AVFoundation 타입을 직접 쓰지 않고 **AudioKit**을 쓴다.

```swift
private var engine: AudioEngine?      // AudioKit
private var mixer: Mixer?             // AudioKit
private var sampler: MIDISampler?     // AudioKit
```

AudioKit은 Apple의 `AVAudioEngine` 위에 올라간 **서드파티 오픈소스 래퍼**다. 노드를 연결해 오디오 그래프를 만드는 구조는 같고, API가 더 간결하다.

```text
앱 코드 (AudioManager)
      ↓
AudioKit          AudioEngine / Mixer / MIDISampler
      ↓
AVFAudio          AVAudioEngine / AVAudioUnitSampler
      ↓
Core Audio        저수준 오디오 처리
      ↓
하드웨어
```

그래서 `AudioEngine`은 `AVAudioEngine`의 다른 이름이 아니라, **`AVAudioEngine`을 감싸 쓰는 AudioKit의 타입**이다.

### 지금 이 `import`는 실제로 필요한가

확인해 보면 **필요하지 않다.** `import AVFoundation`을 주석 처리하고 빌드해도 성공한다.

```text
// import AVFoundation  → ** BUILD SUCCEEDED **
```

이 파일에 AVFoundation 타입이 직접 등장하지 않기 때문이다. 지우면 의존 관계가 더 정직해진다. 다만 다음 경우에는 **다시 필요해진다.**

- `AVAudioSession`을 직접 설정할 때
- `AVAudioFile`로 샘플 음원을 불러올 때
- 녹음 기능을 붙일 때

강의를 따라가며 기능을 추가할 예정이라면 남겨 두어도 무방하다. "지금은 안 쓰지만 곧 쓴다"와 "습관적으로 붙였다"를 구분해 두는 것이 요점이다.

### 실기기에서 소리가 안 날 때 먼저 볼 것 — `AVAudioSession`

시뮬레이터에서는 소리가 나는데 실기기에서 안 나는 경우가 흔하다. 대부분 **오디오 세션을 설정하지 않아서**다.

`AVAudioSession`은 "이 앱의 오디오가 어떤 성격인가"를 시스템에 알리는 통로다.

```swift
import AVFoundation

let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default)
try session.setActive(true)
```

`.playback`으로 선언하면 **무음 스위치가 켜져 있어도 소리가 난다.** 기본값(`.soloAmbient`)은 무음 스위치를 따르므로, 악기 앱에서 흔히 겪는 "소리가 안 나요"의 원인이 된다.

카테고리는 앱의 성격에 맞춰 고른다.

| 카테고리 | 용도 | 무음 스위치 |
|---|---|---|
| `.ambient` | 배경음, 게임 효과음 | 따름 (무음) |
| `.soloAmbient` | 기본값 | 따름 (무음) |
| `.playback` | 음악·악기 앱 | **무시하고 재생** |
| `.record` | 녹음 전용 | — |
| `.playAndRecord` | 통화, 녹음하며 재생 | — |

현재 `AudioManager.setAudio()`에는 이 설정이 없다. AudioKit이 내부적으로 처리해 주는 부분이 있는지, 아니면 직접 설정해야 하는지는 **실기기에서 확인**해야 한다. 이 확인은 체크리스트에 남겨 둔다.

### AVFoundation과 헷갈리기 쉬운 이웃들

| 프레임워크 | 쓰임 |
|---|---|
| **AVFoundation** | 미디어 데이터와 엔진 |
| **AVKit** | 미디어 재생 UI |
| **Core Audio** | AVFoundation 아래의 저수준 C API |
| **AudioToolbox** | 오디오 유닛, 시스템 사운드 등 중간 계층 |
| **MediaPlayer** | 사용자 음악 라이브러리, 잠금화면 재생 정보 |
| **PhotosUI / Photos** | 사진·동영상 라이브러리 접근 |
| **AudioKit** | Apple 것이 아님. `AVAudioEngine` 위의 오픈소스 래퍼 |

"소리를 낸다"는 목표 하나에도 계층이 여러 개다. 어느 계층에서 풀 문제인지 먼저 정하는 편이 빠르다.

## 체크리스트

- [ ] AVFoundation의 다섯 영역(자산·재생·촬영·편집·오디오)을 한 줄씩 설명한다.
- [ ] AVFoundation, AVFAudio, AVKit의 경계를 그림으로 그린다.
- [ ] `import AVFoundation`을 지우고 빌드해 실제 의존 여부를 확인한다.
- [ ] AudioKit의 `AudioEngine`이 `AVAudioEngine`과 어떤 관계인지 설명한다.
- [ ] `AVAudioSession`의 카테고리를 바꿔 가며 무음 스위치 동작을 실기기에서 확인한다.
- [ ] 이 앱에 오디오 세션 설정이 필요한지 실기기에서 판단한다.
- [ ] `AVAudioEngine`만으로 같은 피아노를 만들어 보고 AudioKit과 코드량을 비교한다.

## 공식 참고 자료

- [Apple: AVFoundation](https://developer.apple.com/documentation/avfoundation)
- [Apple: AVFAudio](https://developer.apple.com/documentation/avfaudio)
- [Apple: AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Apple: AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Apple: AVAudioUnitSampler](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler)
- [Apple: AVAsset](https://developer.apple.com/documentation/avfoundation/avasset)
- [Apple: AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer)
- [Apple: AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession)
- [AudioKit 공식 사이트](https://www.audiokit.io/)
- [AudioKit 저장소](https://github.com/AudioKit/AudioKit)
