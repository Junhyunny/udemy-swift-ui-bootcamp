# Swift 동시성 런타임 — 실측과 JavaScript 비교

**Task → Job → Executor → 협력 스레드 풀** 네 층 구조, `await` 한 줄에서 벌어지는 일, 스택 프레임과 비동기 프레임의 구분은 블로그 글 「스위프트 비동기 처리 아키텍처」로 정리를 마쳤다. 이 문서에는 그 글에 담지 않은 **실측값, JavaScript와의 대조, 실행 위치를 바꾸는 손잡이**만 남긴다.

- 의미론(`await`가 무슨 뜻인가)은 [101](./101-swift-async-await-model.md), [143](./143-sync-vs-async-and-suspension.md)
- 컴파일 결과(SIL·IR에서 무엇으로 바뀌는가)는 [152](./152-async-function-compilation-model.md)

이 문서의 수치는 **14코어 머신에서 Swift 6.3.3으로 직접 측정**한 값이다.

## 1부 — JavaScript와 나란히 놓기

```text
[JavaScript]                          [Swift]

  콜스택                                 Task 트리
    │                                     │
    ▼                                     ▼
  이벤트 루프 ◀── 매크로태스크 큐          여러 개의 실행자
    │         ◀── 마이크로태스크 큐          ├─ MainActor 직렬 실행자
    ▼                                      ├─ 각 actor 의 직렬 실행자
  스레드 1개                                └─ 전역 동시 실행자
                                            │
                                            ▼
                                        스레드 N개 (≤ 코어 수)
```

| | JavaScript | Swift |
| --- | --- | --- |
| 스레드 | **1개** | **여러 개** (코어 수 이하) |
| 조율 주체 | 이벤트 루프 **하나** | 실행자 **여러 개** |
| 큐 | 매크로/마이크로태스크 큐 | 실행자마다 잡 큐 |
| 동시 실행 | 없음 (번갈아 실행) | **있음** (진짜 병렬) |
| data race | 구조적으로 없음 | **있다** → `actor`·`Sendable` 필요 |
| 중단 지점 | `await` | `await` (동일) |
| 선점 | 없음 | 없음 (`await`에서만 중단) |
| 동시성 시작 | 함수 호출만으로 생김 | **명시해야 생김** (`async let`·`Task`·`TaskGroup`) |

**"이벤트 루프 하나"가 "실행자 여러 개"로 바뀐 것**이 가장 큰 구조적 차이다. 그래서 JS에는 없는 두 가지가 생긴다 — 진짜 병렬 실행, 그리고 그에 따른 데이터 경쟁.

마지막 줄도 중요하다. JS는 `fetch()`를 부르는 순간 작업이 굴러가지만, Swift의 `await f()`는 그 자리에서 호출하고 그 자리에서 기다린다. [101 문서](./101-swift-async-await-model.md)에 자세하다.

## 2부 — 실측: 스레드는 몇 개나 쓰이나

14코어 머신에서 CPU 작업 100개를 돌린 결과다.

```text
논리 코어 수: 14
① Swift 작업 100개 → 사용된 스레드 수: 14
① Swift 작업 100개 → 사용된 스레드 수: 10   (다른 실행)
```

**작업이 100개여도 스레드는 코어 수를 넘지 않는다.** 남는 작업은 큐에서 기다린다.

이제 블로킹이 섞인 GCD와 비교한다. 3회 반복했다.

```text
  1회차 GCD 블로킹 100개 → 스레드 70개
  2회차 GCD 블로킹 100개 → 스레드 70개
  3회차 GCD 블로킹 100개 → 스레드 70개
```

**GCD는 스레드 70개를 만들었다.** 작업이 스레드를 붙잡고 자기 때문에, 큐가 밀리지 않도록 런타임이 스레드를 계속 새로 띄운다. 이것이 **스레드 폭발(thread explosion)** 이다. 스레드마다 스택 메모리를 잡고 컨텍스트 스위치 비용이 들기 때문에, 많아질수록 느려진다.

Swift 동시성은 스레드를 늘리지 않는 대신 **작업을 중단시키고 스레드를 반납**하게 만들어 같은 문제를 푼다.

> The pool does not grow to cover blocked threads.

## 3부 — "블로킹 금지" 계약, 어기면 무슨 일이 생기나

협력 스레드 풀은 **모든 작업이 전진한다(forward progress)** 는 전제 위에서 동작한다. 스레드를 붙잡고 자는 작업이 있으면 그 전제가 깨진다. 직접 측정했다.

코어 수만큼 블로킹 작업을 띄우고, 즉시 끝나는 짧은 작업 하나를 함께 넣었다.

```text
② 블로킹 실험 — Thread.sleep(1.0) 을 코어 수만큼
   짧은 작업 시작 시점: 1.00s     ← 1초를 꼬박 기다렸다
   총 소요: 1.01s

③ 같은 실험을 Task.sleep 으로
   짧은 작업 시점: 0.00s          ← 즉시 실행됐다
```

**`Thread.sleep`을 쓰면 1초를 기다리고, `Task.sleep`을 쓰면 0초에 실행된다.** 코드는 거의 같은데 결과가 정반대다.

블로킹은 스레드를 점유한 채 놓지 않으므로 풀이 고갈되고, 다른 작업은 **실행될 기회 자체를 잃는다.** GCD였다면 스레드를 더 만들어 넘어갔겠지만, 협력 풀은 늘어나지 않는다.

> Violations don't make the program slow, they make it stop.

**느려지는 게 아니라 멈춘다.** 이것이 "async 함수 안에서 블로킹 API를 쓰지 말라"는 규칙이 단순 권고가 아닌 이유다.

블로킹에 해당하는 것들이다.

| 쓰면 안 되는 것 | 대신 |
| --- | --- |
| `Thread.sleep` | `Task.sleep` |
| `DispatchSemaphore.wait()` | `await` |
| `DispatchGroup.wait()` | `TaskGroup` |
| 동기 파일·소켓 읽기 | async API |
| 무한 계산 루프 | 중간에 `await Task.yield()` |

## 4부 — 메인 액터와 런루프

`@MainActor`의 직렬 실행자는 **메인 스레드(런루프)** 에 연결된다. 측정 결과다.

```text
③ MainActor 실행 스레드가 메인인가: true
```

```text
메인 스레드
 ┌──────────────────────────────────────────┐
 │  런루프: 터치 이벤트 → 레이아웃 → 렌더링       │
 │         ▲                                 │
 │         └── MainActor 잡 큐가 여기에 얹힌다   │
 └──────────────────────────────────────────┘
```

여기서 UI 성능 규칙이 따라 나온다. **메인 액터에서 오래 걸리는 잡을 실행하면 그동안 렌더링이 멈춘다.** 60fps면 프레임당 16ms인데, 메인 액터 잡 하나가 50ms를 쓰면 프레임을 놓친다.

그래서 무거운 계산은 메인 액터 밖으로 보내고 결과만 돌려받는다. `@concurrent`가 그 표시이며, 측정 결과는 [Swift 액터 완전 정복](./153-swift-actor-complete-guide.md)의 3.8절에 있다.

## 5부 — 실행 위치를 바꾸는 손잡이

| 손잡이 | 무엇을 바꾸나 | 제안서 |
| --- | --- | --- |
| 커스텀 actor 실행자 | **특정 actor**의 잡이 어디서 도는가 | SE-0392 |
| 태스크 실행자 선호 | **태스크 트리 전체**의 비격리 코드가 어디서 도는가 | SE-0417 |
| `@concurrent` | 비격리 async 함수가 호출자를 떠나게 | SE-0461 |
| `nonisolated(nonsending)` | 호출자를 따라가게 (6.2 기본) | SE-0461 |

둘의 역할이 다르다.

> SerialExecutor guarantees mutual exclusion, and the TaskExecutor provides a source of threads.

**직렬 실행자는 "상호 배제", 태스크 실행자는 "스레드 공급"** 이다.

다만 제안서 자체가 경고한다.

> Applying task executors to solve a performance problem should be done after thoroughly understanding the problem.

일반적인 앱에서는 이 손잡이를 건드릴 일이 거의 없다. 기본 설정이 대부분 맞다.

## 6부 — JS 경험이 만드는 오해

| 오해 | 실제 |
| --- | --- |
| "이벤트 루프가 하나 있다" | 실행자가 여러 개다. UI만 단일 실행자 |
| "싱글 스레드라 race가 없다" | 진짜 병렬이라 race가 있다 → `actor`·`Sendable` |
| "함수를 부르면 동시에 돈다" | `await`만 쓰면 순차. `async let`·`TaskGroup`이 필요 |
| "`await`는 그냥 기다림" | 스레드를 반납하고 중단한다 |
| "`await` 뒤도 같은 스레드" | 달라질 수 있다 |
| "블로킹해도 좀 느릴 뿐" | 풀이 고갈되면 **멈춘다** (3부 실측) |
| "`Task`는 Promise 같은 것" | `async let`이 Promise에 가깝다 |

## 학습 체크리스트

- [ ] `ProcessInfo.processInfo.activeProcessorCount`로 코어 수를 확인한다.
- [ ] `TaskGroup`으로 CPU 작업 100개를 돌리고 사용된 고유 스레드 수를 센다.
- [ ] 같은 작업을 `DispatchQueue.global()` + `Thread.sleep`으로 돌려 스레드 수를 비교한다.
- [ ] 코어 수만큼 `Thread.sleep` 작업을 띄우고 짧은 작업이 언제 실행되는지 측정한다.
- [ ] 같은 실험을 `Task.sleep`으로 바꿔 즉시 실행되는지 확인한다.
- [ ] `await` 앞뒤에서 스레드 ID를 찍어 달라질 수 있는지 관찰한다.
- [ ] `@MainActor` 함수에서 `Thread.isMainThread`를 확인한다.
- [ ] 메인 액터에서 50ms 걸리는 계산을 반복 실행해 UI가 끊기는지 본다.
- [ ] 같은 계산을 `@concurrent` 함수로 빼고 비교한다.
- [ ] `DispatchSemaphore.wait()`를 async 함수 안에서 호출해 무슨 일이 생기는지 확인한다.
- [ ] JS의 `Promise.all`과 Swift의 `async let`을 같은 시나리오로 작성해 비교한다.

## 공식 참고 자료

- [WWDC21: Swift concurrency — Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/)
- [WWDC22: Visualize and optimize Swift concurrency](https://developer.apple.com/videos/play/wwdc2022/110350/)
- [Apple: Executor](https://developer.apple.com/documentation/swift/executor)
- [Apple: SerialExecutor](https://developer.apple.com/documentation/swift/serialexecutor)
- [Apple: TaskExecutor](https://developer.apple.com/documentation/swift/taskexecutor)
- [Apple: ExecutorJob](https://developer.apple.com/documentation/swift/executorjob)
- [swiftlang/swift: stdlib/public/Concurrency/Executor.swift](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Executor.swift)
- [SE-0392: Custom Actor Executors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md)
- [SE-0417: Task Executor Preference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0417-task-executor-preference.md)
- [Swift Forums: How is the Cooperative Thread Pool integrated in Swift?](https://forums.swift.org/t/how-is-the-cooperative-thread-pool-integrated-in-swift/67466)
