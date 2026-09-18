# Swift Concurrency 학습 로드맵 — 전체 지도와 순서

`actor`, `@MainActor`, `Task`, `async/await`, `Sendable`, `MainActor.run`, `Task.yield()`는 따로 떨어진 기능이 아니라 **Swift Concurrency라는 하나의 실행 모델** 안에 있는 연관 개념이다. 하나씩 사용법만 외우면 "왜 여기서 `await`가 필요한가", "왜 이 에러가 나는가"에 답할 수 없다.

이 문서는 **전체 지도와 학습 순서**를 담은 인덱스다. 각 단계는 별도 문서로 나뉘어 있다.

## 전체 지도

```text
Swift Concurrency
│
├─ async / await ──────────────────── 143, 144
│
├─ Task ───────────────────────────── 145
│   ├─ Task { } / Task.detached { }
│   ├─ cancellation
│   └─ Task.sleep / Task.yield
│
├─ Structured Concurrency ─────────── 146
│   ├─ async let
│   └─ TaskGroup
│
├─ Actor ──────────────────────────── 147
│   ├─ actor isolation
│   └─ reentrancy
│
├─ Global Actor ───────────────────── 148
│   └─ @MainActor / MainActor.run / nonisolated
│
├─ Data race safety ───────────────── 149
│   └─ Sendable / 영역 기반 격리 / Swift 6 에러
│
└─ SwiftUI와 연결 ─────────────────── 150
    ├─ .task { } / .task(id:)
    ├─ @MainActor + @Observable
    └─ UI 갱신 흐름
```

## 학습 순서와 문서

| 단계 | 주제 | 문서 | 기존 문서 |
| --- | --- | --- | --- |
| 1 | 동기 vs 비동기, 중단(suspension) | [143](./143-sync-vs-async-and-suspension.md) | [101](./101-swift-async-await-model.md) |
| 2 | `async` / `await` / `try await` | [144](./144-async-await-basics.md) | [102](./102-async-throws-and-custom-errors.md), [105](./105-for-await-async-sequence.md) |
| 3 | `Task`와 취소 | [145](./145-task-basics-and-cancellation.md) | [103](./103-task-modifier-and-async-lifecycle.md), [104](./104-task-priority-and-scheduling.md) |
| 4 | 구조적 동시성 | [146](./146-structured-concurrency.md) | — |
| 5 | `actor`와 재진입 | [147](./147-actor-and-reentrancy.md) | [107](./107-swift-actor-type.md) |
| 6 | `@MainActor`와 전역 액터 | [148](./148-main-actor-and-global-actors.md) | [106](./106-main-actor-and-ios-threading.md), [108](./108-nonisolated-keyword.md), [139](./139-actor-isolation-domains.md) |
| 7 | `Sendable`과 엄격 검사 | [149](./149-sendable-and-strict-concurrency.md) | — |
| 8 | SwiftUI와 연결 | [150](./150-swiftui-concurrency-integration.md) | [103](./103-task-modifier-and-async-lifecycle.md), [050](./050-observation-framework-and-observable.md) |

**5~7단계가 Swift 6에서 특히 중요해졌다.** 예전에는 경고도 없던 코드가 엄격 검사에서 다음 세 가지 에러를 만든다. 셋 다 149에서 읽는 법을 다룬다.

```text
main actor-isolated property 'name' can not be mutated from a nonisolated context
sending value of non-Sendable type '...' risks causing data races
value of optional type ... (이건 옵셔널 — 141 참조)
```

## 곁가지로 나오는 것들

학습 중 자주 마주치는데 어디에 속하는지 헷갈리는 것들이다.

| 궁금증 | 답이 있는 곳 |
| --- | --- |
| `Task.yield()`는 왜 필요한가 | [145](./145-task-basics-and-cancellation.md) |
| `withCheckedContinuation`은 왜 존재하는가 | [143](./143-sync-vs-async-and-suspension.md) |
| `Task { }` 안의 액터 컨텍스트는 어떻게 정해지나 | [145](./145-task-basics-and-cancellation.md), [148](./148-main-actor-and-global-actors.md) |
| `@MainActor`는 왜 붙이는가 | [148](./148-main-actor-and-global-actors.md) |
| async 코드는 어떻게 테스트하나 | [146](./146-structured-concurrency.md), [123](./123-dependency-injection-for-testing.md) |
| Combine과는 어떤 관계인가 | [114](./114-combine-vs-async-await.md) |
| `Timer`·`NotificationCenter`를 async로 받으려면 | [105](./105-for-await-async-sequence.md), [110](./110-timer-publisher-and-onreceive.md) |

## 이 저장소의 설정

문서의 예제를 실행할 때 전제가 되는 값이다. 전수 조사 결과다.

```text
전체 챕터 70개 중
  SWIFT_APPROACHABLE_CONCURRENCY = YES        : 70
  SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor   : 69 (chapter-109 제외)
  SWIFT_VERSION = 5.0                         : 70
```

**기본 격리가 `MainActor`이고 Swift 5 모드**다. 그래서 대부분의 코드가 아무것도 안 붙여도 메인 액터에서 돌고, Swift 6 엄격 검사 에러는 아직 경고로만 나온다. 7단계를 공부한 뒤 `SWIFT_VERSION`을 6으로 올려 보면 무엇이 걸리는지 확인할 수 있다.

## 진행 체크

- [ ] 1단계 — [동기 vs 비동기와 중단](./143-sync-vs-async-and-suspension.md)
- [ ] 2단계 — [`async`/`await` 기초](./144-async-await-basics.md)
- [ ] 3단계 — [`Task`와 취소](./145-task-basics-and-cancellation.md)
- [ ] 4단계 — [구조적 동시성](./146-structured-concurrency.md)
- [ ] 5단계 — [`actor`와 재진입](./147-actor-and-reentrancy.md)
- [ ] 6단계 — [`@MainActor`와 전역 액터](./148-main-actor-and-global-actors.md)
- [ ] 7단계 — [`Sendable`과 엄격 검사](./149-sendable-and-strict-concurrency.md)
- [ ] 8단계 — [SwiftUI와 연결](./150-swiftui-concurrency-integration.md)
- [ ] 마무리 — 작은 예제 앱 하나에 1~8단계를 전부 연결해 본다

## 공식 참고 자료

- [Swift Book: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift.org: Migrating to Swift 6](https://www.swift.org/migration/documentation/migrationguide/)
- [Apple: Concurrency (Swift 표준 라이브러리)](https://developer.apple.com/documentation/swift/concurrency)
- [WWDC21: Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Explore structured concurrency in Swift](https://developer.apple.com/videos/play/wwdc2021/10134/)
- [WWDC21: Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC22: Eliminate data races using Swift Concurrency](https://developer.apple.com/videos/play/wwdc2022/110351/)
- [WWDC25: Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
