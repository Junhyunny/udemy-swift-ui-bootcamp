# 3단계 — `Task`와 취소

[로드맵](./142-swift-concurrency-roadmap.md)의 3단계다. `async` 함수를 **실제로 실행시키는 단위**가 `Task`다.

관련 기존 문서: [`.task` modifier와 비동기 생명주기](./103-task-modifier-and-async-lifecycle.md), [`TaskPriority`](./104-task-priority-and-scheduling.md)

## `Task`는 비동기 세계로 들어가는 문이다

동기 코드에서 `async` 함수를 부르려면 문맥이 필요하다. `Task { }`가 그 문맥을 만든다.

```swift
Button("Load") {
    Task { await viewModel.load() }   // 동기 클로저 → 비동기 문맥
}
```

`Task`는 **생성 즉시 실행이 예약**된다. 반환값이 필요하면 `await task.value`, 던질 수 있으면 `try await task.value`로 받는다.

## `Task { }`와 `Task.detached { }` — 상속하느냐 아니냐

가장 중요한 차이다. 직접 측정했다.

```swift
@MainActor
func inheritance() async {
    print("호출자: \(now()) / 우선순위 \(Task.currentPriority)")
    await Task(priority: .high) { print("Task{}        : \(now()) / \(Task.currentPriority)") }.value
    await Task.detached      { print("Task.detached : \(now()) / \(Task.currentPriority)") }.value
}
```

```text
② 호출자: 메인 / 우선순위 TaskPriority.medium
   Task{}        : 메인 / TaskPriority.high
   Task.detached : 백그라운드 / TaskPriority.medium
```

| | `Task { }` | `Task.detached { }` |
| --- | --- | --- |
| 액터 컨텍스트 | **상속한다** (메인에서 만들면 메인) | 상속하지 않는다 (백그라운드) |
| 우선순위 | 상속 (명시하면 그 값) | 상속하지 않음 |
| 취소 전파 | 상속하지 않음(비구조적) | 상속하지 않음 |
| 태스크 로컬 값 | 상속 | 상속하지 않음 |

**`Task { }`가 기본이고 `Task.detached`는 예외다.** `@MainActor` 문맥에서 `Task { }`를 만들면 그 안도 메인 액터다. 그래서 SwiftUI에서 `Task { viewModel.state = ... }`가 그냥 동작한다.

`Task.detached`는 상속을 **전부** 끊는다. 편해 보이지만 액터 격리까지 끊기므로 UI 상태를 만지면 곧바로 에러가 된다. "무거운 작업을 백그라운드로" 정도의 이유라면 `Task.detached`보다 액터 설계로 푸는 편이 맞다.

## 비구조적 작업이라는 점

`Task { }`는 **비구조적(unstructured)** 이다. 부모와 수명이 연결되지 않는다.

- 만든 쪽이 끝나도 `Task`는 계속 산다
- 부모가 취소돼도 자동으로 취소되지 않는다
- 핸들을 버리면 취소할 방법이 없다

그래서 `Task { }`를 쓸 때는 **핸들을 보관할지 먼저 판단**해야 한다. 뷰 수명에 묶고 싶다면 `Task { }` 대신 SwiftUI의 `.task { }`가 답이다(8단계).

```swift
private var loadTask: Task<Void, Never>?

func start() {
    loadTask?.cancel()                    // 중복 실행 방지
    loadTask = Task { await load() }
}
deinit { loadTask?.cancel() }
```

## 취소는 협조적이다

Swift의 취소는 **강제 중단이 아니다.** `cancel()`은 플래그를 세울 뿐이고, 확인하고 빠져나오는 것은 코드의 책임이다.

확인하는 방법은 셋이다.

```swift
// ① 플래그 확인
if Task.isCancelled { return }

// ② 던지기
try Task.checkCancellation()          // 취소됐으면 CancellationError

// ③ 취소를 던지는 API 를 쓴다
try await Task.sleep(for: .seconds(1)) // 취소되면 CancellationError
```

**여기서 가장 흔한 버그가 나온다.**

```swift
while count < 60 {
    try? await Task.sleep(for: .seconds(1))   // ← try? 가 CancellationError 를 삼킨다
    count += 1
}
```

취소된 뒤에는 `Task.sleep`이 **잠들지 않고 즉시 에러를 던지며 반환**한다. `try?`가 그것을 `nil`로 지우고, 루프는 `isCancelled`를 보지 않으므로 전속력으로 회전한다. 1초에 한 번 돌아야 할 루프가 CPU를 태운다.

취소를 전파하려면 `try?`가 아니라 `try`를 쓰고 루프를 빠져나가야 한다.

```swift
while count < 60 {
    do { try await Task.sleep(for: .seconds(1)) }
    catch { return }                  // 취소되면 즉시 탈출
    count += 1
}
```

추상화를 둘 때도 마찬가지다. 프로토콜에서 `throws`를 떼면 취소 신호가 경계에서 사라진다.

### 정리 작업이 필요하면 — `withTaskCancellationHandler`

취소 순간에 해야 할 일이 있으면 핸들러를 붙인다.

```swift
await withTaskCancellationHandler {
    try? await Task.sleep(for: .seconds(5))
} onCancel: {
    print("onCancel 핸들러 실행됨")     // 소켓 닫기, 스트림 종료 등
}
```

```text
④ onCancel 핸들러 실행됨
```

`onCancel`은 **취소 시점에 즉시, 동기적으로** 불린다. 그 안에서 `await`를 쓸 수 없으므로 실제 작업이 아니라 신호 전달(플래그 세우기, `continuation.resume`, 소켓 `close`) 용도로 쓴다.

## `Task.sleep`과 `Task.yield()`

**`Task.sleep`** — 스레드를 붙잡지 않고 잠든다. `Thread.sleep`과 정반대다. 취소되면 던진다.

**`Task.yield()`** — 잠들지 않고 **실행 기회만 양보**한다. 긴 계산 루프가 다른 작업을 굶기지 않게 한다. 효과를 직접 확인했다.

```swift
// yield 없이
let t1 = Task { for i in 1...3 { print("A\(i)") } }
let t2 = Task { for i in 1...3 { print("B\(i)") } }

// yield 있음
let t3 = Task { for i in 1...3 { print("A\(i)"); await Task.yield() } }
let t4 = Task { for i in 1...3 { print("B\(i)"); await Task.yield() } }
```

```text
③ yield 없이        ③ yield 있음
   A1                  A1
   A2                  B1
   A3                  A2
   B1                  B2
   B2                  A3
   B3                  B3
```

`yield`가 없으면 A가 전부 끝난 뒤 B가 시작되고, 있으면 번갈아 실행된다. **중단점이 없는 긴 루프는 협력 스레드를 독점한다.** 이미지 처리나 큰 배열 순회처럼 `await`가 등장하지 않는 반복문에서는 주기적으로 `await Task.yield()`를 넣어 준다. 취소 확인 지점을 만드는 효과도 있다.

## 우선순위

`Task(priority: .background)`처럼 지정할 수 있다. 다만 우선순위는 **힌트**이고, 값의 의미와 상승(priority escalation) 규칙은 [104 문서](./104-task-priority-and-scheduling.md)에 정리되어 있다. 대부분의 경우 기본값이 맞다.

## 학습 체크리스트

- [ ] 동기 함수에서 `async` 함수를 부르려다 에러를 보고 `Task { }`로 감싸 본다.
- [ ] `@MainActor` 문맥에서 `Task { }`와 `Task.detached { }`의 `Thread.isMainThread`를 비교한다.
- [ ] `Task.currentPriority`를 찍어 상속 여부를 확인한다.
- [ ] `Task` 핸들을 보관하지 않고 만들어 취소할 방법이 없는 것을 확인한다.
- [ ] `try?`로 `Task.sleep`을 감싼 루프를 취소해 busy loop가 되는 것을 관찰한다.
- [ ] 같은 루프를 `do-catch`로 고쳐 즉시 탈출하는지 확인한다.
- [ ] `Task.isCancelled`와 `try Task.checkCancellation()`을 각각 써 본다.
- [ ] `withTaskCancellationHandler`의 `onCancel`이 언제 불리는지 확인한다.
- [ ] `await` 없는 긴 루프를 만들어 다른 Task가 굶는 것을 관찰한 뒤 `Task.yield()`를 넣어 비교한다.
- [ ] `Task.sleep`과 `Thread.sleep`을 각각 쓰고 다른 작업의 진행 여부를 비교한다.

## 공식 참고 자료

- [Apple: Task](https://developer.apple.com/documentation/swift/task)
- [Apple: Task.detached(priority:operation:)](https://developer.apple.com/documentation/swift/task/detached(name:priority:operation:)-795w1)
- [Apple: Task.yield()](https://developer.apple.com/documentation/swift/task/yield())
- [Apple: Task.sleep(for:tolerance:clock:)](https://developer.apple.com/documentation/swift/task/sleep(for:tolerance:clock:))
- [Apple: Task.checkCancellation()](https://developer.apple.com/documentation/swift/task/checkcancellation())
- [Apple: withTaskCancellationHandler(operation:onCancel:isolation:)](https://developer.apple.com/documentation/swift/withtaskcancellationhandler(operation:oncancel:isolation:))
- [Swift Book: Concurrency — Task Cancellation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Task-Cancellation)
- [Swift Book: Concurrency — Unstructured Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Unstructured-Concurrency)
