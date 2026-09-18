# 2단계 — `async` / `await` / `try await`

[로드맵](./142-swift-concurrency-roadmap.md)의 2단계다. 1단계에서 잡은 실행 모델을 문법으로 옮긴다.

관련 기존 문서: [`async throws`와 커스텀 에러](./102-async-throws-and-custom-errors.md), [`for await`와 AsyncSequence](./105-for-await-async-sequence.md), [오류 처리 방식들](./100-swift-error-handling-forms.md)

## 선언과 호출

```swift
func loadUser() async throws -> User {
    try await api.fetchUser()
}
```

키워드 자리가 정해져 있다.

| 위치 | 순서 | 뜻 |
| --- | --- | --- |
| 선언 | `async throws` | 중단될 수 있고, 던질 수 있다 |
| 호출 | `try await` | 던질 수 있고, 중단될 수 있다 |

**선언과 호출의 순서가 반대**라 헷갈린다. 외우는 대신 이렇게 읽으면 된다 — 선언부는 "이 함수는 async이고 throws한다", 호출부는 "try해서 await한다". 자세한 조합은 [102 문서](./102-async-throws-and-custom-errors.md)에 네 가지 경우로 정리되어 있다.

`async` 함수는 **`async` 문맥에서만 호출할 수 있다.** 동기 함수에서 부르려면 `Task { }`로 문맥을 만들어야 한다(3단계).

## `await`는 중단점 표시다

`await`가 붙은 자리는 **중단될 수 있는 지점**이다. 이 사실에서 두 가지가 따라 나온다.

**① `await` 전후로 상태가 바뀔 수 있다.** 중단된 사이에 다른 코드가 실행되기 때문이다. 5단계의 액터 재진입 문제가 정확히 이 얘기다.

```swift
guard balance >= amount else { return }
try await someDelay()          // ← 이 사이에 balance 가 바뀔 수 있다
balance -= amount              // 검사 결과가 이미 낡았을 수 있다
```

**② `await`를 나열하면 순차 실행된다.** 직접 측정했다.

```swift
let a = await work("A", ms: 300)
let b = await work("B", ms: 300)
```

```text
① 순차 await : AB — 0.64s
```

각각 0.3초인 작업 둘을 `await`로 나열하면 0.64초가 걸린다. **동시에 실행되지 않는다.** 서로 의존하지 않는 작업을 동시에 하려면 4단계의 `async let`이나 `TaskGroup`이 필요하다.

이것이 초보자가 가장 많이 놓치는 부분이다. `async`를 붙였다고 저절로 병렬이 되지 않는다.

## 값을 반환하고 에러를 던진다

콜백과 달리 **평범한 반환값과 평범한 `throw`** 를 쓴다.

```swift
func fetchUser() async throws -> User {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw APIError.badStatus
    }
    return try JSONDecoder().decode(User.self, from: data)
}
```

`do-catch`, `try?`, `try!`가 동기 코드와 똑같이 동작한다. 에러 타입을 `enum`으로 설계하는 방법은 [102 문서](./102-async-throws-and-custom-errors.md)에 정리되어 있다.

`try?`가 옵셔널을 평탄화하는 동작은 [옵셔널 총정리](./141-optional-complete-guide.md)의 3부를 참조한다.

## 여러 값을 받으려면 — `AsyncSequence`

값이 하나면 `async` 함수, 여러 번 오면 `AsyncSequence`다.

```swift
for await notification in center.notifications(named: name) {
    // 알림이 올 때마다 한 번씩
}
```

`for await`는 **반복할 때마다 중단될 수 있는 반복문**이다. 자세한 것은 [105 문서](./105-for-await-async-sequence.md)에 있다.

## 흔한 함정

**`async` 함수 안에서 블로킹 API를 쓰는 것.** `Thread.sleep`, 동기 파일 읽기, 세마포어 대기 등은 스레드를 붙잡아 버려서 Concurrency의 전제를 깬다. 협력 스레드 풀이 고갈되면 앱 전체가 멈출 수 있다.

**`await`를 붙였으니 안전하다고 생각하는 것.** `await`는 중단점 표시일 뿐 상호 배제를 제공하지 않는다. 공유 상태 보호는 5단계 `actor`의 역할이다.

## 학습 체크리스트

- [ ] `async` 함수를 동기 함수에서 호출해 컴파일 에러를 확인한다.
- [ ] 선언은 `async throws`, 호출은 `try await` 순서인 것을 직접 써서 확인한다.
- [ ] 0.3초짜리 작업 둘을 `await`로 나열하고 총 시간이 합산되는 것을 측정한다.
- [ ] 같은 코드를 4단계 학습 후 `async let`으로 바꿔 시간을 비교한다.
- [ ] `await` 앞뒤에서 공유 변수를 찍어 값이 바뀔 수 있는지 관찰한다.
- [ ] `async` 함수에서 에러를 던지고 `do-catch`로 잡아 본다.
- [ ] `async` 함수 안에서 `Thread.sleep`을 호출해 무엇이 달라지는지 본다.
- [ ] `URLSession.shared.data(from:)`으로 실제 네트워크 호출을 `async`로 작성한다.

## 공식 참고 자료

- [Swift Book: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple: URLSession.data(from:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/data(from:delegate:))
- [Apple: AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence)
- [SE-0296: Async/await](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md)
- [SE-0298: Async/Await: Sequences](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0298-asyncsequence.md)
- [WWDC21: Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
