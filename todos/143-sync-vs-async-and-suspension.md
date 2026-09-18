# 1단계 — 동기 vs 비동기, 그리고 "중단(suspension)"이란 무엇인가

[Swift Concurrency 로드맵](./142-swift-concurrency-roadmap.md)의 1단계다. 문법을 배우기 전에 **실행 모델**을 먼저 잡는다. 이것을 건너뛰면 이후 모든 단계가 암기가 된다.

관련 기존 문서: [Swift의 async/await 실행 모델](./101-swift-async-await-model.md)

## 이 단계에서 답할 질문

- `await`는 "기다린다"는 뜻인가?
- 기다리는 동안 스레드는 무엇을 하는가?
- 콜백 방식과 무엇이 다른가?
- 옛날 콜백 API를 어떻게 `async`로 바꾸는가?

## 블로킹과 중단은 다르다

가장 중요한 구분이다.

```text
[블로킹 — 예전 방식]
  스레드 ──── 작업 시작 ──── 응답 올 때까지 멈춤 ──── 계속
              └─ 이 스레드는 아무것도 못 한다. 점유된 채 낭비된다.

[중단(suspension) — Swift Concurrency]
  Task ──── await ──┐
                    │  스레드는 풀려나 다른 Task 를 실행한다
                    │
       resume ◀─────┘
```

`await`는 **"이 자리에서 멈출 수 있다"** 는 표시다. 스레드를 붙잡고 기다리는 것이 아니라, **작업을 중단시키고 스레드를 반납**했다가 나중에 이어서 실행한다.

이 차이가 실용적으로 중요한 이유는 스레드가 비싼 자원이기 때문이다. 블로킹 방식으로 동시 요청 100개를 처리하려면 스레드 100개가 필요하지만, 중단 방식은 몇 개로 충분하다.

`await`는 `Thread.sleep`과 정반대다. `Thread.sleep`은 스레드를 붙잡은 채 재우고, `Task.sleep`은 스레드를 놓아준다.

### 대기 중 상태는 어디에 보관되나

중단됐다가 이어서 실행하려면 "어디까지 했는지"를 기억해야 한다. 블로킹 방식은 스레드 스택이 그 역할을 하지만, 스레드를 반납하면 스택도 쓸 수 없다.

Swift는 async 함수의 지역 변수와 재개 지점을 **스레드 스택이 아니라 힙의 별도 저장소**에 보관한다. 그래서 스레드를 반납하고도 나중에 정확히 그 자리에서 이어갈 수 있다. [101 문서](./101-swift-async-await-model.md)에 더 자세하다.

## 콜백 방식과 비교

같은 일을 세 가지로 써 보면 차이가 분명하다.

```swift
// ① 콜백 — 중첩이 깊어지고 에러 경로가 흩어진다
func load(completion: @escaping (Result<User, Error>) -> Void) {
    fetchToken { token in
        switch token {
        case .success(let t):
            fetchUser(token: t) { user in
                completion(user)          // 여기까지 오면 3단 중첩
            }
        case .failure(let e):
            completion(.failure(e))       // 에러 처리가 각 단계마다 반복
        }
    }
}

// ② async/await — 위에서 아래로 읽힌다
func load() async throws -> User {
    let token = try await fetchToken()
    return try await fetchUser(token: token)
}
```

콜백 방식의 진짜 문제는 중첩이 아니라 **컴파일러가 도와줄 수 없다는 점**이다.

- `completion`을 호출하지 않고 함수가 끝나도 컴파일러는 모른다
- 두 번 호출해도 모른다
- 에러 경로를 빠뜨려도 모른다
- 어느 스레드에서 불릴지 계약에 없다

`async/await`는 이 네 가지를 전부 타입 시스템으로 옮긴다. 반환값을 돌려주지 않으면 컴파일 에러이고, 두 번 반환할 수 없으며, `throws`가 에러 경로를 강제하고, 액터 격리가 실행 위치를 정한다.

## 콜백 API를 `async`로 잇는 다리 — `withCheckedContinuation`

기존 콜백 API를 전부 다시 쓸 수는 없다. **continuation이 그 다리다.**

```swift
// 옛 스타일 콜백 API (내가 고칠 수 없는 코드라고 하자)
func legacyFetch(completion: @escaping (Result<String, Error>) -> Void) { ... }

// async 래퍼
func fetch() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        legacyFetch { continuation.resume(with: $0) }
    }
}

print(try await fetch())
```

```text
ⓒ 콜백 → async 변환 결과: 데이터
```

`continuation.resume`이 호출되는 순간 중단됐던 지점이 재개된다. **정확히 한 번만 호출해야 한다.** 0번이면 그 작업은 영원히 깨어나지 않고, 2번이면 크래시한다. `checked` 버전은 이 위반을 런타임에 잡아 주므로 개발 중에는 항상 `checked`를 쓴다.

delegate 콜백, `CLLocationManager`, `CallKit`, WebSocket 이벤트처럼 **콜백으로 설계된 프레임워크를 async 세계로 들여올 때 쓰는 표준 도구**다.

여러 번 값이 오는 API(스트림)는 continuation이 아니라 `AsyncStream`이 맞다. [`for await`와 AsyncSequence](./105-for-await-async-sequence.md) 참조.

## 흔한 오해

**"`await`를 쓰면 느려진다"** — 반대다. 중단은 스레드를 놓아주는 동작이라 전체 처리량이 올라간다. 단, 순차로 `await`를 나열하면 그만큼 순차 실행된다. 동시에 하려면 4단계(구조적 동시성)가 필요하다.

**"async 함수는 백그라운드에서 돈다"** — 아니다. 어디서 도는지는 **액터 격리**가 정하며, 최신 Swift에서는 비격리 async 함수가 기본적으로 **호출자를 따라간다**. 6단계와 [139 문서](./139-actor-isolation-domains.md)에서 다룬다.

**"`await`마다 스레드가 바뀐다"** — 바뀔 수 있다는 것이지 반드시 바뀌는 것은 아니다. `await` 전후로 스레드가 같다고 가정한 코드를 쓰면 안 된다.

## 학습 체크리스트

- [ ] `Thread.sleep`과 `Task.sleep`을 각각 쓰고 다른 작업이 진행되는지 비교한다.
- [ ] 콜백 3단 중첩 코드를 `async/await`로 바꿔 줄 수를 비교한다.
- [ ] 콜백 함수에서 `completion`을 호출하지 않고 끝내 보고, 컴파일러가 잡지 못하는 것을 확인한다.
- [ ] 같은 실수를 `async` 함수에서 저질러 보고 컴파일 에러가 나는 것을 확인한다.
- [ ] `withCheckedThrowingContinuation`으로 콜백 API를 감싸 본다.
- [ ] `continuation.resume`을 두 번 호출해 런타임 경고를 확인한다.
- [ ] `resume`을 아예 호출하지 않고 작업이 영원히 멈추는 것을 확인한다.
- [ ] `await` 앞뒤에서 `Thread.isMainThread`를 찍어 값이 달라질 수 있는지 본다.

## 공식 참고 자료

- [Swift Book: Concurrency — Defining and Calling Asynchronous Functions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Defining-and-Calling-Asynchronous-Functions)
- [Apple: withCheckedThrowingContinuation(function:_:)](https://developer.apple.com/documentation/swift/withcheckedthrowingcontinuation(isolation:function:_:))
- [Apple: withCheckedContinuation(function:_:)](https://developer.apple.com/documentation/swift/withcheckedcontinuation(function:_:))
- [Apple: CheckedContinuation](https://developer.apple.com/documentation/swift/checkedcontinuation)
- [Apple: AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [WWDC21: Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [SE-0296: Async/await](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md)
- [SE-0300: Continuations for interfacing async tasks with synchronous code](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0300-continuation.md)
