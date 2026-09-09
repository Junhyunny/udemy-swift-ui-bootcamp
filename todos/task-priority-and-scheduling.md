# `TaskPriority` — 우선순위 값들과 실제 동작

`Task { }`와 `.task { }`의 구분은 [별도 문서](./task-modifier-and-async-lifecycle.md)에 정리했다. 이 문서는 **`priority` 파라미터**를 파고든다.

## 질문이 나온 코드

`chapter-65/chapter-65/ContentView.swift`

```swift
Task(priority: .background) {
    await receiveNotifications()
}
```

```swift
init() {
    Task(priority: .background) {
        await orientationChangeNotification()
    }
}
```

## 공부할 내용

### 무엇을 하는 값인가

`priority`는 **"이 작업이 얼마나 급한가"를 시스템에 알려 주는 힌트**다. 명령이 아니라 힌트라는 점이 중요하다.

> The executor determines how priority information affects the way tasks are scheduled. **The behavior varies depending on the executor currently being used.** Typically, executors attempt to run tasks with a higher priority before tasks with a lower priority. **However, the semantics of how priority is treated are left up to each platform and Executor implementation.**

**"보통 높은 우선순위를 먼저 실행하려 하지만, 구체적 의미는 플랫폼과 실행자에 달렸다"** 는 것이다. 정확한 실행 순서가 보장되지 않는다.

시스템이 우선순위를 참고해 결정하는 것들이다.

- 여러 작업이 대기 중일 때 **실행 순서**
- 스레드에 부여할 **QoS(Quality of Service)** — CPU 시간, IO 우선순위
- 배터리 절약 모드에서의 **지연 여부**

### 값 목록

`TaskPriority`가 제공하는 값은 아홉 개지만, 실질적으로는 **다섯 단계**다. 일부가 별칭이기 때문이다.

| 값 | 별칭 | 용도 |
| --- | --- | --- |
| `.userInteractive` | — | 애니메이션, 즉각 반응. **직접 지정하지 않는 것이 권장** |
| `.high` | `.userInitiated` | 사용자가 결과를 **기다리고 있는** 작업 |
| `.medium` | `.default` | 명시하지 않았을 때의 기본값 |
| `.low` | `.utility` | 진행 표시가 있는 긴 작업 |
| `.background` | — | **사용자가 모르는** 준비·정리 작업 |
| `.unspecified` | — | 우선순위 정보 없음 |

`.high`와 `.userInitiated`, `.low`와 `.utility`는 같은 값이다. GCD의 QoS 이름과 대응시키기 위해 두 이름을 모두 제공한다.

**각 값을 언제 쓰나**

| 값 | 예시 |
| --- | --- |
| `.userInitiated` / `.high` | 버튼을 눌러 시작한 로딩, 화면에 필요한 데이터 |
| `.medium` | 특별한 판단이 없을 때 |
| `.utility` / `.low` | 파일 다운로드, 대량 데이터 처리 (진행률 표시) |
| `.background` | 캐시 정리, 로그 전송, 미리 가져오기(prefetch) |

**`.userInteractive`는 직접 쓰지 않는 것이 좋다.** 메인 스레드의 렌더링 루프를 위한 등급이라, 여기에 작업을 밀어 넣으면 UI 반응성을 해칠 수 있다.

### `.background`가 뜻하는 것

질문의 `.background`가 가장 낮은 실질 우선순위다.

**시스템이 이렇게 취급한다.**

- 다른 작업이 없을 때 실행한다
- **저전력 모드에서는 미뤄질 수 있다**
- IO 우선순위도 낮아진다
- 스로틀링 대상이 된다

**적합한 작업**은 사용자가 결과를 기다리지 않고, 늦어져도 무방한 것이다. 로그 업로드, 캐시 정리, 다음 화면 데이터 미리 가져오기 등이다.

### 우선순위 상승 — 낮은 작업이 막지 않도록

Apple 문서가 두 가지 자동 조정을 설명한다.

> In some situations the priority of a task is elevated — that is, the task is treated as it if had a higher priority, without actually changing the priority of the task:
> - If a task runs on behalf of an actor, and a new higher-priority task is enqueued to the actor, then the actor's current task is temporarily elevated to the priority of the enqueued task.
> - If a higher-priority task accesses the `value` property, then the priority of this task increases until the task completes.

**우선순위 역전(priority inversion)을 막기 위한 장치**다. 낮은 우선순위 작업이 액터를 점유한 상태에서 높은 우선순위 작업이 대기하면, 낮은 쪽을 일시적으로 끌어올려 빨리 끝내게 한다.

두 번째는 `await task.value`로 결과를 기다릴 때 적용된다. 급한 작업이 결과를 기다리고 있다면 그 작업의 우선순위가 올라간다.

### 상속 규칙

> **Child tasks automatically inherit their parent task's priority.** Detached tasks created by `detach(priority:operation:)` don't inherit task priority because they aren't attached to the current task.

| 생성 방식 | 우선순위 |
| --- | --- |
| `async let`, `TaskGroup` (자식 작업) | **부모에게서 상속** |
| `Task { }` | 현재 문맥에서 상속 |
| `Task(priority: .x) { }` | **명시한 값** |
| `Task.detached { }` | **상속하지 않음** |

`Task { }`가 현재 문맥의 우선순위를 물려받는다는 점이 중요하다. 대부분의 경우 **명시하지 않는 것이 맞다.**

### 이 코드에서 `.background`가 적절한가

**의도는 이해되지만 실효가 거의 없다.**

```swift
Task(priority: .background) {
    await receiveNotifications()
}
```

`receiveNotifications()`가 하는 일을 보면 이유가 나온다.

```swift
for await notification in center.notifications(named: name) {
    // ...
    await MainActor.run {
        counter += 1
    }
}
```

- **대기가 대부분이다.** 알림을 기다리는 동안 CPU를 전혀 쓰지 않는다. 우선순위를 낮춰 절약할 것이 없다
- **실제 작업은 메인 액터에서 한다.** `MainActor.run`으로 넘기므로 백그라운드에서 처리되는 부분이 없다
- **우선순위가 낮으면 응답이 늦어질 수 있다.** 버튼을 눌렀는데 화면 갱신이 지연되면 사용자 경험이 나빠진다

**두 번째 사용처는 더 애매하다.**

```swift
init() {
    Task(priority: .background) {
        await orientationChangeNotification()      // @MainActor 함수
    }
}
```

호출하는 함수가 `@MainActor`라 **어차피 메인 액터에서 실행된다.** `.background`를 지정해도 실행 위치가 바뀌지 않는다. 화면 회전은 즉시 반영되어야 하는 이벤트이므로 낮은 우선순위가 오히려 부적절하다.

**권장하는 형태**는 이렇다.

```swift
// ① 우선순위를 지정하지 않는다 — 문맥에서 상속
.task {
    await receiveNotifications()
}
```

[`.task` 문서](./task-modifier-and-async-lifecycle.md)에서 다룬 대로 `.task`의 기본값은 `.userInitiated`이고, 뷰 생명주기에 묶여 자동 취소된다는 이점도 함께 얻는다.

### `.background`가 실제로 유용한 경우

CPU나 IO를 실제로 쓰는 작업이어야 의미가 있다.

```swift
// 캐시 정리 — 늦어도 무방
Task(priority: .background) {
    await cleanupOldCache()
}

// 로그 업로드 — 사용자가 모른다
Task(priority: .background) {
    await uploadAnalytics()
}

// 다음 화면 미리 가져오기
Task(priority: .background) {
    await prefetchNextPage()
}
```

공통점은 **사용자가 결과를 기다리지 않는다**는 것이다.

### 현재 우선순위 확인하기

```swift
Task {
    print(Task.currentPriority)      // 현재 작업의 우선순위
}
```

디버깅할 때 유용하다. 상속이 예상대로 되는지 확인할 수 있다.

### 우선순위보다 중요한 것

**대부분의 성능 문제는 우선순위로 해결되지 않는다.** 실제로 중요한 것은 이런 것들이다.

- **메인 스레드를 막지 않는가** — [MainActor 문서](./main-actor-and-ios-threading.md) 참조
- **불필요한 작업을 하고 있지 않은가**
- **취소가 제대로 되는가** — 화면을 나갔는데 계속 도는 작업이 없는지
- **중복 실행이 없는가**

우선순위는 **여러 작업이 CPU를 두고 경쟁할 때** 의미를 갖는다. 그런 상황이 아니라면 지정하지 않는 것이 낫다.

### 정리

```text
priority = 스케줄링 힌트 (명령이 아니다)
  실제 동작은 플랫폼과 executor에 달렸다

실질 5단계
  userInteractive  직접 쓰지 않는다
  high/userInitiated  사용자가 기다리는 작업
  medium/default      기본값
  low/utility         진행 표시가 있는 긴 작업
  background          사용자가 모르는 작업, 저전력 모드에서 지연 가능

상속
  자식 작업 → 부모에게서 상속
  Task { } → 현재 문맥에서 상속
  Task.detached → 상속 안 함

이 코드에서는
  대기가 대부분이고 실제 작업은 MainActor에서 하므로
  .background의 실효가 거의 없다
  .task { }로 바꾸는 편이 낫다 (자동 취소도 얻는다)
```

## 학습 체크리스트

- [ ] `Task.currentPriority`를 출력해 실제 우선순위를 확인한다.
- [ ] `.background`를 지우고 기본 우선순위가 무엇인지 확인한다.
- [ ] `.high`, `.background`로 각각 바꿔 알림 반응 속도에 차이가 있는지 관찰한다.
- [ ] `Task { }` 안에서 또 `Task { }`를 만들어 우선순위가 상속되는지 확인한다.
- [ ] `Task.detached { }`로 바꿔 상속되지 않는 것을 확인한다.
- [ ] `.userInitiated`와 `.high`가 같은 값인지 `==`로 비교한다.
- [ ] `.utility`와 `.low`도 같은지 확인한다.
- [ ] `Task(priority:)`를 `.task`로 바꾸고 기본값이 `.userInitiated`인 것을 확인한다.
- [ ] 무거운 계산을 `.background`와 `.userInitiated`로 각각 실행해 UI 반응 차이를 본다.
- [ ] 저전력 모드를 켜고 `.background` 작업이 지연되는지 관찰한다.
- [ ] `orientationChangeNotification()`이 `@MainActor`라 우선순위가 무의미한 이유를 설명한다.
- [ ] `await task.value`로 결과를 기다릴 때 우선순위 상승이 일어나는지 확인해 본다.

## 공식 참고 자료

- [Apple: TaskPriority](https://developer.apple.com/documentation/swift/taskpriority)
- [Apple: TaskPriority.background](https://developer.apple.com/documentation/swift/taskpriority/background)
- [Apple: TaskPriority.userInitiated](https://developer.apple.com/documentation/swift/taskpriority/userinitiated)
- [Apple: TaskPriority.utility](https://developer.apple.com/documentation/swift/taskpriority/utility)
- [Apple: TaskPriority.medium](https://developer.apple.com/documentation/swift/taskpriority/medium)
- [Apple: Task](https://developer.apple.com/documentation/swift/task)
- [Apple: Task.currentPriority](https://developer.apple.com/documentation/swift/task/currentpriority)
- [Apple: Task.detached(priority:operation:)](https://developer.apple.com/documentation/swift/task/detached(priority:operation:))
- [Apple: view.task(priority:_:)](https://developer.apple.com/documentation/swiftui/view/task(priority:_:))
- [Swift 공식 문서: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple: Dispatch — Quality of Service](https://developer.apple.com/documentation/dispatch/dispatchqos)
