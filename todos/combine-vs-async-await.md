
# `dataTaskPublisher` vs `URLSession.data` — Combine과 async/await 중 무엇을 쓰나

`async/await` 실행 모델은 [별도 문서](./swift-async-await-model.md)에, Combine 연산자는 [여기](./combine-operators.md)에 정리했다. 이 문서는 **두 방식의 선택**을 다룬다.

## 질문이 나온 코드

`chapter-80/chapter-80/Services/ExchangeRateService.swift` — Combine 방식

```swift
func urlSession<T: Codable>(_ type: T.Type, with url: URL) -> AnyPublisher<T, Error> {
    URLSession.shared
        .dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: type.self, decoder: JSONDecoder())
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
}
```

`chapter-61`에서 쓴 async/await 방식

```swift
func request<T: Decodable>(...) async throws -> T {
    let (data, response) = try await URLSession.shared.data(for: request)
    // 상태 코드 검사
    return try JSONDecoder().decode(T.self, from: data)
}
```

## 공부할 내용

### 무엇이 다른가 — 근본적인 차이

**값을 몇 번 돌려주는가**가 핵심이다.

| | async/await | Combine |
| --- | --- | --- |
| 값의 개수 | **한 번** | **0개 ~ 무한** |
| 모델 | 함수 호출 | 스트림 |
| 완료 | `return` 또는 `throw` | `.finished` 또는 `.failure` |
| 취소 | `Task.cancel()` | `AnyCancellable` 해제 |
| 스레드 전환 | `@MainActor` | `receive(on:)` |
| 오류 처리 | `do-catch` | `catch`, `replaceError` 연산자 |

**네트워크 요청 하나는 값을 한 번만 돌려준다.** 그래서 이 예제의 용도에는 async/await가 더 자연스럽다.

Combine이 빛나는 것은 **값이 여러 번 오거나, 여러 스트림을 합쳐야 할 때**다.

```swift
// 검색어 입력을 디바운스하고 요청 — Combine이 압도적으로 편하다
$searchText
    .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
    .removeDuplicates()
    .flatMap { query in service.search(query) }
    .sink { results = $0 }
    .store(in: &cancellables)
```

같은 것을 async/await로 하려면 디바운스와 이전 작업 취소를 직접 구현해야 한다.

### 같은 코드를 두 방식으로

이 예제를 async/await로 옮기면 이렇게 된다.

```swift
// Combine — 현재
func urlSession<T: Codable>(_ type: T.Type, with url: URL) -> AnyPublisher<T, Error> {
    URLSession.shared
        .dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: type.self, decoder: JSONDecoder())
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
}
```

```swift
// async/await
func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(T.self, from: data)
}
```

호출부의 차이가 더 크다.

```swift
// Combine
func fetchRates() {
    service.getExchangeRate()
        .replaceError(with: ExchangeRate.placeholder)
        .sink { [weak self] in self?.exchangeRate = $0 }
        .store(in: &cancellableSet)
}
```

```swift
// async/await
@MainActor
func fetchRates() async {
    do {
        exchangeRate = try await service.getExchangeRate()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**async/await 쪽에서 사라지는 것들**

- `AnyCancellable`, `cancellableSet`, `store(in:)`
- `[weak self]` — 클로저를 저장하지 않으므로 순환 참조 걱정이 없다
- `deinit`의 정리 코드
- `receive(on:)` — `@MainActor`가 대신한다
- `eraseToAnyPublisher()` — 반환 타입이 그냥 `T`다

[구독 수명 관리 문서](./combine-cancellable-and-store.md)에서 다룬 개념 대부분이 필요 없어진다.

### 각각의 장단점

**async/await**

| | |
| --- | --- |
| 장점 | 코드가 위에서 아래로 읽힌다 |
| | 오류 처리가 언어 문법(`try`/`catch`)이다 |
| | 취소가 구조적으로 관리된다 ([`.task`](./task-modifier-and-async-lifecycle.md)) |
| | `weak self`가 대체로 불필요 |
| | 학습 부담이 적다 |
| | 컴파일러가 데이터 경쟁을 검사한다 |
| 단점 | 값을 여러 번 받는 흐름에 부적합 (`AsyncSequence`로 일부 보완) |
| | 디바운스·스로틀 같은 연산자가 없다 |
| | 여러 스트림 합성이 번거롭다 |
| | iOS 13(async/await는 13, 일부 API는 15+) |

**Combine**

| | |
| --- | --- |
| 장점 | 연산자 조합으로 복잡한 흐름을 선언적으로 표현 |
| | 디바운스, 스로틀, 병합, 재시도가 내장 |
| | `@Published`와 자연스럽게 연결 |
| | 여러 소스를 합치기 쉽다 (`combineLatest`, `zip`) |
| 단점 | **학습 곡선이 급하다** — 연산자가 100개 이상 |
| | 타입이 복잡해 에러 메시지가 불친절하다 |
| | 구독 수명을 직접 관리해야 한다 |
| | 디버깅이 어렵다 (스택 트레이스가 파이프라인 내부) |
| | **Apple이 신규 API를 추가하지 않고 있다** |

### 중요한 흐름 — Apple의 방향

Combine은 2019년(iOS 13)에 나왔고, async/await는 2021년(iOS 15, Swift 5.5)에 나왔다.

**그 이후 Apple의 새 API는 대체로 async/await 기반이다.**

- `URLSession.data(for:)` — async
- `NotificationCenter.notifications(named:)` — `AsyncSequence` ([관련 문서](./for-await-async-sequence.md))
- SwiftUI `.task`, `.refreshable` — async 클로저
- SwiftData, Observation — Combine 의존 없음

`@Observable`이 `ObservableObject`를 대체한 것도 같은 흐름이다. [Observation 문서](./observation-framework-and-observable.md)에서 다룬 대로 `@Published`와 Combine 의존이 사라졌다.

**Combine이 폐기된 것은 아니다.** 여전히 동작하고 유지된다. 다만 **새 코드의 기본 선택지는 async/await**로 옮겨갔다고 보는 것이 정확하다.

### 선택 기준

```text
값을 한 번만 받는가? (네트워크 요청, 파일 읽기)
  → async/await                          ← 이 예제가 여기

값이 시간에 따라 여러 번 오는가?
  ├─ 단순 순회 → AsyncSequence (for await)
  └─ 디바운스·병합·변환이 필요 → Combine

기존 코드가 이미 Combine인가?
  → 일관성을 위해 Combine 유지

@Published, ObservableObject를 쓰고 있는가?
  → Combine이 자연스럽다
  → 다만 @Observable로 옮길 계획이라면 async/await도 함께 검토

UIKit 프레임워크 API가 Combine publisher만 제공하는가?
  → Combine (또는 .values로 AsyncSequence 변환)
```

**Combine → async/await 변환도 가능하다.**

```swift
// publisher를 AsyncSequence로
for await value in publisher.values { ... }

// publisher에서 값 하나만
let value = try await publisher.values.first { _ in true }
```

### 이 예제에서 확인할 것

이 프로젝트는 **두 방식이 섞여 있지 않고 Combine으로 일관되게 작성됐다.** 그 점은 좋다.

다만 코드에 개선 여지가 있다.

**① 상태 코드를 검사하지 않는다**

```swift
.map(\.data)      // response를 버린다
```

chapter-61의 async/await 버전은 `guard (200...299).contains(...)`로 검사했는데 이쪽은 빠져 있다. `tryMap`으로 보완할 수 있다.

**② `Endpoint.withSymbols.url!` 강제 언래핑**

```swift
return urlSession(ExchangeRate.self, with: Endpoint.withSymbols.url!)
```

`url`이 `URL?`이므로 `nil`이면 크래시한다. [guard 문서](./guard-keyword.md)의 방식으로 처리하는 편이 안전하다.

**③ `RunLoop.main`보다 `DispatchQueue.main`**

[연산자 문서](./combine-operators.md)에서 다룬 차이다.

**④ 오류가 `placeholder`로 뭉개진다**

`replaceError`의 문제도 같은 문서에서 다뤘다.

**학습 목적이라면 Combine을 이렇게 써 보는 것이 의미가 있다.** 두 방식을 모두 경험하면 나중에 판단하기 쉬워진다.

## 학습 체크리스트

- [ ] `dataTaskPublisher`의 Output 타입을 확인한다 (`(data:response:)` 튜플).
- [ ] 같은 요청을 async/await로 다시 구현하고 코드 줄 수를 비교한다.
- [ ] async/await 버전에서 `AnyCancellable`이 필요 없어지는 것을 확인한다.
- [ ] `[weak self]`가 async/await 버전에서 불필요한 이유를 설명한다.
- [ ] `publisher.values`로 Combine을 `AsyncSequence`로 바꿔 `for await`으로 받아 본다.
- [ ] `.task { await fetchRates() }`로 뷰에서 호출하고 자동 취소를 확인한다.
- [ ] `debounce` 연산자를 붙여 Combine의 강점을 체감한다.
- [ ] 같은 디바운스를 async/await로 구현해 보고 난이도를 비교한다.
- [ ] `combineLatest`로 두 publisher를 합쳐 본다.
- [ ] `Endpoint.withSymbols.url!`의 강제 언래핑을 `guard`로 바꿔 본다.
- [ ] `.map(\.data)`를 `tryMap`으로 바꿔 상태 코드를 검사한다.
- [ ] `@Observable` + async/await 조합으로 `ViewModel`을 다시 써 본다.

## 공식 참고 자료

- [Apple: URLSession.dataTaskPublisher(for:)](https://developer.apple.com/documentation/foundation/urlsession/datataskpublisher(for:)-6i9wm)
- [Apple: URLSession.DataTaskPublisher](https://developer.apple.com/documentation/foundation/urlsession/datataskpublisher)
- [Apple: URLSession.data(from:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/data(from:delegate:))
- [Apple: Combine](https://developer.apple.com/documentation/combine)
- [Apple: Processing URL session data task results with Combine](https://developer.apple.com/documentation/foundation/processing-url-session-data-task-results-with-combine)
- [Apple: Publisher.values](https://developer.apple.com/documentation/combine/publisher/values-1dm9r)
- [Apple: AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence)
- [Swift 공식 문서: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple: Updating an app to use strict concurrency](https://developer.apple.com/documentation/swift/updating-an-app-to-use-strict-concurrency)
- [Apple: WWDC21 — Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [Apple: WWDC19 — Introducing Combine](https://developer.apple.com/videos/play/wwdc2019/722/)
