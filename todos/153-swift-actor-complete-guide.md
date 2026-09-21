# Swift 액터 완전 정복 — data race부터 격리 도메인까지

`actor`, `@MainActor`, `nonisolated`, `isolated`, `@concurrent`. Swift 동시성을 공부하다 보면 비슷하게 생긴 키워드가 쏟아진다. 각각을 따로 외우면 금방 헷갈리지만, **"격리 도메인(isolation domain)"이라는 개념 하나**로 꿰면 전부 같은 이야기의 다른 면이라는 것이 보인다.

이 문서는 그 순서대로 간다.

```text
기 ─ 왜 필요한가        data race 를 직접 측정한다
승 ─ actor 타입          컴파일러가 검사하는 직렬화
전 ─ 격리 도메인          actor / @MainActor / nonisolated 를 하나로 묶는다
   ─ 함정                actor 가 막아 주지 않는 것들
결 ─ 설계 지침            무엇에 무엇을 붙일 것인가
```

이 문서의 측정값과 컴파일 에러는 **Swift 6.3.3 툴체인에서 `-swift-version 6`으로 직접 컴파일·실행해 확인**한 실측값이다.

관련 문서: [Swift Concurrency 로드맵](./142-swift-concurrency-roadmap.md) · [async/await 실행 모델](./101-swift-async-await-model.md) · [`Sendable`과 엄격 검사](./149-sendable-and-strict-concurrency.md) · [런타임 아키텍처](./151-concurrency-runtime-architecture.md)

---

# 1부(기) — 문제: 왜 액터가 필요한가

## 1.1 data race를 직접 본다

평범한 `class`를 여러 작업이 동시에 건드리면 어떻게 되는가. 100,000번 증가를 5회 반복해 측정했다.

```swift
final class UnsafeCounter: @unchecked Sendable { var value = 0 }

await withTaskGroup(of: Void.self) { g in
    for _ in 0..<100_000 { g.addTask { u.value += 1 } }
}
```

```text
  1회차: 96779 / 100000 ← 유실
  2회차: 97604 / 100000 ← 유실
  3회차: 96950 / 100000 ← 유실
  4회차: 96916 / 100000 ← 유실
  5회차: 98117 / 100000 ← 유실
```

**매번 3% 안팎이 사라지고, 사라지는 양도 매번 다르다.** `value += 1`은 읽기·더하기·쓰기 세 단계라, 두 작업이 같은 값을 읽으면 증가 한 번이 없어진다.

여기서 배울 것은 숫자가 아니라 **비결정성**이다. 실행할 때마다 결과가 달라지므로 테스트로 잡을 수 없다. **데이터 경합은 정의되지 않은 동작(undefined behavior)** 이고, "대부분 잘 동작하다가 가끔 깨지는" 최악의 버그 유형이다. Swift가 이 문제를 런타임 검사가 아니라 **컴파일 타임 검사**로 옮긴 이유가 이것이다.

증상은 한 가지가 아니다. 크래시일 수도, 값이 조용히 틀리는 것일 수도, **아무 일도 안 일어나다가 특정 기기에서만 터지는 것**일 수도 있다.

## 1.2 또 하나의 규칙 — UI는 메인 스레드에서만

iOS에는 data race와 짝을 이루는 규칙이 하나 더 있다. **UIKit·SwiftUI의 UI 갱신은 반드시 메인 스레드에서 일어나야 한다.**

이유는 같다. **UI 프레임워크가 스레드 안전하지 않기 때문**이다. 여러 스레드가 동시에 뷰 계층을 건드리면 내부 상태가 깨진다. 화면이 깜빡이거나, 레이아웃이 어긋나거나, 크래시가 난다.

메인 스레드가 하는 일은 이렇다.

```text
메인 런루프 (초당 60~120회)
  ├─ 터치·제스처 입력 처리
  ├─ 상태 변경 반영
  ├─ 레이아웃 계산
  ├─ 화면 그리기
  └─ 다음 프레임 준비
```

그래서 메인 스레드에서 무거운 작업을 하면 **화면이 멈춘다.** 두 방향의 규칙이 동시에 성립한다.

| | 어디서 |
| --- | --- |
| UI 갱신 | **반드시 메인 스레드** |
| 네트워크, 파일 IO, 무거운 계산 | **백그라운드** |

## 1.3 GCD 시대 — 규칙을 개발자가 기억했다

Swift 동시성 이전에는 `DispatchQueue`로 직접 관리했다.

```swift
DispatchQueue.global(qos: .background).async {
    let data = heavyWork()                  // 백그라운드
    DispatchQueue.main.async {
        self.label.text = data              // 메인으로 복귀
    }
}
```

공유 상태 보호도 마찬가지로 손으로 했다.

```swift
private let queue = DispatchQueue(label: "audio")
func playNote(...) { queue.async { ... } }
```

**문제는 컴파일러가 검증해 주지 않는다는 것**이다. `DispatchQueue.main.async`를 빠뜨려도, 새 메서드에 `queue.async`를 빠뜨려도 컴파일은 통과한다. 그리고 런타임에 간헐적으로 터진다.

```text
GCD 시대      "메인에서 해야 한다"를 개발자가 기억
Swift 동시성   "메인에서 해야 한다"를 타입 시스템이 강제
```

Swift 5.5의 **액터(actor)** 는 이 기억을 타입 시스템으로 옮긴 장치다.

---

# 2부(승) — `actor` 타입

## 2.1 결론 먼저

- `actor`는 **자기 상태를 한 번에 하나의 작업만 만지도록 컴파일러가 보장하는 참조 타입**이다.
- 목적은 단 하나, **data race 방지**다. 성능 향상 장치가 아니다.
- `class`에 `lock`이나 직렬 큐를 직접 붙여 하던 일을, **컴파일러가 검사해 주는 언어 기능으로 올린 것**이다.
- 대가로 밖에서 쓸 때 `await`가 필요하다.

앞의 카운터를 `actor`로 바꾸면 유실이 사라진다.

```swift
actor Counter {
    var value = 0
    func increment() { value += 1 }
}
```

```text
actor 1000회 증가: 1000 (1000이면 정상)
```

## 2.2 actor가 하는 일 — 격리와 직렬 실행

> Swift guarantees that only code running on an actor can access that actor's local state. This guarantee is known as *actor isolation*.

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

`await`는 "여기서 기다릴 수 있다"는 표시다. actor가 다른 작업을 처리 중이면 순서를 기다렸다가 들어간다.

## 2.3 안과 밖의 규칙이 다르다

actor 내부에서는 `await` 없이 자기 상태를 그냥 쓴다.

```swift
actor AudioManager {
    private var sampler: MIDISampler?

    func playNote(note: MIDINoteNumber, velocity: MIDIVelocity = 127) {
        sampler?.play(...)      // 내부라 await 불필요
    }

    func replay(note: MIDINoteNumber) {
        stopNote(note: note)    // 같은 actor 의 메서드도 await 불필요
        playNote(note: note)
    }
}
```

이미 그 actor 안에 들어와 있기 때문이다. **`await`가 필요한 건 밖에서 들어올 때뿐이다.**

| | actor 안 | actor 밖 |
| --- | --- | --- |
| 프로퍼티 읽기 | 그냥 | `await` |
| 프로퍼티 쓰기 | 그냥 | **불가능** (메서드를 통해야 함) |
| 메서드 호출 | 그냥 | `await` |

밖에서 프로퍼티에 직접 대입할 수 없다는 점이 중요하다. `counter.value = 5`는 컴파일 에러다. **상태 변경은 actor가 제공하는 메서드를 통해서만 가능하다.**

## 2.4 `struct`, `class`, `actor`

| | `struct` | `class` | `actor` |
|---|---|---|---|
| 종류 | 값 타입 | 참조 타입 | **참조 타입** |
| 복사 | 값 복사 | 참조 공유 | 참조 공유 |
| 상속 | 불가 | 가능 | **불가** |
| 동시 접근 보호 | 복사되므로 공유 없음 | **없음 (직접 해야 함)** | **컴파일러가 보장** |
| 외부 접근 | 그냥 | 그냥 | **`await` 필요** |

`actor`는 **"상속 없는 class + 자동 동기화"**로 이해하면 가깝다. 값 타입과 참조 타입의 일반적인 차이는 [`struct`와 `class`](./019-struct-vs-class.md)에 정리되어 있다.

## 2.5 언제 쓰는가

**쓰기 좋은 경우**

- 여러 곳에서 공유하는 **가변 상태**를 들고 있다
- 싱글턴처럼 앱 전체가 하나의 인스턴스를 함께 쓴다
- 캐시, 커넥션 풀, 파일 핸들, 로그 버퍼처럼 순서가 중요한 자원
- 백그라운드에서 대량 작업을 하되 상태를 안전하게 지켜야 한다

**안 써도 되는 경우**

- 상태가 없다. 순수 함수 모음이면 `enum`의 `static` 메서드나 `struct`로 충분하다
- 상태가 있지만 **UI 상태**다. 그건 `@MainActor`가 맞다
- 값 타입으로 충분하다. 공유하지 않으면 경합도 없다

## 2.6 실제 사례 — `AudioManager`

`chapter-140/chapter-140/Utils/AudioManager.swift`

```swift
actor AudioManager {
    private var engine: AudioEngine?     // ← 이 셋이 공유 가변 상태
    private var mixer: Mixer?
    private var sampler: MIDISampler?

    static let shared = AudioManager()
    private init() {}

    func setAudio() throws { ... }
    func playNote(note: MIDINoteNumber, velocity: MIDIVelocity = 127) { ... }
    func stopNote(note: MIDINoteNumber) { ... }
}
```

여기서 actor가 실제로 막고 있는 것은 이렇다.

- `PianoViewModel.init`의 `Task`가 `setAudio()`로 셋을 **초기화**한다.
- 건반을 누를 때마다 별도 `Task`가 `playNote()`로 `sampler`를 **읽는다**.
- 뗄 때마다 또 다른 `Task`가 `stopNote()`로 **읽는다**.

`actor`가 아니면 초기화가 끝나기 전에 재생 호출이 `sampler`를 읽는 상황이 가능하다. `actor`는 이 접근들을 한 줄로 세운다.

`static let shared` + `private init()`으로 싱글턴을 만든 것도 의도가 같다. **오디오 엔진은 앱에 하나만 있어야 하므로**, 인스턴스를 하나로 고정하고 그 하나를 actor로 보호한다.

역할 분담이 깔끔하게 드러난다.

```text
PianoViewModel   @MainActor   UI 상태(activeNotes), 화면 갱신
       │  await
       ▼
AudioManager     actor        오디오 엔진이라는 공유 자원
```

---

# 3부(전) — 격리 도메인: 액터는 하나가 아니다

`@MainActor`도 actor의 일종이다. 정확히는 **global actor**이며, 인스턴스가 앱 전체에 하나뿐이라는 점이 다르다. 여기서부터는 `actor`, `@MainActor`, `nonisolated`를 **하나의 개념**으로 묶는다.

## 3.1 격리 도메인은 셋뿐이다

핵심은 **"어느 액터 위에서 도는가"** 가 모든 선언에 붙는 속성이라는 점이다. 그 속성값이 곧 격리 도메인이고, 종류는 셋뿐이다.

| 도메인 | 의미 | 표기 |
| --- | --- | --- |
| **비격리(nonisolated)** | 어느 액터에도 속하지 않는다 | 아무것도 없음 또는 `nonisolated` |
| **액터 인스턴스 격리** | 특정 액터 **인스턴스** 하나에 속한다 | `actor` 안의 멤버, `isolated` 파라미터 |
| **전역 액터 격리** | 전역에 하나뿐인 액터에 속한다 | `@MainActor`, `@globalActor` 타입 |

"독립적인 액터"는 보통 둘째를, "격리된 액터"는 셋 전체를 뭉뚱그려 부르는 말이다. 정확히는 **액터가 격리된 것이 아니라, 선언이 액터에 격리된다.**

**같은 도메인 안에서는 동기 접근이 되고, 도메인을 넘으면 `await`가 필요하다. 이 규칙 하나가 전부다.**

```swift
actor Account { var balance = 0 }

func bad(_ a: Account) { a.balance += 1 }
```

```text
error: actor-isolated property 'balance' can not be mutated from a nonisolated context
note: mutation of this property is only permitted within the actor
```

**에러 문구에 도메인 이름이 그대로 등장한다.** 이 문장 구조를 읽을 줄 알면 대부분의 동시성 에러를 스스로 해결할 수 있다.

## 3.2 액터 인스턴스 격리

`actor` 타입의 멤버는 그 **인스턴스**에 격리된다. 인스턴스마다 도메인이 따로 있다는 뜻이다. `Account` 두 개를 만들면 격리 도메인도 두 개다.

이때 `self`는 **암묵적으로 `isolated`** 다. 2.3절의 "안과 밖" 차이가 여기서 나온다.

## 3.3 전역 액터 — `@MainActor`는 특별한 문법이 아니다

> A global actor is a globally-unique actor identified by a type.

`MainActor`의 선언은 이렇게 생겼다.

```swift
@globalActor final actor MainActor
```

**메인 스레드를 대표하는 전역 액터**이고, `@MainActor`가 붙은 코드는 메인 스레드에서 실행되는 것이 **컴파일 타임에 보장된다.**

`GlobalActor` 프로토콜의 요구사항은 `shared` 하나뿐이다.

> `static var shared: ActorType { get }` — the shared actor instance that will be used to provide mutually-exclusive access to declarations annotated with the given global actor type.

그래서 직접 만드는 것도 간단하다.

```swift
@globalActor
actor DataActor {
    static let shared = DataActor()
}

@DataActor
final class Cache {
    var items: [String] = []
    func add(_ s: String) { items.append(s) }   // DataActor 도메인
}
```

프로그램 어디에 있든 `@DataActor`가 붙은 선언은 **전부 같은 도메인**이므로 서로 동기 접근이 되고, 밖에서는 `await c.add("a")`가 된다.

**언제 쓰는가.** 서로 떨어져 있지만 같은 자원을 만지는 선언들을 한 도메인으로 묶고 싶을 때다. 파일 캐시, 로깅, 데이터베이스 접근처럼 "이 일은 한 번에 하나씩"이어야 하는 영역이 대표적이다. 타입 하나로 모을 수 있으면 그냥 `actor`를 쓰고, **여러 타입·전역 함수에 흩어져 있을 때** 전역 액터가 답이 된다.

## 3.4 가장 중요한 오해 — 스레드가 아니라 액터다

```text
❌ "@MainActor = 항상 main thread 에서 실행"
✅ "@MainActor = MainActor 에 isolated 되어 있다"
```

실용적으로는 메인 스레드에서 도는 것이 맞지만, **개념을 스레드로 이해하면 나머지가 틀어진다.**

- 커스텀 전역 액터는 특정 스레드에 묶이지 않는다. 보장하는 것은 "동시에 하나만"이지 "항상 같은 스레드"가 아니다
- `await` 전후로 스레드가 바뀔 수 있지만 액터 격리는 유지된다
- 컴파일러가 검사하는 것은 스레드가 아니라 격리 도메인이다

**스레드는 실행 자원이고, 액터는 접근 권한 경계다.** 둘을 분리해서 생각해야 한다.

## 3.5 `nonisolated` — 반대 방향의 표시

`nonisolated`는 **"이 선언은 어떤 액터에도 묶이지 않는다"**는 표시다. 액터 격리를 **벗어나는** 키워드다.

```text
@MainActor      →  "이건 메인 액터에서만 실행된다"       (묶는다)
nonisolated     →  "이건 아무 데서나 실행해도 안전하다"  (푼다)
```

`actor` 안에서 쓰는 모습이다.

```swift
actor AudioManager {
    private var buffer: [Float] = []        // 액터 격리 상태
    nonisolated let identifier: UUID        // 불변이라 안전

    nonisolated var debugName: String {     // 격리 상태를 안 읽는다
        "AudioManager(\(identifier))"
    }

    func append(_ sample: Float) {          // 격리됨 — await 로 호출
        buffer.append(sample)
    }
}
```

`debugName`은 `await` 없이 호출할 수 있다. 반면 `nonisolated` 안에서 `buffer`를 읽으려 하면 컴파일 오류가 난다.

```swift
nonisolated var count: Int { buffer.count }
// error: actor-isolated property 'buffer' can not be referenced
//        from a nonisolated context
```

**컴파일러가 약속을 검증한다**는 점이 중요하다. `nonisolated`는 검사를 끄는 스위치가 아니다.

### 헷갈리기 쉬운 것들

**① `nonisolated`는 "백그라운드에서 실행"이 아니다**

```text
nonisolated  =  "특정 액터에 묶이지 않는다"
             ≠  "백그라운드 스레드에서 돈다"
```

메인 스레드에서 호출하면 메인 스레드에서 실행된다. **호출한 곳에서 그대로 실행**될 뿐이고, 액터 hop이 없어질 뿐이다.

**② `nonisolated`와 `Sendable`은 다르다**

| | 무엇에 붙나 | 뜻 |
|---|---|---|
| `nonisolated` | 선언(함수·프로퍼티·타입) | 액터에 묶이지 않음 |
| `Sendable` | 타입 | 액터 경계를 넘어 전달해도 안전 |

**③ `nonisolated(unsafe)`는 최후의 수단이다**

```swift
nonisolated(unsafe) var globalCache: [String: Data] = [:]
```

검사를 **끄는** 형태다. 이름 그대로 안전을 컴파일러가 아니라 내가 보증한다. 전역 변수 마이그레이션 같은 데서만 임시로 쓴다.

## 3.6 기본 격리 설정이 판을 뒤집는다

SE-0466이 이 저장소의 설정을 설명한다.

> The `-default-isolation` flag controls default actor isolation for the entire module. Valid arguments are `MainActor` and `nonisolated`. If unspecified, the default is `nonisolated`.

Xcode 설정 이름은 `SWIFT_DEFAULT_ACTOR_ISOLATION`이다. 이 저장소를 전수 조사한 결과다.

```text
전체 챕터: 70
  SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor : 69 (chapter-109 제외)
  SWIFT_APPROACHABLE_CONCURRENCY = YES      : 70
  SWIFT_VERSION = 5.0                       : 70
```

**기본 격리가 `MainActor`로 켜져 있다.** 즉 아무것도 안 붙인 선언이 암묵적으로 `@MainActor`다. 이 사실을 모르면 `nonisolated`가 왜 필요한지, `@MainActor`가 왜 중복인지 설명이 안 된다.

```text
[기본 격리 nonisolated — 예전 방식]
  기본값: 비격리
  메인이 필요하면 → @MainActor 를 붙인다

[기본 격리 MainActor — 이 저장소]
  기본값: @MainActor
  액터를 벗어나야 하면 → nonisolated 를 붙인다
```

예외도 알아 둘 만하다. `-default-isolation MainActor`여도 **`actor` 타입 안의 선언, 명시적 격리가 있는 선언, 전역 액터를 붙일 수 없는 선언(타입알리아스, enum case 등)** 은 영향을 받지 않는다.

## 3.7 사례 연구 — `Shape.path(in:)`에 `nonisolated`가 필수인 이유

`chapter-164/chapter-164/ContentView.swift`

```swift
@Animatable
@MainActor
struct CircleShape: Shape {
    var radius: CGFloat
    // ...

    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(
                center: .init(x: rect.midX, y: rect.midY),
                radius: radius,
                startAngle: .init(degrees: startAngle),
                endAngle: .init(degrees: endAngle),
                clockwise: isClockWise
            )
        }
    }
}
```

이유는 한 줄로 요약된다. **`Shape` 프로토콜의 `path(in:)`이 `nonisolated`로 선언되어 있는데, 이 타입은 `@MainActor`라서 그대로는 요구사항을 만족할 수 없기 때문**이다. 공식 문서의 선언이 그것을 보여 준다.

```swift
nonisolated func path(in rect: CGRect) -> Path
```

`nonisolated`를 빼면 컴파일러가 아주 친절하게 설명해 준다.

```text
error: conformance of 'BadShape' to protocol 'Shape' crosses into
       main actor-isolated code and can cause data races [#ConformanceIsolation]

note: main actor-isolated instance method 'path(in:)' cannot satisfy
      nonisolated requirement
note: mark all declarations used in the conformance 'nonisolated'
note: isolate this conformance to the main actor with '@MainActor'
note: turn data races into runtime errors with '@preconcurrency'
```

핵심은 두 번째 줄이다.

```text
프로토콜이 요구하는 것:  nonisolated func path(in:) -> Path
내가 제공한 것:          @MainActor func path(in:) -> Path
        ↓
"아무 데서나 부를 수 있어야 하는 자리"에
"메인 액터에서만 부를 수 있는 것"을 넣으려 했다  → 거부
```

프로토콜 요구사항은 **계약**이다. 계약이 "어디서든 호출 가능"인데 구현이 "메인에서만 가능"이면 계약 위반이다.

### 왜 `Shape.path(in:)`은 애초에 `nonisolated`인가

SwiftUI는 도형을 **메인 스레드가 아닌 곳에서도 그릴 수 있어야** 한다. 렌더링·레이아웃 계산은 백그라운드로 내려갈 수 있고, 그때마다 메인 액터로 hop 하면 성능이 무너진다. 그리고 `path(in:)`은 안전하다.

```text
입력:  rect (값 타입)  +  self 의 저장 프로퍼티 (전부 값 타입)
출력:  Path (값 타입)
부수 효과: 없음
        ↓
공유 상태를 건드리지 않는 순수 계산 → 어느 스레드에서 돌려도 안전
```

### 컴파일러가 제시한 선택지를 실제로 시도하면

**① `nonisolated func` — 이 코드의 선택 ✓** 통과한다. 메서드 하나만 액터에서 풀어 준다.

**② 격리된 적합성(isolated conformance) — `Shape`에는 불가 ✗**

```swift
struct S2: @MainActor Shape { func path(in rect: CGRect) -> Path { ... } }
```

```text
error: cannot form main actor-isolated conformance of 'S2' to
       SendableMetatype-inheriting protocol 'Shape' [#IsolatedConformances]
```

`Shape`은 `SendableMetatype`을 상속하므로 적합성 자체를 액터에 묶을 수 없다. **컴파일러의 제안이 항상 이 상황에 맞는 것은 아니라는 좋은 예**다.

**③ 타입 전체를 `nonisolated`로 — 더 깔끔한 대안 ✓**

```swift
nonisolated struct CircleShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path { ... }   // nonisolated 불필요
}
```

```text
현재:  @MainActor struct  +  nonisolated func path   (묶었다가 하나를 품)
대안:  nonisolated struct                            (애초에 안 묶음)
```

둘 다 맞지만, 메서드가 여러 개로 늘어나면 대안 쪽이 덜 번거롭다. 참고로 `@Animatable`이 합성하는 `animatableData`에는 **매크로가 `nonisolated`를 자동으로 붙여 준다**([`@Animatable` 매크로 문서](./099-animatable-macro.md)).

### `nonisolated`를 쓰는 전형적인 상황

| 상황 | 예 |
|---|---|
| **nonisolated 프로토콜 요구사항 구현** | `Shape.path(in:)`, `Equatable.==`, `Hashable.hash(into:)` |
| **불변 상태를 읽는 접근자** | `nonisolated let id: UUID` 기반의 계산 프로퍼티 |
| **`Identifiable`, `CustomStringConvertible` 채택** | `var id`, `var description` |
| **기본 격리가 MainActor인 프로젝트의 순수 계산 함수** | 포매터, 파서, 수학 유틸 |
| **actor 안에서 액터 상태를 안 쓰는 메서드** | 상수만 다루는 헬퍼 |

## 3.8 비격리 async 함수는 두 종류다 (Swift 6.2의 변화)

`nonisolated`는 "어느 도메인에도 속하지 않는다"는 선언이다. 그런데 **비동기 함수의 경우 "속하지 않는다"가 두 가지로 갈린다.** 여기가 Swift 6.2에서 바뀐 지점이고, `SWIFT_APPROACHABLE_CONCURRENCY = YES`인 이 저장소에 직접 해당한다.

| | 의미 | 결과 |
| --- | --- | --- |
| `nonisolated(nonsending)` | 호출자의 격리를 **물려받는다** | 스레드 홉 없음 |
| `@concurrent` | 호출자를 **떠난다** | 백그라운드로 홉 |

SE-0461의 설명이다.

> nonisolated async functions ... now "run on the caller's actor by default"

실제로 확인한 결과다.

```swift
nonisolated(nonsending) func staysWithCaller() async { print(where_()) }
@concurrent            func leavesCaller()    async { print(where_()) }

@MainActor func run() async {
    await staysWithCaller()
    await leavesCaller()
}
```

```text
호출자(@MainActor): 메인
  staysWithCaller : 메인
  leavesCaller    : 백그라운드
```

**같은 "비격리"인데 실행 위치가 정반대다.** 예전 Swift에서는 `nonisolated async`가 항상 액터를 떠났다. 지금은 기본이 반대로 뒤집혔고, 떠나고 싶으면 `@concurrent`를 **명시**해야 한다.

실무 판단은 단순하다 — **무거운 CPU 작업(디코딩, 이미지 처리)만 `@concurrent`로 명시적으로 내보내고**, 나머지는 호출자를 따라가게 둔다.

## 3.9 `isolated` 파라미터 — 액터를 인자로 받기

격리는 `self`에만 붙는 것이 아니다. **아무 파라미터나 `isolated`로 표시하면 그 함수는 그 액터의 도메인에서 실행된다.**

```swift
actor Account { var balance = 0 }

func deposit(_ amount: Int, to account: isolated Account) {
    account.balance += amount      // await 없이 동기 접근
}
```

SE-0313의 규칙이다.

> A given function cannot have multiple `isolated` parameters.

호출부에서 갈린다.

```swift
deposit(100, to: self)          // 내가 그 액터면 동기
await deposit(100, to: other)   // 아니면 await
```

**왜 필요한가.** 액터의 로직을 메서드로만 쓸 수 있으면 확장이 막힌다. `isolated` 파라미터를 쓰면 액터 밖의 자유 함수나 제네릭 유틸리티도 액터 도메인 안에서 동작할 수 있다. `isolated` 파라미터는 **동적**이다 — 어떤 액터를 넘기느냐에 따라 실행 도메인이 달라진다.

## 3.10 `#isolation` — 호출자의 격리를 물려받기

SE-0420은 여기서 한 걸음 더 나간다. `isolated` 파라미터를 **옵셔널**로 만들고, 기본값으로 `#isolation`을 주면 **호출자의 격리가 자동으로 흘러들어온다.**

```swift
func logHere(isolation: isolated (any Actor)? = #isolation) async {
    print("caller isolation:", isolation.map { "\(type(of: $0))" } ?? "nonisolated")
}
```

`@MainActor` 함수에서 부른 결과다.

```text
caller isolation: MainActor
```

규칙은 이렇다.

> if the current context is statically non-isolated, the parameter must have optional type, and the argument is `nil`; if the current context is isolated to a global actor `T`, the argument is `T.shared`.

표준 라이브러리의 `AsyncIteratorProtocol.next(isolation:)`가 이 형태를 쓴다. **비Sendable 값을 경계 넘김 없이 다룰 수 있게** 해 주는 것이 핵심 이점이다.

---

# 4부(전) — 메인 액터를 실전에서 다루는 법

## 4.1 네 가지 도구

`@MainActor` 경계를 넘나드는 방법이 여러 개라 늘 헷갈린다. 한자리에 놓고 비교한다.

| | `await MainActor.run { }` | `Task { @MainActor in }` | `@MainActor func` | `MainActor.assumeIsolated { }` |
| --- | --- | --- | --- | --- |
| 하는 일 | 메인 액터로 **전환하고 기다린다** | 메인 액터에서 도는 **새 작업 생성** | 함수 전체를 격리 | 이미 메인이라고 **단언** |
| 호출부에서 대기 | **예** (`await`) | **아니오** — 바로 다음 줄로 | 예 | 동기 실행 |
| 반환값 | 받을 수 있다 | 받기 어렵다 | 받을 수 있다 | 받을 수 있다 |
| 취소 연결 | 현재 작업에 붙는다 | **비구조적 — 끊어진다** | 붙는다 | 해당 없음 |
| 오류 전파 | `try await`으로 전파 | **전파되지 않는다** | 전파된다 | 전파된다 |
| 메인이 아니면 | 전환해 준다 | 전환해 준다 | 전환해 준다 | **크래시** |

두 가지를 기억하면 된다.

**① `Task { @MainActor in }`의 결정적 차이는 "기다리지 않는다"는 것**이다.

```swift
func fetchPosts() async {
    let (data, _) = try await URLSession.shared.data(from: url)

    Task { @MainActor in
        posts = try decoder.decode(Results.self, from: data)   // 나중에 실행된다
    }
    // ← 여기로 즉시 넘어온다. 위 작업이 끝나기를 기다리지 않는다
}                                                              // 함수가 먼저 끝날 수 있다
```

**② `assumeIsolated`는 전환이 아니라 확인이다.**

```swift
await MainActor.run { ui.text = "갱신됨" }     // 전환 — 메인으로 건너간다
MainActor.assumeIsolated { ui.text }           // 확인 — 이미 메인임을 단언
```

컴파일러가 정적으로 증명하지 못하는 경우(대표적으로 UIKit 델리게이트 콜백)에 쓴다. 실제로 그 액터가 아니면 **크래시한다.** 이 구분을 놓치면 "왜 가끔 죽는지" 알 수 없게 된다.

## 4.2 `Task { }`는 만들어진 자리의 액터를 상속한다

```text
호출자: 메인 / 우선순위 TaskPriority.medium
  Task{}        : 메인 / TaskPriority.high
  Task.detached : 백그라운드 / TaskPriority.medium
```

그래서 `@MainActor` 문맥에서 만든 `Task { }` 안에서는 UI 상태를 그냥 바꿀 수 있고, `MainActor.run`이 필요 없다.

```swift
@MainActor
func onTap() {
    Task {                       // 메인 액터를 상속
        let data = await load()  // 중단 — 이 사이 다른 일 진행
        self.items = data        // 다시 메인 액터, 그냥 대입 가능
    }
}
```

`Task.detached`는 상속을 끊으므로 같은 코드가 에러가 된다. **UI를 만지는 작업에 `Task.detached`를 쓰지 않는 이유다.**

## 4.3 사례 ① — `MainActor.run`이 두 번 나오는 코드

`chapter-65/chapter-65/ContentView.swift`

```swift
Task(priority: .background) {
    await receiveNotifications()
}

private func receiveNotifications() async {
    for await notification in center.notifications(named: name) {
        if let userInfo = notification.userInfo,
           let moreInfo = userInfo["Course"] as? DTCourse {
            await MainActor.run {
                additionalInfo = "\(moreInfo.name) by: \(moreInfo.author)"
            }
        }
        await MainActor.run {
            counter += 1
        }
    }
}
```

`counter`는 `@State` 프로퍼티다. **SwiftUI의 `View`와 `@State`는 `@MainActor`에 격리되어 있다.** 백그라운드에서 직접 건드리면 Swift 6 언어 모드에서 컴파일 에러다.

```text
error: main actor-isolated property 'counter' can not be mutated from a nonisolated context
```

`MainActor.run`의 시그니처를 보면 왜 이것이 경계를 넘는 수단인지 알 수 있다.

```swift
static func run<T>(resultType: T.Type = T.self,
                   body: @MainActor @Sendable () throws -> T) async rethrows -> T
```

파라미터 `body`에 **`@MainActor`가 붙어 있다.**

### 더 나은 방법들

**① `@MainActor` 함수로 만든다** — 같은 파일의 다른 코드가 이미 이 방식이다.

```swift
@MainActor
private func receiveNotifications() async {
    for await notification in center.notifications(named: name) {
        if let moreInfo = notification.userInfo?["Course"] as? DTCourse {
            additionalInfo = "\(moreInfo.name) by: \(moreInfo.author)"
        }
        counter += 1
    }
}
```

`MainActor.run` 두 개가 사라진다. **"메인 액터에서 도는데 UI가 멈추지 않나?"** 걱정할 수 있지만 아니다. `for await`은 값을 기다리는 동안 **실행을 중단하고 스레드를 놓아준다**([for await 문서](./105-for-await-async-sequence.md)).

**② `.task`로 뷰 생명주기에 묶는다**

```swift
.task { await receiveNotifications() }    // 자동 취소
```

**③ `onReceive`에 맡긴다** — 메인 스레드를 보장하므로 `MainActor` 코드가 전부 사라진다([NotificationCenter 문서](./109-notification-center.md)).

참고로 `Task(priority: .background)`는 **의도는 이해되지만 실효가 없다.** 결국 `MainActor.run`으로 메인에 넘기므로 백그라운드에서 하는 일이 없고, 알림 대기는 CPU를 쓰지 않아 우선순위가 의미를 갖지 않는다([TaskPriority 문서](./104-task-priority-and-scheduling.md)).

## 4.4 사례 ② — `Task { @MainActor in }`이 만든 세 가지 문제

`chapter-88/chapter-88/Services/NetworkManager.swift`

```swift
let (data, _) = try await URLSession.shared.data(from: url)
let decoder = JSONDecoder()

Task { @MainActor in
    let results = try decoder.decode(Results.self, from: data)
    posts = results.hits
}
```

**① 오류가 사라진다.** `Task`의 클로저가 throwing이면 `Task<Void, Error>`가 만들어지고, 오류는 그 `Task`의 `value`나 `result`로만 꺼낼 수 있다. 여기서는 `Task`를 변수에 담지도 않으므로 **오류가 조용히 버려진다.** 바깥의 `catch`도 잡지 못한다.

```swift
do {
    let (data, _) = try await URLSession.shared.data(from: url)
    Task { @MainActor in
        try decoder.decode(...)      // 이 오류는
    }
} catch {
    print(error)                     // ← 여기로 오지 않는다
}
```

**② 취소가 연결되지 않는다.** `.task { await networkManager.fetchPosts() }`로 호출하므로 뷰가 사라지면 `fetchPosts`는 취소된다. 하지만 **안에서 만든 `Task`는 별개**라 계속 실행된다.

**③ 디코딩을 메인 액터에서 한다.** `decode`는 CPU 작업이다. 항목이 많으면 메인 스레드를 점유해 UI가 멈춘다.

### 권장하는 형태

```swift
@Observable
final class NetworkManager {
    var posts = [Post]()

    @MainActor
    func fetchPosts() async throws {
        guard let url = URL(string: "https://hn.algolia.com/api/v1/search?tags=story") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let results = try JSONDecoder().decode(Results.self, from: data)
        posts = results.hits
    }
}
```

`Task`, `MainActor.run`이 모두 사라진다. **`await` 지점에서 스레드를 놓아주므로 UI를 막지 않는다.** 뷰에서 오류를 처리한다.

```swift
.task {
    do { try await networkManager.fetchPosts() }
    catch { errorMessage = error.localizedDescription }
}
```

디코딩까지 백그라운드로 분리하려면 대입 지점만 넘긴다.

```swift
func fetchPosts() async throws {
    let (data, _) = try await URLSession.shared.data(from: url)
    let results = try JSONDecoder().decode(Results.self, from: data)   // 백그라운드

    await MainActor.run {
        posts = results.hits                                            // 메인
    }
}
```

요령은 **오류가 나는 코드를 `MainActor.run` 밖에 두는 것**이다. `try`가 안에 있으면 오류 전파가 복잡해진다.

### 그럼 `Task { @MainActor in }`은 언제 쓰나

**"결과를 기다릴 필요가 없는 UI 갱신"** 에는 유효하다.

```swift
func handleNotification(_ note: Notification) {      // 동기 콜백
    Task { @MainActor in
        self.badgeCount += 1                          // await 할 필요 없다
    }
}
```

동기 문맥에서는 `await MainActor.run`을 쓸 수 없으므로 이 방법이 필요하다. **하지만 이미 `async` 함수 안이라면** `MainActor.run`이나 `@MainActor` 함수가 낫다.

## 4.5 `@MainActor`를 붙이는 위치

| 위치 | 효과 |
| --- | --- |
| `@MainActor func` | 그 함수만 |
| `@MainActor class` / `struct` | **모든 멤버가** 메인 액터에 격리 |
| `@MainActor var` | 그 프로퍼티만 |
| 클로저 파라미터 | 그 클로저 |

**SwiftUI의 `View`는 이미 `@MainActor`다.** 문제는 **`Task`나 `async` 함수로 격리를 벗어났다가 돌아올 때** 생긴다.

**타입 전체에 붙이는 편이 메서드마다 붙이는 것보다 낫다.** 격리가 타입의 성질이 되어 빠뜨릴 수 없다.

```swift
@MainActor
@Observable
final class SystemNotificationExample { ... }
```

---

# 5부(전) — 액터가 막아 주지 **않는** 것

## 5.1 재진입(reentrancy) — 가장 큰 함정

**actor는 "한 번에 하나"를 보장하지만 "중간에 끼어들지 않음"을 보장하지 않는다.**

`await`를 만나면 actor는 중단되고, **그 사이 다른 호출이 actor에 들어올 수 있다.** 직접 재현했다.

```swift
actor Bank {
    var balance = 100
    func withdraw(_ amount: Int, tag: String) async -> Bool {
        guard balance >= amount else { return false }   // ① 검사
        try? await Task.sleep(for: .milliseconds(50))    // ② 중단 — 여기서 끼어든다
        balance -= amount                                 // ③ 반영
        return true
    }
}

async let w1 = bank.withdraw(100, tag: "A")
async let w2 = bank.withdraw(100, tag: "B")
```

```text
② 잔액 100에서 100씩 두 번 출금 → -100 (음수면 재진입 문제)
   A 검사통과 balance=100
   B 검사통과 balance=100     ← A 가 중단된 사이에 B 가 들어왔다
   A 차감후 balance=0
   B 차감후 balance=-100
```

**잔액 100에서 100씩 빠져나가 -100이 됐다.** actor를 썼는데도 논리가 깨졌다. 원인은 `await`가 있는 자리에서 **검사와 반영 사이가 벌어졌기** 때문이다.

**actor는 데이터 경합은 막지만 논리적 경합까지 막지는 않는다.**

### 어떻게 막나

**① 검사와 반영 사이에 `await`를 두지 않는다.** 가장 확실하다.

```swift
func withdraw(_ amount: Int) -> Bool {      // async 가 아니다 = 중단점이 없다
    guard balance >= amount else { return false }
    balance -= amount
    return true
}
```

**② `await` 이후에 상태를 다시 검사한다.**

```swift
try await someDelay()
guard balance >= amount else { return false }   // 다시 확인
balance -= amount
```

**③ 진행 중 표시를 둔다.**

```swift
var inFlight: Set<String> = []
guard !inFlight.contains(id) else { return false }
inFlight.insert(id)
defer { inFlight.remove(id) }
```

**경험칙 — actor 메서드에서 `await`를 만나면, 그 앞에서 읽은 모든 상태는 낡았다고 가정한다.**

## 5.2 `Sendable` — 경계를 넘는 값

도메인이 나뉘면 그 사이로 오가는 값이 안전한지 따져야 한다. 그 계약이 `Sendable`이다.

**`Sendable`은 "액터 경계를 안전하게 넘을 수 있는 타입"을 나타내는 프로토콜**이다. 값 타입이거나 내부적으로 동기화가 보장되어야 한다.

```swift
await audioManager.playNote(note: note.midiNote)   // MIDINoteNumber 는 값 타입
```

이 코드가 `PianoNote` 객체 대신 `midiNote`(숫자)만 넘기는 것도 같은 맥락이다. 클래스 인스턴스를 그대로 넘기려 하면 컴파일러가 막는다. SwiftData의 model 객체가 `Sendable`이 아닌 것과 같은 규칙이다([SwiftData 동시성 문서](./132-swiftdata-concurrency-and-context-isolation.md)).

### `@unchecked Sendable`은 안전 보장을 끄는 것이다

```swift
extension NotificationCenter: @unchecked Sendable {}    // chapter-65
```

`@unchecked`는 **"컴파일러 검증을 끄고 내가 책임진다"** 는 선언이다. 컴파일 경고를 없애는 가장 빠른 방법이지만, **안전 보장도 함께 사라진다.** `NotificationCenter`는 실제로 스레드 안전하게 구현되어 있어 이 선언이 사실과 다르지는 않지만, **최신 SDK에서는 이미 `Sendable`로 표시되어 있어** 이 extension 자체가 불필요할 수 있다.

**일반론으로는 `@unchecked Sendable`을 남발하면 안 된다.** 컴파일러가 잡아 주려던 문제를 눈감는 것이다.

### 영역 기반 격리 — 요즘은 덜 엄격하다

**영역 기반 격리(region-based isolation, SE-0414)** 는 컴파일러가 값의 "영역"을 추적해서, 한쪽에서 더 이상 쓰지 않는 것이 증명되면 **비`Sendable` 값도 경계를 넘길 수 있게** 해 준다. SE-0430의 `sending` 키워드가 그 계약을 API에 명시하는 수단이다. 자세한 것은 [`Sendable`과 엄격 검사](./149-sendable-and-strict-concurrency.md)에 있다.

## 5.3 비용 — actor는 공짜가 아니다

actor 호출은 이미 그 actor 안에 있지 않다면 **실행 문맥을 옮기는 비용(hop)** 이 든다.

```text
@MainActor PianoViewModel
      │  Task { await ... }   ← 여기서 전환
      ▼
actor AudioManager
```

건반을 누를 때마다 이 전환이 일어난다. 사람이 느낄 수준인지는 **측정해서 판단**한다. 실시간 오디오처럼 지연에 민감한 영역에서는 actor 대신 전용 실시간 스레드를 쓰기도 한다.

**"actor니까 안전하고 빠르다"는 결론은 성립하지 않는다. 안전과 성능은 다른 질문이다.**

실무 지침은 이렇다.

- actor 메서드를 **잘게 여러 번 호출하지 말고 한 번에 묶어서** 처리한다. `hop_to_executor`가 그만큼 줄어든다([컴파일 모델 문서](./152-async-function-compilation-model.md)).
- Swift 6.2에서 비격리 async 함수의 기본이 `nonisolated(nonsending)`으로 바뀐 것도 **불필요한 hop을 줄이려는 변경**이다.

---

# 6부(결) — 설계 지침

## 6.1 무엇에 무엇을 붙이나

| 대상 | 권장 |
| --- | --- |
| ViewModel (UI 상태 보유) | **타입 전체에 `@MainActor`** |
| SwiftUI `View` | 이미 `@MainActor` (붙일 필요 없음) |
| 네트워크·파일 서비스 | 붙이지 않음 (호출자를 따라가게) |
| 공유 가변 상태 (캐시, 엔진, 풀) | **`actor`** |
| 흩어진 선언을 한 도메인으로 | `@globalActor` |
| 순수 계산 함수 | `nonisolated` |
| 무거운 CPU 작업 | `@concurrent` |
| UI 상태 | actor에 **넣지 않는다** |

## 6.2 한 장 요약

```text
문제
  data race → 비결정적 버그, 정의되지 않은 동작
  UI 는 메인 스레드에서만 (UI 프레임워크가 스레드 안전하지 않다)
  GCD 는 이 규칙을 컴파일러가 검사해 주지 않았다

해결: 격리 도메인을 타입 시스템에 넣었다
  도메인은 셋뿐
    비격리 / 액터 인스턴스 / 전역 액터
  같은 도메인 = 동기 접근
  다른 도메인 = await + Sendable

어느 도메인에 속하는지 정하는 방법
  ① actor 타입 안           → 그 인스턴스 (self 가 암묵적 isolated)
  ② @MainActor, @globalActor → 그 전역 액터
  ③ isolated 파라미터        → 인자로 받은 액터 (동적)
  ④ #isolation 기본값        → 호출자의 액터를 물려받음
  ⑤ 아무것도 없음            → 모듈 기본값 (이 저장소는 MainActor)

비동기 비격리 함수는 두 종류다
  nonisolated(nonsending) → 호출자를 따라간다 (6.2 기본)
  @concurrent             → 호출자를 떠난다 (명시해야 함)

actor 가 막아 주지 않는 것
  재진입   — await 앞에서 읽은 상태는 낡았다고 가정한다
  논리 경합 — 검사와 반영 사이에 중단점을 두지 않는다
  비용     — hop 은 공짜가 아니다. 호출을 묶어라

@MainActor 도구 네 개
  @MainActor func        함수/타입 전체 격리 — 기본 선택
  await MainActor.run    전환하고 기다린다 — 대입 지점만 넘길 때
  Task { @MainActor in } 새 작업 — 동기 콜백에서만, 오류·취소가 끊긴다
  assumeIsolated         확인이지 전환이 아니다 — 아니면 크래시
```

---

## 학습 체크리스트

### 문제 인식

- [ ] `class` 카운터를 `TaskGroup`으로 10만 번 증가시켜 값이 유실되는 것을 확인한다.
- [ ] 같은 코드를 여러 번 실행해 결과가 매번 다른 것(비결정성)을 확인한다.
- [ ] `actor`로 바꿔 값이 정확해지는 것을 확인한다.
- [ ] `DispatchQueue.main.async`로 같은 코드를 작성하고 `MainActor.run`과 비교한다.

### `actor` 기본

- [ ] `actor`를 `class`로 바꿔 보고 어떤 컴파일 오류가 사라지는지(= 무엇을 잃는지) 확인한다.
- [ ] `await` 없이 actor 메서드를 호출해 오류 메시지를 직접 읽는다.
- [ ] actor 밖에서 프로퍼티에 직접 대입해 컴파일 에러를 확인한다.
- [ ] actor 내부 메서드끼리는 왜 `await`가 필요 없는지 설명한다.
- [ ] `struct`, `class`, `actor`의 차이를 표로 직접 채운다.

### 격리 도메인

- [ ] `actor Account`를 만들고 밖에서 `balance`를 직접 건드려 에러 문구에 "nonisolated context"가 나오는지 확인한다.
- [ ] `@globalActor actor DataActor`를 직접 만들고 `@DataActor` 클래스에 접근해 본다.
- [ ] 같은 `@DataActor` 선언 두 개가 서로 `await` 없이 접근되는지 확인한다.
- [ ] `isolated Account` 파라미터를 받는 자유 함수를 만들고, `self`와 다른 인스턴스를 넘길 때 `await` 유무가 달라지는지 본다.
- [ ] `isolated` 파라미터를 두 개 선언해 "cannot have multiple isolated parameters" 에러를 확인한다.
- [ ] `isolation: isolated (any Actor)? = #isolation` 함수를 만들어 `@MainActor`와 비격리 문맥에서 각각 호출해 출력 차이를 본다.
- [ ] `nonisolated(nonsending)`과 `@concurrent` 함수를 만들어 `Thread.isMainThread`를 찍고 실행 위치를 비교한다.

### `nonisolated`

- [ ] `@MainActor`와 `nonisolated`를 "묶는다/푼다"로 구분해 설명한다.
- [ ] `chapter-164.xcodeproj`에서 `SWIFT_DEFAULT_ACTOR_ISOLATION` 값을 직접 확인한다.
- [ ] `path(in:)`의 `nonisolated`를 지우고 오류 메시지 전체를 읽는다.
- [ ] 오류의 네 가지 note 중 어떤 것이 이 상황에 맞는지 판단해 본다.
- [ ] `struct S: @MainActor Shape` 형태를 시도하고 왜 실패하는지 확인한다.
- [ ] `nonisolated struct`로 바꿔 보고 메서드의 `nonisolated`가 불필요해지는 것을 본다.
- [ ] `actor` 안에 `nonisolated` 메서드를 만들고 격리 상태를 읽어 오류를 확인한다.
- [ ] `nonisolated` 함수가 어느 스레드에서 도는지 `Thread.isMainThread`로 찍어 본다.
- [ ] `nonisolated`와 `Sendable`의 차이를 한 문장씩으로 정리한다.

### `@MainActor` 실전

- [ ] `MainActor.run`을 지우고 직접 `counter += 1`을 해서 어떤 경고·에러가 나는지 본다.
- [ ] Swift 언어 모드를 6으로 올리고 같은 코드가 컴파일 에러가 되는지 확인한다.
- [ ] `receiveNotifications()`에 `@MainActor`를 붙이고 `MainActor.run`을 모두 제거해 본다.
- [ ] 그 상태에서 UI가 멈추지 않는 것을 확인한다 (`for await`이 스레드를 놓아준다).
- [ ] `Thread.isMainThread`를 출력해 각 지점의 스레드를 확인한다.
- [ ] `onAppear` + `Task`를 `.task`로 바꾸고, 다시 `onReceive` 방식으로 바꿔 `MainActor` 코드가 사라지는 것을 확인한다.
- [ ] `@MainActor` 문맥에서 `Task { }`와 `Task.detached { }`의 차이를 `Thread.isMainThread`로 비교한다.
- [ ] `Task.detached` 안에서 UI 상태를 바꿔 에러를 확인한다.
- [ ] `MainActor.assumeIsolated`를 메인이 아닌 곳에서 호출해 크래시하는 것을 확인한다.
- [ ] Xcode의 Main Thread Checker를 켜고 백그라운드 UI 갱신 시 경고를 확인한다.

### 함정

- [ ] `Bank` 재진입 예제를 재현해 잔액이 음수가 되는 것을 확인한다.
- [ ] `withdraw`에서 `await`를 제거해 문제가 사라지는지 확인한다.
- [ ] `await` 이후 재검사를 넣는 방식으로도 고쳐 본다.
- [ ] actor에 클래스 인스턴스(비`Sendable`)를 넘기려 할 때 나오는 오류를 확인한다.
- [ ] `chapter-65`의 `@unchecked Sendable` 확장을 지우고 어떤 에러가 나오는지, 어떻게 고쳐야 하는지 본다.
- [ ] actor 메서드를 잘게 여러 번 호출하는 코드와 한 번에 처리하는 코드의 시간을 비교한다.
- [ ] 건반을 누른 뒤 소리가 날 때까지의 지연을 측정해 actor hop 비용을 가늠한다.

### 저장소 설정

- [ ] `chapter-109`와 다른 챕터의 `SWIFT_DEFAULT_ACTOR_ISOLATION` 설정 차이를 직접 확인한다.
- [ ] 한 챕터의 설정을 `nonisolated`로 바꿔 보고 어떤 에러가 새로 나오는지 관찰한다.

---

## 공식 참고 자료

### Swift Evolution 제안서 (1차 자료)

- [SE-0306: Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md)
- [SE-0306: Actor reentrancy (제안서 내 절)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md#actor-reentrancy)
- [SE-0313: Improved control over actor isolation (`isolated` 파라미터)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0313-actor-isolation-control.md)
- [SE-0316: Global actors (`@globalActor`)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md)
- [SE-0337: Incremental migration to concurrency checking](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md)
- [SE-0414: Region based isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md)
- [SE-0420: Inheritance of actor isolation (`#isolation`)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)
- [SE-0430: `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- [SE-0449: Allow `nonisolated` to prevent global actor inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0449-nonisolated-for-global-actor-cutoff.md)
- [SE-0461: Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- [SE-0466: Control default actor isolation inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)

### Apple 공식 문서

- [Apple: Actor](https://developer.apple.com/documentation/swift/actor)
- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Apple: MainActor.run(resultType:body:)](https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:))
- [Apple: MainActor.assumeIsolated(_:file:line:)](https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:))
- [Apple: GlobalActor](https://developer.apple.com/documentation/swift/globalactor)
- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)
- [Apple: isolation()](https://developer.apple.com/documentation/swift/isolation())
- [Apple: Updating an app to use strict concurrency](https://developer.apple.com/documentation/swift/updating-an-app-to-use-strict-concurrency)
- [SwiftUI: Shape — path(in:)](https://developer.apple.com/documentation/swiftui/shape/path(in:))
- [Apple: Dispatch](https://developer.apple.com/documentation/dispatch)
- [Apple: DispatchQueue.main](https://developer.apple.com/documentation/dispatch/dispatchqueue/main)

### Swift 공식 문서

- [Swift Book: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift Book: Concurrency — Actors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)
- [Swift Book: Concurrency — Sendable Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types)
- [Swift Book: Declaration Modifiers — nonisolated](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Declaration-Modifiers)
- [Swift Book: Memory Safety](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/memorysafety/)

### 마이그레이션·진단

- [Swift.org: Migrating to Swift 6](https://www.swift.org/migration/documentation/migrationguide/)
- [Swift.org: Data Race Safety (격리 도메인 개념)](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/)
- [Swift 컴파일러 진단: actor-isolated call](https://docs.swift.org/compiler/documentation/diagnostics/actor-isolated-call/)
- [Swift 컴파일러 진단: Conformance Isolation](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation)

### 영상

- [WWDC21: Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races using Swift Concurrency](https://developer.apple.com/videos/play/wwdc2022/110351/)
- [WWDC25: Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
