# 7단계 — `Sendable`과 Swift 6 엄격 검사

[로드맵](./142-swift-concurrency-roadmap.md)의 7단계다. 5~6단계에서 격리 경계를 배웠다면, 여기서는 **그 경계를 넘어가는 값**을 다룬다.

관련 기존 문서: [Swift 액터 완전 정복](./153-swift-actor-complete-guide.md)의 5.2절 `Sendable`

## `Sendable`은 "경계를 넘어도 안전하다"는 계약이다

격리 도메인이 다르면 값이 그 사이를 오간다. 그 값이 참조 타입이고 가변이면, 양쪽에서 동시에 만져 5단계에서 본 data race가 난다.

`Sendable`은 **"이 타입은 경계를 넘겨도 안전하다"** 를 타입 시스템에 선언하는 프로토콜이다. 요구사항은 없고 표시만 한다.

| 타입 | `Sendable`인가 |
| --- | --- |
| `Int`, `String`, `Bool` 등 값 타입 | **자동으로 그렇다** |
| `struct` / `enum` (멤버가 전부 Sendable) | **자동으로 추론된다** |
| `actor` | **항상 그렇다** (스스로 보호하므로) |
| `final class` + 불변 프로퍼티만 | 명시하면 된다 |
| 가변 상태를 가진 `class` | **아니다** |
| 클로저 | `@Sendable`로 표시해야 한다 |

핵심 판단 기준은 **"공유된 채로 동시에 변경될 수 있는가"** 다. 값 타입은 복사되므로 안전하고, 클래스는 참조가 공유되므로 위험하다.

## Swift 6에서 만나는 에러 세 가지

엄격 검사가 켜지면 예전에 조용하던 코드가 에러를 낸다. 실제로 재현한 것들이다.

### ① 액터 격리 위반

```text
error: main actor-isolated property 'name' can not be mutated from a nonisolated context
```

6단계에서 다룬 에러다. "격리된 상태를 격리 밖에서 만졌다"는 뜻이다.

### ② 경계를 넘기는 값이 안전하지 않음

```swift
final class Box { var value = 0 }        // Sendable 아님
func bad() {
    let box = Box()
    Task.detached { box.value += 1 }
    print(box.value)                      // 넘긴 뒤 여기서 또 쓴다
}
```

```text
error: sending value of non-Sendable type '() async -> ()' risks causing data races
       [#RegionIsolation::SendingRisksDataRace]
note: Passing value of non-Sendable type '() async -> ()' as a 'sending' argument
      to static method 'detached(name:priority:operation:)' risks causing races
      in between local and caller code
note: access can happen concurrently
```

**`note`까지 읽는 것이 중요하다.** "local과 caller 코드 사이에서 동시 접근이 일어날 수 있다"고 정확히 지적한다.

### ③ 비Sendable 타입이 경계를 넘음

`Non-sendable type ... cannot cross actor boundary` 계열이다. 보통 모델 객체를 액터 안팎으로 주고받을 때 나온다.

## 영역 기반 격리 — 컴파일러는 생각보다 똑똑하다

여기서 놀라운 점이 있다. **위 코드에서 `print(box.value)` 한 줄만 빼면 통과한다.**

```swift
func ok() {
    let box = Box()
    Task.detached { box.value += 1 }      // 이후 안 씀 → 통과 ✅
}
func bad() {
    let box = Box()
    Task.detached { box.value += 1 }
    print(box.value)                       // 넘긴 뒤 다시 씀 → 에러 ❌
}
```

`Box`는 두 경우 모두 `Sendable`이 아닌데 결과가 다르다. **영역 기반 격리(region-based isolation, SE-0414)** 때문이다.

컴파일러가 값의 "영역"을 추적해서, **넘긴 쪽에서 더 이상 그 값을 쓰지 않는 것이 증명되면** 비`Sendable` 값도 경계를 넘길 수 있게 허용한다. 소유권을 완전히 넘겼으니 동시 접근이 불가능하다는 논리다.

그래서 에러를 만났을 때 첫 번째로 시도할 것은 `@unchecked Sendable`을 붙이는 것이 아니라 **"넘긴 뒤에 그 값을 또 쓰고 있지 않은지"** 확인하는 것이다.

이 계약을 API에 명시하는 수단이 `sending` 키워드(SE-0430)다.

## `@unchecked Sendable`은 마지막 수단이다

```swift
extension NotificationCenter: @unchecked Sendable {}   // chapter-65 의 실제 코드
```

`@unchecked`는 **"검사하지 말고 믿어라"** 는 뜻이다. 컴파일러 경고를 끌 뿐 실제 안전성은 아무것도 보장하지 않는다. 특히 위 예처럼 **내가 소유하지 않은 타입에 붙이는 소급 적합성(retroactive conformance)** 은 위험하다.

- 애플이 나중에 같은 conformance를 추가하면 중복 선언으로 빌드가 깨진다
- 다른 모듈이 같은 선언을 하면 충돌한다
- 실제로 스레드 안전하지 않다면 문제는 그대로 남는다

정당한 경우는 **내부적으로 락으로 보호하는 내 타입**에 붙일 때 정도다.

```swift
final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]      // lock 으로만 접근
}
```

이런 경우조차 `actor`로 바꾸는 편이 대개 낫다.

## `@Sendable` 클로저

클로저는 기본적으로 `Sendable`이 아니다. 경계를 넘는 클로저는 표시가 필요하다.

```swift
func run(_ operation: @Sendable @escaping () -> Void) { ... }
```

`@Sendable` 클로저는 **캡처하는 값도 전부 `Sendable`이어야 한다.** `Task { }`, `TaskGroup.addTask`, `Task.detached`의 클로저가 여기 해당한다. "왜 이 클로저에서 `self`를 캡처하면 에러가 나는가"의 답이 보통 이것이다.

## 이 저장소에서 확인할 수 있는 것

전수 조사 결과 70개 챕터 전부가 `SWIFT_VERSION = 5.0`이다. 즉 **엄격 검사가 아직 경고 수준**이다.

한 챕터의 `SWIFT_VERSION`을 6으로 올려 보면 위 세 가지 에러가 실제로 어떤 코드에서 나오는지 확인할 수 있다. 특히 `chapter-65`의 `@unchecked Sendable` 확장과 `chapter-94`의 `UIScreen.main` 접근이 좋은 실험 대상이다.

## 마이그레이션 순서

한 번에 Swift 6로 올리면 에러가 수백 개 쏟아진다. 권장 순서가 있다.

1. Swift 5 모드에서 **엄격 검사를 `minimal` → `targeted` → `complete`** 로 단계적으로 올린다
2. 경고를 유형별로 정리한다 (격리 위반 / 비Sendable / 클로저)
3. 모델 타입을 `struct`로 바꿀 수 있는지 먼저 본다 — 가장 싸게 해결된다
4. 공유 가변 상태는 `actor`로 옮긴다
5. UI 상태 보유 타입에 `@MainActor`를 붙인다
6. 마지막에 `SWIFT_VERSION`을 6으로 올린다

**`@unchecked Sendable`로 경고를 끄는 것은 마이그레이션이 아니라 연기다.**

## 학습 체크리스트

- [ ] `struct`와 `class`를 각각 `Task.detached`에 넘겨 어느 쪽이 에러인지 확인한다.
- [ ] 비`Sendable` 클래스를 넘긴 뒤 다시 쓰지 않으면 통과하는 것을 확인한다.
- [ ] 같은 코드에서 넘긴 뒤 한 줄만 추가해 에러가 나는 것을 비교한다.
- [ ] 에러의 `note`까지 읽고 어느 지점이 동시 접근인지 파악한다.
- [ ] 가변 상태를 가진 클래스를 `actor`로 바꿔 에러가 사라지는지 확인한다.
- [ ] 같은 클래스에 `@unchecked Sendable`을 붙여 에러만 사라지고 문제는 남는 것을 확인한다.
- [ ] `@Sendable` 클로저에서 비`Sendable` 값을 캡처해 에러를 본다.
- [ ] `chapter-65`의 `extension NotificationCenter: @unchecked Sendable {}`을 지우고 어떤 에러가 나오는지 확인한다.
- [ ] 한 챕터의 `SWIFT_VERSION`을 6으로 올려 에러 목록을 유형별로 분류한다.
- [ ] `SWIFT_STRICT_CONCURRENCY`를 `targeted` → `complete`로 단계적으로 올려 경고 수를 비교한다.

## 공식 참고 자료

- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)
- [Swift Book: Concurrency — Sendable Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types)
- [Swift.org: Migrating to Swift 6](https://www.swift.org/migration/documentation/migrationguide/)
- [Swift.org: Data Race Safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/)
- [Swift.org: Common Compiler Errors (마이그레이션 가이드)](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems/)
- [SE-0302: Sendable and @Sendable closures](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
- [SE-0414: Region based isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md)
- [SE-0430: `sending` parameter and result values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- [WWDC22: Eliminate data races using Swift Concurrency](https://developer.apple.com/videos/play/wwdc2022/110351/)
