# `nonisolated` — "이 코드는 액터 밖에서도 안전하다"는 선언

## 질문이 나온 코드

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

`nonisolated`가 무엇이고, 언제 왜 쓰는지가 질문이다.

## 공부할 내용

### 결론 먼저

`nonisolated`는 **"이 선언은 어떤 액터에도 묶이지 않는다"**는 표시다. 액터 격리를 **벗어나는** 키워드다.

```text
@MainActor      →  "이건 메인 액터에서만 실행된다"       (묶는다)
nonisolated     →  "이건 아무 데서나 실행해도 안전하다"  (푼다)
```

이 코드에서 필요했던 이유는 한 줄로 요약된다. **`Shape` 프로토콜의 `path(in:)`이 `nonisolated`로 선언되어 있는데, 이 타입은 `@MainActor`라서 그대로는 요구사항을 만족할 수 없기 때문**이다.

공식 문서의 `Shape.path(in:)` 선언이 그것을 보여 준다.

```swift
nonisolated func path(in rect: CGRect) -> Path
```

### 배경 — 액터 격리가 무엇인가

TSPL의 정의다.

> Swift guarantees that only code running on an actor can access that actor's local state. This guarantee is known as *actor isolation*.

`@MainActor`는 그중 메인 스레드를 담당하는 전역 액터다.

> To ensure a function always runs on the main actor, mark it with the `@MainActor` attribute.
>
> You can also write `@MainActor` on a structure, class, or enumeration to ensure all of its methods and all access to its properties run on the main actor.

`@MainActor`가 타입에 붙으면 **그 안의 모든 메서드와 프로퍼티 접근이 메인 액터 소속**이 된다. 액터와 `@MainActor`의 기본은 [`actor` 타입 문서](./swift-actor-type.md)와 [`MainActor`와 iOS 스레드 모델 문서](./main-actor-and-ios-threading.md)에 정리되어 있다.

### 이 프로젝트의 중요한 설정

`chapter-164.xcodeproj`의 빌드 설정을 보면 이렇다.

```text
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
```

**기본 액터 격리가 `MainActor`**로 켜져 있다. 즉 **아무것도 안 붙여도 파일 안의 모든 선언이 암묵적으로 `@MainActor`**다. TSPL의 설명이 이 기능을 가리킨다.

> If there's a specific function or property that you want to exclude from `using @MainActor`, you can use the `nonisolated` modifier on that declaration to override the default.

이 설정이 켜져 있으면 판이 뒤집힌다.

```text
[기본 격리 끔 — 예전 방식]
  기본값: nonisolated
  메인 스레드가 필요하면 → @MainActor 를 붙인다

[기본 격리 MainActor — 이 프로젝트]
  기본값: @MainActor
  액터를 벗어나야 하면 → nonisolated 를 붙인다
```

그래서 `struct CircleShape`에 붙은 `@MainActor`는 **사실 중복**이고(안 붙여도 `@MainActor`다), 반대로 `path(in:)`의 `nonisolated`가 **필수**가 된다.

### `nonisolated`를 빼면 나오는 오류

직접 재현해 보면 컴파일러가 아주 친절하게 설명해 준다.

```swift
@MainActor
struct BadShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path { Path() }   // nonisolated 없음
}
```

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

### 왜 `Shape.path(in:)`은 `nonisolated`여야 하나

SwiftUI는 도형을 **메인 스레드가 아닌 곳에서도 그릴 수 있어야** 한다. 렌더링·레이아웃 계산은 백그라운드로 내려갈 수 있고, 그때마다 메인 액터로 hop 하면 성능이 무너진다.

`path(in:)`이 안전한 이유는 그 성격에 있다.

```text
입력:  rect (값 타입)  +  self 의 저장 프로퍼티 (전부 값 타입)
출력:  Path (값 타입)
부수 효과: 없음
        ↓
공유 상태를 건드리지 않는 순수 계산 → 어느 스레드에서 돌려도 안전
```

`nonisolated`는 이 사실을 **컴파일러에게 약속**하는 키워드다. 그리고 컴파일러는 그 약속을 검사한다 — `nonisolated` 함수 안에서 액터 격리 상태를 건드리면 오류를 낸다.

### 세 가지 해결책과 실제 결과

컴파일러가 제시한 선택지를 실제로 컴파일해 보면 결과가 갈린다.

**① `nonisolated func` — 이 코드의 선택 ✓**

```swift
@MainActor
struct CircleShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path { ... }
}
```

통과한다. 메서드 하나만 액터에서 풀어 준다.

**② 격리된 적합성(isolated conformance) — `Shape`에는 불가 ✗**

```swift
struct S2: @MainActor Shape {
    func path(in rect: CGRect) -> Path { ... }
}
```

컴파일러가 안내하지만 `Shape`에는 통하지 않는다.

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

이것도 통과한다. 애초에 이 도형에는 메인 액터가 필요 없으므로, **`@MainActor`를 붙였다가 메서드에서 다시 푸는 것보다 처음부터 안 묶는 편**이 의도가 분명하다.

```text
현재:  @MainActor struct  +  nonisolated func path   (묶었다가 하나를 품)
대안:  nonisolated struct                            (애초에 안 묶음)
```

둘 다 맞지만, 프로퍼티가 늘어나 메서드가 여러 개가 되면 대안 쪽이 덜 번거롭다.

### `nonisolated`를 쓰는 전형적인 상황

| 상황 | 예 |
|---|---|
| **nonisolated 프로토콜 요구사항 구현** | `Shape.path(in:)`, `Equatable.==`, `Hashable.hash(into:)` |
| **불변 상태를 읽는 접근자** | `nonisolated let id: UUID` 기반의 계산 프로퍼티 |
| **`Identifiable`, `CustomStringConvertible` 채택** | `var id`, `var description` |
| **기본 격리가 MainActor인 프로젝트의 순수 계산 함수** | 포매터, 파서, 수학 유틸 |
| **actor 안에서 액터 상태를 안 쓰는 메서드** | 상수만 다루는 헬퍼 |

actor 안에서 쓰는 모습은 이렇다.

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

**④ Swift 6.2의 `nonisolated(nonsending)`**

```swift
nonisolated(nonsending) func load() async -> Data { ... }
```

`async` 함수가 **호출자의 액터에서 이어서 실행**되게 한다([SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)). 위의 `SWIFT_APPROACHABLE_CONCURRENCY = YES`가 켜는 기능 묶음에 포함된다. 동기 함수인 `path(in:)`과는 무관하다.

### 이 코드에 적용하면

```swift
@Animatable
@MainActor
struct CircleShape: Shape {
    var radius: CGFloat
    var startAngle: Double
    var endAngle: Double
    @AnimatableIgnored var isClockWise: Bool

    nonisolated func path(in rect: CGRect) -> Path { ... }
}
```

```text
프로젝트 설정: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
        ↓
모든 선언이 암묵적으로 @MainActor  (struct 의 @MainActor 는 사실 중복)
        ↓
Shape 프로토콜은 nonisolated func path(in:) 를 요구
        ↓
@MainActor path(in:) 로는 그 요구를 만족할 수 없음
        ↓
nonisolated 를 붙여 이 메서드만 액터에서 푼다
        ↓
path(in:) 은 값 타입만 읽고 값 타입을 반환하는 순수 계산이라 안전
```

참고로 `@Animatable`이 합성하는 `animatableData`에도 **매크로가 `nonisolated`를 자동으로 붙여 준다.** 같은 이유(`Animatable` 요구사항이 `nonisolated`)이고, 그래서 그쪽은 손댈 일이 없다. [`@Animatable` 매크로 문서](./animatable-macro.md)의 확장 결과에서 확인할 수 있다.

## 체크리스트

- [ ] `@MainActor`와 `nonisolated`를 "묶는다/푼다"로 구분해 설명한다.
- [ ] `chapter-164.xcodeproj`에서 `SWIFT_DEFAULT_ACTOR_ISOLATION` 값을 직접 확인한다.
- [ ] `path(in:)`의 `nonisolated`를 지우고 오류 메시지 전체를 읽는다.
- [ ] 오류의 네 가지 note 중 어떤 것이 이 상황에 맞는지 판단해 본다.
- [ ] `struct S: @MainActor Shape` 형태를 시도하고 왜 실패하는지 확인한다.
- [ ] `nonisolated struct`로 바꿔 보고 메서드의 `nonisolated`가 불필요해지는 것을 본다.
- [ ] `struct`의 `@MainActor`를 지워도 빌드되는지 확인한다.
- [ ] `actor` 안에 `nonisolated` 메서드를 만들고 격리 상태를 읽어 오류를 확인한다.
- [ ] `nonisolated` 함수가 어느 스레드에서 도는지 `Thread.isMainThread`로 찍어 본다.
- [ ] `Shape.path(in:)`의 공식 선언에 `nonisolated`가 있는 것을 문서에서 확인한다.
- [ ] `nonisolated`와 `Sendable`의 차이를 한 문장씩으로 정리한다.

## 공식 참고 자료

- [The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [The Swift Programming Language: Declaration Modifiers — nonisolated](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Declaration-Modifiers)
- [Swift 컴파일러 진단 문서: Conformance Isolation](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation)
- [SwiftUI: Shape — path(in:)](https://developer.apple.com/documentation/swiftui/shape/path(in:))
- [Swift: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Swift Migration Guide: Data Race Safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety)
- [SE-0306: Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md)
- [SE-0316: Global actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md)
- [SE-0461: Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- [SE-0466: Control default actor isolation inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)
