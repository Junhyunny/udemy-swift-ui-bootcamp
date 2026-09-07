# Swift의 async/await 실행 모델 — JavaScript·Python과 무엇이 다른가

## 질문이 나온 코드

`chapter-35/chapter-35/ContentView.swift`의 `.refreshable { await fetchData() }`와 `private func fetchData() async`

## 공부할 내용

### 1. "호출하면 일단 시작되고 나중에 await로 해소" — Swift는 그렇지 않다

여기가 JavaScript와 가장 크게 갈리는 지점이다.

JavaScript에서 `const p = fetch(url)`은 **호출 즉시 작업이 시작되고** Promise 객체가 손에 들어온다. `await p`는 이미 굴러가는 작업의 결과를 기다릴 뿐이다. 그래서 "호출"과 "대기"를 분리할 수 있다.

Swift는 다르다. `await f()`는 **그 자리에서 호출하고 그 자리에서 기다린다.** 반환되는 것은 Promise 같은 핸들이 아니라 최종 값이다.

> "When calling an asynchronous method, execution suspends until that method returns. You write `await` in front of the call to mark the possible suspension point."

그래서 아래 코드는 순차 실행이다. 세 다운로드가 동시에 돌지 않는다.

```swift
let a = await downloadPhoto(named: names[0])
let b = await downloadPhoto(named: names[1])   // a가 끝나야 시작
let c = await downloadPhoto(named: names[2])
```

> "This approach has an important drawback: Although the download is asynchronous and lets other work happen while it progresses, only one call to `downloadPhoto(named:)` runs at a time. Each photo downloads completely before the next one starts downloading."

JavaScript의 "먼저 다 던져 놓고 나중에 모아 받기"를 하려면 **`async let`** 을 쓴다.

```swift
async let a = downloadPhoto(named: names[0])
async let b = downloadPhoto(named: names[1])
async let c = downloadPhoto(named: names[2])
let photos = await [a, b, c]      // 여기서 한 번에 기다린다
```

> "In this example, all three calls to `downloadPhoto(named:)` start without waiting for the previous one to complete... None of these function calls are marked with `await` because the code doesn't suspend to wait for the function's result."

`async let`이 JS의 `const p = fetch(...)`에 해당하고, 마지막 `await`가 `await p`에 해당한다고 보면 대응이 맞는다. 더 동적으로 개수를 다루려면 `TaskGroup`, 완전히 독립적인 작업을 띄우려면 `Task { }`를 쓴다.

**핵심 차이**: JS는 async 함수를 호출하는 것만으로 동시성이 생기지만, **Swift는 `async let` / `Task` / `TaskGroup`으로 명시해야 동시성이 생긴다.** 그냥 `await`만 쓰면 그냥 순차 코드다.

### 2. "SwiftUI도 싱글 스레드인가" — 아니다

UI 갱신은 main actor에서 일어나지만 앱 전체가 싱글 스레드는 아니다. 네트워킹이나 파일 IO는 다른 실행 문맥에서 돌고, Swift concurrency는 **cooperative thread pool** 위에서 작업을 스케줄링한다.

JavaScript는 단일 스레드 + 이벤트 루프라서 "동시에 실행"은 없고 "번갈아 실행"만 있다. Swift는 진짜로 여러 스레드에서 **동시에** 실행될 수 있다. 그래서 JS에는 없는 데이터 레이스 문제가 존재하고, `actor`와 `Sendable` 같은 장치가 필요하다.

다만 suspend가 **선점형이 아니라는 점**은 알아 둘 만하다.

> "Inside an asynchronous method, the flow of execution can be suspended only when you call another asynchronous method — suspension is never implicit or preemptive — which means every possible suspension point is marked with `await`."

`await`가 없는 곳에서는 절대 중간에 끊기지 않는다. 코드에 적힌 `await`가 곧 "여기서 멈출 수 있음" 표시다.

### 3. "대기 중 스택은 어디에 보관되나" — 스레드 스택이 아니라 별도 저장소

추측하신 두 모델 중 **Python 쪽에 가깝다.** JS처럼 "콜스택에서 빠져나가 외부로 갔다가 큐를 통해 이벤트 루프로 복귀"하는 구조가 아니다.

`await`에서 멈추면 스레드를 붙잡고 있지 않고 놓아준다.

> "This is also called yielding the thread because, behind the scenes, Swift suspends the execution of your code on the current thread and runs some other code on that thread instead."

그럼 지역 변수와 실행 위치는 어디에 남는가. async 함수는 스레드 스택을 쓰지 않고 자기 저장소를 쓴다. async/await 도입 제안(SE-0296)이 이렇게 설명한다.

> "asynchronous functions are able to completely give up that stack and use their own, separate storage"
>
> "In practice, asynchronous functions are compiled to not depend on the thread during an asynchronous call, so that only the innermost function needs to do any extra work."

그리고 재개될 때 원래 스레드로 돌아온다는 보장도 없다.

> "When control returns to an asynchronous function, it picks up exactly where it was. That doesn't necessarily mean that it'll be running on the exact same thread it was before"

정리하면 **중단된 async 함수의 상태는 힙에 놓인 별도 프레임에 보관되고, 스레드는 풀로 반납되며, 재개 시 아무 스레드에서나 이어서 실행된다.** 그래서 스레드를 블로킹하지 않으면서도 수만 개의 작업을 띄울 수 있다. 세 가지 모델을 비교하면 이렇다.

| | JavaScript | Python asyncio | Swift |
| --- | --- | --- | --- |
| 호출 즉시 시작 | O (Promise) | X (coroutine 객체) | X (`async let`/`Task` 필요) |
| 실제 병렬 실행 | X (단일 스레드) | X (단일 이벤트 루프) | **O** (cooperative pool) |
| 중단 상태 저장 | 마이크로태스크 큐 | 힙의 frame 객체 | 힙의 별도 async frame |
| 재개 스레드 | 항상 동일 | 항상 동일 | 달라질 수 있음 |

### 4. 지금 코드에서 벌어지는 일

```swift
.refreshable { await fetchData() }
```

`refreshable`은 async 클로저를 받는다. 사용자가 당겨서 새로고침하면 SwiftUI가 이 작업을 시작하고, **작업이 끝날 때까지 스피너를 보여 준다.** 그래서 `await`로 끝까지 기다리는 것이 맞다. `fetchData()` 안에서 `URLSession`이 5초 응답을 기다리는 동안 스레드는 블로킹되지 않고, UI는 계속 반응한다.

`randomData.append(...)`가 `await` 뒤에서 `@State`를 건드리는데 문제가 없는 이유는, SwiftUI의 `View`가 main actor에 격리돼 있어 이 코드가 main actor에서 재개되기 때문이다.

## 학습 체크리스트

- [ ] `fetchData()`를 두 번 연속 `await` 호출하고 총 소요 시간이 합산되는지 측정한다.
- [ ] 같은 작업을 `async let` 두 개로 바꿔 시간이 절반 가까이 줄어드는지 비교한다.
- [ ] `await` 앞뒤에 `print(Thread.current)`를 찍어 재개 후 스레드가 달라질 수 있음을 관찰한다.
- [ ] `Task { }`로 작업을 띄우고 `await` 없이 다음 줄이 바로 실행되는지 확인한다.
- [ ] `Task`를 변수에 담아 `cancel()`을 호출해 취소가 전파되는지 본다.
- [ ] `refreshable` 클로저에서 `await`를 빼면 스피너가 언제 사라지는지 비교한다.
- [ ] `TaskGroup`으로 개수가 정해지지 않은 작업을 병렬 실행해 본다.
- [ ] `fetchData`를 `nonisolated`로 만들고 `randomData` 수정 시 어떤 오류가 나는지 확인한다.
- [ ] `Task.sleep`을 쓰는 버전과 `Thread.sleep`을 쓰는 버전을 비교해 UI 멈춤 차이를 체감한다.

## 참고 자료

- [The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift Evolution SE-0296: async/await](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md)
- [Swift Evolution SE-0304: Structured concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)
- [WWDC21: Swift concurrency — Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/)
- [Apple: Task](https://developer.apple.com/documentation/swift/task)
- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)
- [Apple: View.refreshable(action:)](https://developer.apple.com/documentation/swiftui/view/refreshable(action:))
- [Apple: URLSession.data(from:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/data(from:delegate:))
- [Swift.org: Data Race Safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/)
