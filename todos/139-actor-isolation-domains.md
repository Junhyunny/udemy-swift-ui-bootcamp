# 액터 격리 — 격리 도메인, 전역 액터, `isolated` 파라미터

`actor` 타입의 기본은 [`actor` 타입 문서](./107-swift-actor-type.md)에, `MainActor`와 스레드 모델은 [iOS의 스레드 모델](./106-main-actor-and-ios-threading.md)에, `nonisolated` 키워드는 [액터 밖에서도 안전하다는 선언](./108-nonisolated-keyword.md)에 정리했다.

이 문서는 그 셋을 **하나의 개념 — 격리 도메인(isolation domain)** 으로 묶어 본다. "격리된 액터", "독립적인 액터"라는 말이 실제로 무엇을 가리키는지, 그리고 한 코드가 **어느 도메인에 속하는지 결정하는 규칙 전체**를 다룬다.

이 문서의 모든 코드는 **Swift 6.3.3 툴체인에서 `-swift-version 6` 으로 직접 컴파일·실행해 확인**했다. 출력이 실린 것은 전부 실측값이다.

## 출발점 — 이 저장소의 설정

빌드 설정을 전부 조사한 결과다.

```text
전체 챕터: 70  |  SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor: 69
SWIFT_APPROACHABLE_CONCURRENCY = YES: 전체
SWIFT_VERSION = 5.0: 전체
```

`chapter-109`를 뺀 모든 챕터가 **기본 격리를 `MainActor`로 켜 두었다.** 즉 아무것도 안 붙인 선언이 암묵적으로 `@MainActor`다. 이 사실을 모르면 `nonisolated`가 왜 필요한지, `@MainActor`가 왜 중복인지 설명이 안 된다. 근거는 아래 6부에 있다.

## 공부할 내용

### 격리 도메인이란 무엇인가

액터 격리의 정의는 한 줄이다.

> Swift guarantees that only code running on an actor can access that actor's local state. This guarantee is known as *actor isolation*.

여기서 핵심은 **"어느 액터 위에서 도는가"** 가 모든 선언에 붙는 속성이라는 점이다. 그 속성값이 곧 격리 도메인이고, 종류는 **셋뿐이다.**

| 도메인 | 의미 | 표기 |
| --- | --- | --- |
| **비격리(nonisolated)** | 어느 액터에도 속하지 않는다 | 아무것도 없음 또는 `nonisolated` |
| **액터 인스턴스 격리** | 특정 액터 **인스턴스** 하나에 속한다 | `actor` 안의 멤버, `isolated` 파라미터 |
| **전역 액터 격리** | 전역에 하나뿐인 액터에 속한다 | `@MainActor`, `@globalActor` 타입 |

"독립적인 액터"는 보통 둘째를, "격리된 액터"는 셋 전체를 뭉뚱그려 부르는 말이다. 정확히는 **액터가 격리된 것이 아니라, 선언이 액터에 격리된다.**

같은 도메인 안에서는 동기 접근이 되고, 도메인을 넘으면 `await`가 필요하다. 이 규칙 하나가 전부다.

```swift
actor Account { var balance = 0 }

func bad(_ a: Account) { a.balance += 1 }
```

```text
error: actor-isolated property 'balance' can not be mutated from a nonisolated context
note: mutation of this property is only permitted within the actor
```

컴파일러 메시지가 정확히 "nonisolated context에서 actor-isolated 프로퍼티를 건드렸다"고 말한다. **도메인 이름이 그대로 에러 문구에 등장한다.**

### 1부 — 액터 인스턴스 격리

`actor` 타입의 멤버는 그 **인스턴스**에 격리된다. 인스턴스마다 도메인이 따로 있다는 뜻이다. `Account` 두 개를 만들면 격리 도메인도 두 개다.

이때 `self`는 **암묵적으로 `isolated`** 다. `actor` 안의 메서드는 `self`의 상태에 동기 접근할 수 있고, 밖에서는 `await`로만 닿는다. 안과 밖의 규칙 차이는 [107 문서](./107-swift-actor-type.md)의 "안과 밖의 규칙이 다르다" 절에 정리되어 있다.

### 2부 — 전역 액터는 직접 만들 수 있다

`@MainActor`는 특별한 문법이 아니라 **전역 액터의 한 사례**다.

> A global actor is a globally-unique actor identified by a type.

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

`Cache`의 모든 멤버가 `DataActor`에 격리된다. 프로그램 어디에 있든 `@DataActor`가 붙은 선언은 **전부 같은 도메인**이므로 서로 동기 접근이 되고, 밖에서는 `await c.add("a")`가 된다.

**언제 쓰는가.** 서로 떨어져 있지만 같은 자원을 만지는 선언들을 한 도메인으로 묶고 싶을 때다. 파일 캐시, 로깅, 데이터베이스 접근처럼 "이 일은 한 번에 하나씩"이어야 하는 영역이 대표적이다. 타입 하나로 모을 수 있으면 그냥 `actor`를 쓰고, **여러 타입·전역 함수에 흩어져 있을 때** 전역 액터가 답이 된다.

> 주의: `@MainActor`가 붙은 것은 메인 **스레드**가 아니라 메인 **액터**다. 커스텀 전역 액터는 특정 스레드에 묶이지 않는다. 보장하는 것은 "동시에 하나만 실행된다"이지 "항상 같은 스레드"가 아니다.

### 3부 — 비격리와 격리 상속 (Swift 6.2 이후 크게 바뀐 부분)

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

### 4부 — `isolated` 파라미터: 액터를 인자로 받기

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

### 5부 — `#isolation`: 호출자의 격리를 물려받기

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

`nil`이면 비격리로, 값이 있으면 그 액터 도메인으로 동작한다. 표준 라이브러리의 `AsyncIteratorProtocol.next(isolation:)`가 이 형태를 쓴다. **비Sendable 값을 경계 넘김 없이 다룰 수 있게** 해 주는 것이 핵심 이점이다.

### 6부 — 기본 격리 설정이 판을 뒤집는다

SE-0466이 이 저장소의 설정을 설명한다.

> The `-default-isolation` flag controls default actor isolation for the entire module. Valid arguments are `MainActor` and `nonisolated`. If unspecified, the default is `nonisolated`.

Xcode 설정 이름이 `SWIFT_DEFAULT_ACTOR_ISOLATION`이고, 이 저장소는 70개 중 69개 챕터가 `MainActor`다.

```text
[기본 격리 nonisolated — 예전 방식]
  기본값: 비격리
  메인이 필요하면 → @MainActor 를 붙인다

[기본 격리 MainActor — 이 저장소]
  기본값: @MainActor
  액터를 벗어나야 하면 → nonisolated 를 붙인다
```

예외도 알아 둘 만하다. `-default-isolation MainActor`여도 **`actor` 타입 안의 선언, 명시적 격리가 있는 선언, 전역 액터를 붙일 수 없는 선언(타입알리아스, enum case 등)** 은 영향을 받지 않는다.

`chapter-164`의 `Shape.path(in:)`에 `nonisolated`가 **필수**인 이유가 여기 있다. 자세한 재현은 [108 문서](./108-nonisolated-keyword.md)에 있다.

### 7부 — 경계를 넘는 값: `Sendable`

도메인이 나뉘면 그 사이로 오가는 값이 안전한지 따져야 한다. 그 계약이 `Sendable`이다. 기본은 [106 문서](./106-main-actor-and-ios-threading.md)의 `Sendable` 절에 있다.

여기서 더 알아 둘 것은 **영역 기반 격리(region-based isolation, SE-0414)** 다. 컴파일러가 값의 "영역"을 추적해서, 한쪽에서 더 이상 쓰지 않는 것이 증명되면 **비`Sendable` 값도 경계를 넘길 수 있게** 해 준다. SE-0430의 `sending` 키워드가 그 계약을 API에 명시하는 수단이다.

`chapter-65`의 `extension NotificationCenter: @unchecked Sendable {}`은 이 계약을 **검사 없이 선언만 한 것**이라 위험하다. 그 파일의 `FIXME`가 지적하는 내용이다.

### 8부 — 런타임에 격리를 확인하기

컴파일러가 정적으로 증명하지 못하는 경우(대표적으로 UIKit 델리게이트 콜백)에는 동적 확인을 쓴다.

```swift
nonisolated func readFromKnownMainThread(_ m: Model) -> Int {
    MainActor.assumeIsolated { m.value }   // "지금 메인이다"를 단언하고 동기 접근
}

@MainActor func run() {
    MainActor.assertIsolated("메인이어야 한다")
}
```

`assumeIsolated`는 **확인이지 전환이 아니다.** 실제로 그 액터가 아니면 크래시한다. 액터로 **옮기고** 싶으면 `await`나 `Task { @MainActor in }`을 써야 한다. 이 구분을 놓치면 "왜 가끔 죽는지" 알 수 없게 된다.

### 정리

```text
격리 도메인은 셋뿐이다
  비격리 / 액터 인스턴스 / 전역 액터

어느 도메인에 속하는지 정하는 방법
  ① actor 타입 안       → 그 인스턴스 (self 가 암묵적 isolated)
  ② @MainActor, @globalActor → 그 전역 액터
  ③ isolated 파라미터    → 인자로 받은 액터 (동적)
  ④ #isolation 기본값    → 호출자의 액터를 물려받음
  ⑤ 아무것도 없음        → 모듈 기본값 (이 저장소는 MainActor)

같은 도메인 = 동기 접근
다른 도메인 = await + Sendable

비동기 비격리 함수는 두 종류다
  nonisolated(nonsending) → 호출자를 따라간다 (6.2 기본)
  @concurrent             → 호출자를 떠난다 (명시해야 함)
```

## 학습 체크리스트

- [ ] `actor Account`를 만들고 밖에서 `balance`를 직접 건드려 에러 문구에 "nonisolated context"가 나오는지 확인한다.
- [ ] `@globalActor actor DataActor`를 직접 만들고 `@DataActor` 클래스에 접근해 본다.
- [ ] 같은 `@DataActor` 선언 두 개가 서로 `await` 없이 접근되는지 확인한다.
- [ ] `nonisolated(nonsending)`과 `@concurrent` 함수를 만들어 `Thread.isMainThread`를 찍고 실행 위치를 비교한다.
- [ ] `@concurrent` 함수에 비`Sendable` 값을 넘겨 보고 에러를 확인한다.
- [ ] `isolated Account` 파라미터를 받는 자유 함수를 만들고, `self`와 다른 인스턴스를 넘길 때 `await` 유무가 달라지는지 본다.
- [ ] `isolated` 파라미터를 두 개 선언해 "cannot have multiple isolated parameters" 에러를 확인한다.
- [ ] `isolation: isolated (any Actor)? = #isolation` 함수를 만들어 `@MainActor`와 비격리 문맥에서 각각 호출해 출력 차이를 본다.
- [ ] `chapter-109`와 다른 챕터의 `SWIFT_DEFAULT_ACTOR_ISOLATION` 설정 차이를 직접 확인한다.
- [ ] 한 챕터의 설정을 `nonisolated`로 바꿔 보고 어떤 에러가 새로 나오는지 관찰한다.
- [ ] `MainActor.assumeIsolated`를 메인이 아닌 곳에서 호출해 크래시하는 것을 확인한다.
- [ ] `chapter-65`의 `@unchecked Sendable` 확장을 지우고 어떤 에러가 나오는지, 어떻게 고쳐야 하는지 본다.

## 공식 참고 자료

### Swift Evolution 제안서 (1차 자료)

- [SE-0306: Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md)
- [SE-0313: Improved control over actor isolation (`isolated` 파라미터)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0313-actor-isolation-control.md)
- [SE-0316: Global actors (`@globalActor`)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md)
- [SE-0414: Region based isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md)
- [SE-0420: Inheritance of actor isolation (`#isolation`)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md)
- [SE-0430: `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- [SE-0449: Allow `nonisolated` to prevent global actor inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0449-nonisolated-for-global-actor-cutoff.md)
- [SE-0461: Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- [SE-0466: Control default actor isolation inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)

### Apple 공식 문서

- [Apple: GlobalActor](https://developer.apple.com/documentation/swift/globalactor)
- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Apple: MainActor.assumeIsolated(_:file:line:)](https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:))
- [Apple: isolation()](https://developer.apple.com/documentation/swift/isolation())
- [Apple: Actor](https://developer.apple.com/documentation/swift/actor)
- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)
- [Swift Book: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

### 마이그레이션·진단

- [Swift.org: Migrating to Swift 6](https://www.swift.org/migration/documentation/migrationguide/)
- [Swift.org: Data Race Safety (격리 도메인 개념)](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/)
- [Swift 컴파일러 진단: actor-isolated call](https://docs.swift.org/compiler/documentation/diagnostics/actor-isolated-call/)

### 영상

- [WWDC21: Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races using Swift Concurrency](https://developer.apple.com/videos/play/wwdc2022/110351/)
- [WWDC25: Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
