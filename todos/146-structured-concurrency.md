# 4단계 — 구조적 동시성: `async let`과 `TaskGroup`

[로드맵](./142-swift-concurrency-roadmap.md)의 4단계다. 2단계에서 확인한 "`await`를 나열하면 순차 실행된다"는 문제를 여기서 푼다.

## 구조적이라는 말의 뜻

**자식 작업의 수명이 부모 범위를 벗어나지 않는다**는 뜻이다. 부모 함수가 반환하기 전에 자식은 반드시 끝나거나 취소된다.

```text
[비구조적 — Task { }]            [구조적 — async let / TaskGroup]
  부모 ──── 반환                   부모 ─────────────── 반환
   └─ Task ──── 계속 살아있음        ├─ 자식1 ──┐
                                    └─ 자식2 ──┴─ 여기서 모두 정리됨
```

이 성질에서 세 가지가 공짜로 따라온다.

- **누수가 없다** — 부모가 끝나면 자식도 끝난다
- **취소가 전파된다** — 부모를 취소하면 자식도 취소된다
- **에러가 전파된다** — 자식이 던지면 부모가 받는다

3단계의 `Task { }`는 이 중 아무것도 보장하지 않는다. **그래서 가능하면 구조적 동시성을 먼저 고려한다.**

## `async let` — 개수가 고정일 때

```swift
async let x = work("A", ms: 300)
async let y = work("B", ms: 300)
let (rx, ry) = await (x, y)
```

`async let`은 선언 즉시 자식 작업을 시작하고, `await`할 때 결과를 거둔다. 측정 결과다.

```text
① 순차 await : AB — 0.64s
① async let  : AB — 0.32s
```

**0.64초가 0.32초가 된다.** 서로 의존하지 않는 작업이라면 이렇게 겹쳐야 한다.

주의할 점이 둘이다.

- `async let`으로 선언한 값은 **반드시 `await`해야 한다.** 안 하면 범위를 벗어날 때 자동 취소된다.
- 던지는 함수라면 `try await`로 받는다. 하나라도 던지면 나머지는 취소된다.

## `TaskGroup` — 개수가 동적일 때

작업 수가 런타임에 정해지면 `async let`으로는 안 된다.

```swift
let results = await withTaskGroup(of: String.self) { group in
    for n in ["A","B","C","D"] {
        group.addTask { await work(n, ms: 300) }
    }
    var acc: [String] = []
    for await r in group { acc.append(r) }
    return acc.sorted()
}
```

```text
② TaskGroup 4개 : ABCD — 0.31s
```

0.3초짜리 작업 넷이 0.31초에 끝났다. **완전히 겹쳐서 실행된다.**

기억할 점들이다.

- **결과 순서는 보장되지 않는다.** 먼저 끝난 것부터 나온다. 위 예제가 `sorted()`를 쓰는 이유다. 순서가 필요하면 인덱스를 함께 넘긴다.
- 던지는 작업은 `withThrowingTaskGroup`을 쓴다.
- 자식이 던지면 나머지 자식이 자동 취소된다.
- `group.addTask`의 클로저는 경계를 넘으므로 **`Sendable` 제약**을 받는다(7단계).

### 어느 쪽을 쓰나

| 상황 | 선택 |
| --- | --- |
| 작업 2~3개, 개수 고정, 타입이 서로 다름 | `async let` |
| 개수가 런타임에 정해짐, 배열 순회 | `TaskGroup` |
| 결과를 모두 모아야 함 | 둘 다 가능 |
| 먼저 끝난 하나만 필요 | `TaskGroup` + 첫 결과에서 탈출 |

## 취소 전파 — 직접 확인

구조적 동시성의 가장 큰 이점이다.

```swift
let parent = Task {
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            do { try await Task.sleep(for: .seconds(5)); print("자식 정상 종료") }
            catch { print("자식이 취소 감지: \(type(of: error))") }
        }
    }
}
try? await Task.sleep(for: .milliseconds(100))
parent.cancel()
```

```text
③ 자식이 취소 감지: CancellationError
```

부모를 취소했더니 **5초를 기다리던 자식이 즉시 `CancellationError`를 받았다.** `Task { }`를 중첩했다면 이런 전파가 없다.

## 동시성이 항상 이득은 아니다

- 작업이 짧으면 오버헤드가 이득보다 클 수 있다
- 서버에 동시 요청을 많이 보내면 오히려 느려지거나 차단당한다 — `TaskGroup`에 동시 실행 개수 제한을 직접 구현해야 한다
- 순서가 중요한 작업은 겹치면 안 된다

**의존 관계가 없는 작업만 겹친다.** `let token = try await fetchToken()` 다음에 그 토큰을 쓰는 호출은 순차가 맞다.

## 테스트하기 좋아진다

구조적 동시성 코드는 `await`로 완료를 기다릴 수 있어 테스트가 쉽다. 시간에 의존하는 로직은 `Clock`을 주입해 실제로 기다리지 않고 검증한다.

```swift
protocol DelayProviding { func sleep(for: Duration) async throws }

func runTimer(clock: DelayProviding) async { ... }   // 테스트에서 가짜 clock 주입
```

주입 방식은 [의존성 주입 문서](./123-dependency-injection-for-testing.md)와 같다.

## 학습 체크리스트

- [ ] 0.3초 작업 둘을 순차 `await`와 `async let`으로 각각 실행해 시간을 측정한다.
- [ ] `async let`으로 선언하고 `await`하지 않은 채 범위를 벗어나 본다.
- [ ] `async let` 중 하나가 던지게 만들고 나머지가 취소되는지 확인한다.
- [ ] `withTaskGroup`으로 작업 10개를 돌려 결과 순서가 보장되지 않는 것을 확인한다.
- [ ] 인덱스를 함께 반환해 순서를 복원해 본다.
- [ ] `withThrowingTaskGroup`에서 자식 하나가 던질 때 나머지가 취소되는지 확인한다.
- [ ] 부모 `Task`를 취소해 `TaskGroup` 자식이 `CancellationError`를 받는지 확인한다.
- [ ] 같은 구조를 `Task { }` 중첩으로 만들어 취소가 전파되지 않는 것을 비교한다.
- [ ] `TaskGroup`에 동시 실행 개수 제한(예: 4개)을 직접 구현한다.

## 공식 참고 자료

- [Swift Book: Concurrency — Tasks and Task Groups](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Tasks-and-Task-Groups)
- [Apple: withTaskGroup(of:returning:body:)](https://developer.apple.com/documentation/swift/withtaskgroup(of:returning:isolation:body:))
- [Apple: withThrowingTaskGroup(of:returning:body:)](https://developer.apple.com/documentation/swift/withthrowingtaskgroup(of:returning:isolation:body:))
- [Apple: TaskGroup](https://developer.apple.com/documentation/swift/taskgroup)
- [Apple: Clock](https://developer.apple.com/documentation/swift/clock)
- [SE-0304: Structured concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
- [SE-0317: `async let` bindings](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0317-async-let.md)
- [WWDC21: Explore structured concurrency in Swift](https://developer.apple.com/videos/play/wwdc2021/10134/)
