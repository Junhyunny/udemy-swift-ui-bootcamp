# `actor` 타입 — 무엇이고, 어떤 용도로 왜 쓰는가

## 질문이 나온 코드

`chapter-140/chapter-140/Utils/AudioManager.swift`

```swift
actor AudioManager {
    private var engine: AudioEngine?
    private var mixer: Mixer?
    private var sampler: MIDISampler?
    static let shared = AudioManager()
    private init() {}

    func setAudio() throws { ... }
    func playNote(note: MIDINoteNumber, velocity: MIDIVelocity = 127) { ... }
    func stopNote(note: MIDINoteNumber) { ... }
}
```

`class`도 `struct`도 아닌 `actor`다. 이 타입이 무엇이고, 어떤 용도로 왜 쓰는지가 질문이다.

`@MainActor`와 iOS 스레드 모델은 [`MainActor`는 왜 필요한가](./main-actor-and-ios-threading.md)에 정리되어 있다. 이 문서는 **`actor` 타입 자체**를 다룬다.

## 공부할 내용

### 결론 먼저

- `actor`는 **자기 상태를 한 번에 하나의 작업만 만지도록 컴파일러가 보장하는 참조 타입**이다.
- 목적은 단 하나, **data race(데이터 경합) 방지**다. 성능 향상 장치가 아니다.
- `class`에 `lock`이나 직렬 큐를 직접 붙여 하던 일을, **컴파일러가 검사해 주는 언어 기능으로 올린 것**이다.
- 대가로 밖에서 쓸 때 `await`가 필요하다.

### 왜 필요한가 — class로 쓰면 생기는 일

`AudioManager`를 `class`로 만들었다고 해 보자.

```swift
final class AudioManager {
    private var sampler: MIDISampler?

    func setAudio() throws {
        sampler = MIDISampler(name: "Piano")   // 쓰기
        ...
    }

    func playNote(note: MIDINoteNumber) {
        sampler?.play(noteNumber: note, ...)   // 읽기
    }
}
```

`PianoViewModel`은 여러 `Task`에서 이 객체를 호출한다.

```swift
func notePressed(_ note: PianoNote) {
    Task { await audioManager.playNote(note: note.midiNote) }
}
```

```text
Task A: setAudio()  ──▶ sampler에 쓰는 중
Task B: playNote()  ──▶ 같은 순간 sampler를 읽음
                         ↓
                   무엇을 읽을지 정해져 있지 않다
```

이것이 data race다. 증상은 크래시일 수도, 소리가 안 나는 것일 수도, **아무 일도 안 일어나다가 특정 기기에서만 터지는 것**일 수도 있다. 재현이 어려워 가장 다루기 힘든 버그에 속한다.

전통적인 해법은 직접 막는 것이었다.

```swift
private let queue = DispatchQueue(label: "audio")
func playNote(...) { queue.async { ... } }
```

문제는 **이 규칙을 지켰는지 아무도 검사해 주지 않는다**는 점이다. 새 메서드를 추가하면서 `queue.async`를 빠뜨려도 컴파일은 통과한다.

### actor가 하는 일

`actor`로 선언하면 두 가지가 생긴다.

1. **격리(isolation)**: 저장 프로퍼티와 메서드는 그 actor에 속하게 된다.
2. **직렬 실행**: actor의 상태에 접근하는 작업은 한 번에 하나씩만 실행된다.

```text
                 AudioManager (actor)
                 ┌──────────────────┐
Task A ──await──▶│  engine          │
Task B ──await──▶│  mixer           │  한 번에 하나만 들어간다
Task C ──await──▶│  sampler         │
                 └──────────────────┘
```

그리고 **규칙을 어기면 컴파일 오류**가 난다.

```swift
let manager = AudioManager.shared
manager.playNote(note: 60)
// error: actor-isolated instance method 'playNote(note:)' can not be
//        referenced from a nonisolated context
```

올바른 호출은 이렇다.

```swift
await manager.playNote(note: 60)
```

`await`는 "여기서 기다릴 수 있다"는 표시다. actor가 다른 작업을 처리 중이면 순서를 기다렸다가 들어간다. [async/await 실행 모델](./swift-async-await-model.md)과 함께 보면 이해가 빠르다.

### 안과 밖의 규칙이 다르다

actor 내부에서는 `await` 없이 자기 상태를 그냥 쓴다.

```swift
actor AudioManager {
    private var sampler: MIDISampler?

    func playNote(note: MIDINoteNumber, velocity: MIDIVelocity = 127) {
        sampler?.play(...)      // 내부라 await 불필요
    }

    func replay(note: MIDINoteNumber) {
        stopNote(note: note)    // 같은 actor의 메서드도 await 불필요
        playNote(note: note)
    }
}
```

이미 그 actor 안에 들어와 있기 때문이다. **`await`가 필요한 건 밖에서 들어올 때뿐이다.**

### `class`, `struct`, `actor` 비교

| | `struct` | `class` | `actor` |
|---|---|---|---|
| 종류 | 값 타입 | 참조 타입 | **참조 타입** |
| 복사 | 값 복사 | 참조 공유 | 참조 공유 |
| 상속 | 불가 | 가능 | **불가** |
| 동시 접근 보호 | 복사되므로 공유 없음 | **없음 (직접 해야 함)** | **컴파일러가 보장** |
| 외부 접근 | 그냥 | 그냥 | **`await` 필요** |

`actor`는 **"상속 없는 class + 자동 동기화"**로 이해하면 가깝다. 값 타입과 참조 타입의 일반적인 차이는 [`struct`와 `class`](./struct-vs-class.md)에 정리되어 있다.

### 언제 쓰는가

**쓰기 좋은 경우**

- 여러 곳에서 공유하는 **가변 상태**를 들고 있다 (이 코드의 `engine`, `mixer`, `sampler`)
- 싱글턴처럼 앱 전체가 하나의 인스턴스를 함께 쓴다
- 캐시, 커넥션 풀, 파일 핸들, 로그 버퍼처럼 순서가 중요한 자원
- 백그라운드에서 대량 작업을 하되 상태를 안전하게 지켜야 한다

**안 써도 되는 경우**

- 상태가 없다. 순수 함수 모음이면 `enum`의 `static` 메서드나 `struct`로 충분하다
- 상태가 있지만 **UI 상태**다. 그건 `@MainActor`가 맞다 (이 프로젝트의 `PianoViewModel`)
- 값 타입으로 충분하다. 공유하지 않으면 경합도 없다

이 프로젝트의 역할 분담이 좋은 예다.

```text
PianoViewModel   @MainActor   UI 상태(activeNotes), 화면 갱신
       │  await
       ▼
AudioManager     actor        오디오 엔진이라는 공유 자원
```

`@MainActor`도 actor의 일종이다. 정확히는 **global actor**이며, 인스턴스가 앱 전체에 하나뿐이고 메인 스레드에 묶여 있다는 점이 다르다([SE-0316](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md)).

### 주의할 점 — 재진입(reentrancy)

actor가 "한 번에 하나"를 보장하는 건 **중단 없이 실행되는 구간**에 대해서다. 메서드 안에 `await`가 있으면 그 지점에서 다른 작업이 끼어들 수 있다.

```swift
actor Counter {
    private var value = 0

    func bump() async {
        let current = value       // ①
        await Task.yield()        // ← 여기서 다른 호출이 끼어들 수 있다
        value = current + 1       // ② ①에서 읽은 값이 이미 낡았을 수 있다
    }
}
```

**actor는 데이터 경합은 막지만 논리적 경합까지 막지는 않는다.** `await` 앞뒤로 상태가 유지된다고 가정하면 안 된다. `await` 뒤에서는 필요한 값을 다시 읽는다.

### 주의할 점 — `Sendable`

actor 경계를 넘나드는 값은 여러 실행 문맥에서 안전해야 하므로 `Sendable`이어야 한다.

```swift
await audioManager.playNote(note: note.midiNote)   // MIDINoteNumber는 값 타입
```

이 코드가 `PianoNote` 객체 대신 `midiNote`(숫자)만 넘기는 것도 같은 맥락이다. 클래스 인스턴스를 그대로 넘기려 하면 컴파일러가 막는다. SwiftData의 model 객체가 `Sendable`이 아닌 것과 같은 규칙이며, [SwiftData 동시성 문서](./swiftdata-concurrency-and-context-isolation.md)에서도 다뤘다.

### 주의할 점 — 비용

actor 호출은 공짜가 아니다. 이미 그 actor 안에 있지 않다면 **실행 문맥을 옮기는 비용(hop)**이 든다.

```text
@MainActor PianoViewModel
      │  Task { await ... }   ← 여기서 전환
      ▼
actor AudioManager
```

건반을 누를 때마다 이 전환이 일어난다. 사람이 느낄 수준인지는 **측정해서 판단**한다. 실시간 오디오처럼 지연에 민감한 영역에서는 actor 대신 전용 실시간 스레드를 쓰기도 한다. "actor니까 안전하고 빠르다"는 결론은 성립하지 않는다. 안전과 성능은 다른 질문이다.

### 이 코드에서 actor가 실제로 막고 있는 것

```swift
actor AudioManager {
    private var engine: AudioEngine?     // ← 이 세 개가 공유 가변 상태
    private var mixer: Mixer?
    private var sampler: MIDISampler?
```

- `PianoViewModel.init`의 `Task`가 `setAudio()`로 셋을 **초기화**한다.
- 건반을 누를 때마다 별도 `Task`가 `playNote()`로 `sampler`를 **읽는다**.
- 뗄 때마다 또 다른 `Task`가 `stopNote()`로 **읽는다**.

`actor`가 아니면 초기화가 끝나기 전에 재생 호출이 `sampler`를 읽는 상황이 가능하다. `actor`는 이 접근들을 한 줄로 세운다.

`static let shared` + `private init()`으로 싱글턴을 만든 것도 의도가 같다. **오디오 엔진은 앱에 하나만 있어야 하므로**, 인스턴스를 하나로 고정하고 그 하나를 actor로 보호한다.

## 체크리스트

- [ ] `actor`를 `class`로 바꿔 보고 어떤 컴파일 오류가 사라지는지(= 무엇을 잃는지) 확인한다.
- [ ] `await` 없이 actor 메서드를 호출해 오류 메시지를 직접 읽는다.
- [ ] actor 내부 메서드끼리는 왜 `await`가 필요 없는지 설명한다.
- [ ] `struct`, `class`, `actor`의 차이를 표로 직접 채운다.
- [ ] 재진입 예제를 만들어 `await` 앞뒤로 상태가 바뀌는 것을 확인한다.
- [ ] actor에 클래스 인스턴스를 넘기려 할 때 나오는 `Sendable` 오류를 확인한다.
- [ ] `@MainActor`와 일반 `actor`가 어떻게 다른지 한 문장으로 정리한다.
- [ ] `nonisolated` 메서드를 하나 추가해 어떤 제약이 생기는지 본다.
- [ ] 건반을 누른 뒤 소리가 날 때까지의 지연을 측정해 actor hop 비용을 가늠한다.

## 공식 참고 자료

- [The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [The Swift Programming Language: Declarations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/)
- [Apple: Actor](https://developer.apple.com/documentation/swift/actor)
- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)
- [SE-0306: Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md)
- [SE-0316: Global actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md)
- [SE-0337: Incremental migration to concurrency checking](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md)
- [Apple WWDC21: Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [Apple WWDC22: Eliminate data races using Swift Concurrency](https://developer.apple.com/videos/play/wwdc2022/110351/)
