# Combine 프레임워크와 `AnyPublisher`

구독 수명 관리는 [별도 문서](./combine-cancellable-and-store.md)에, 연산자는 [여기](./combine-operators.md)에, async/await와의 비교는 [여기](./combine-vs-async-await.md)에 정리했다. 이 문서는 **전체 그림과 `AnyPublisher`** 를 다룬다.

## 질문이 나온 코드

`chapter-09/chapter-09/ContentView.swift`의 `internal import Combine`, `ObservableObject`, `@Published`

`chapter-80/chapter-80/Services/ExchangeRateService.swift`

```swift
// TODO, AnyPublisher 프로토콜은 뭐야? 언제 사용해?
func getExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
    return urlSession(ExchangeRate.self, with: Endpoint.withSymbols.url!)
}
```

## 1부 — 기본 구조

### 세 축으로 이루어진다

Combine은 **시간에 따라 발생하는 값을 선언적으로 처리하는** 프레임워크다.

| 역할 | 프로토콜·타입 | 하는 일 |
| --- | --- | --- |
| 발행 | `Publisher` | 값을 내보낸다 |
| 구독 | `Subscriber` | 값을 받는다 |
| 연결 | `Subscription` | 둘 사이의 연결을 관리 |
| 취소 | `Cancellable` | 연결을 끊는다 |

`Publisher`는 두 개의 associated type을 갖는다.

```swift
protocol Publisher<Output, Failure> {
    associatedtype Output       // 내보내는 값의 타입
    associatedtype Failure: Error   // 실패할 수 있는 오류 타입
}
```

**`Failure`가 `Never`면 절대 실패하지 않는다는 뜻**이고, 그때만 인자 하나짜리 `sink`를 쓸 수 있다. [연산자 문서](./combine-operators.md)에서 다룬 `replaceError`가 이 타입을 바꾼다.

### `@Published`와 `ObservableObject`

Combine의 가장 흔한 접점이다.

```swift
class StopWatchViewModel: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
}
```

- `ObservableObject`는 `objectWillChange` publisher를 제공한다
- `@Published`를 붙인 프로퍼티는 변경 이벤트를 발행하고, `$프로퍼티명`으로 그 publisher에 접근한다
- SwiftUI가 `objectWillChange`를 구독해 뷰를 갱신한다

```swift
$elapsedTime
    .sink { print("변경:", $0) }
    .store(in: &cancellables)
```

**다만 이 방식은 구형이다.** [`@Observable`](./observation-framework-and-observable.md)이 iOS 17에서 이를 대체했고, 그쪽은 Combine 의존이 없다. 그래서 최신 SwiftUI 코드에서 Combine을 쓸 이유가 줄었다.

### 파이프라인 — 연산자를 이어 붙인다

Combine의 핵심 사용법이다.

```swift
URLSession.shared
    .dataTaskPublisher(for: url)      // Publisher 생성
    .map(\.data)                       // 변환
    .decode(type: T.self, decoder: JSONDecoder())   // 변환
    .receive(on: RunLoop.main)         // 실행 문맥 변경
    .eraseToAnyPublisher()             // 타입 감추기
```

각 연산자가 **새 publisher를 감싸 돌려준다.** 그래서 타입이 계속 중첩된다 — 이 점이 `AnyPublisher`가 필요한 이유다.

## 2부 — `AnyPublisher`

### 프로토콜이 아니라 구조체다

질문에 "프로토콜은 뭐야?"라고 되어 있는데 **`AnyPublisher`는 `struct`** 다.

```swift
@frozen struct AnyPublisher<Output, Failure> where Failure : Error
```

프로토콜은 `Publisher`이고, `AnyPublisher`가 그것을 **타입 소거(type erasure)** 한 구현체다.

| 이름 | 종류 |
| --- | --- |
| `Publisher` | **프로토콜** |
| `AnyPublisher` | **구조체** — 타입 소거된 래퍼 |

[`AnyCancellable`도 클래스](./combine-cancellable-and-store.md)였던 것과 같은 구조다. `Any` 접두사가 붙은 Combine 타입들은 대체로 타입 소거 래퍼다.

### 무엇을 해결하나 — 타입이 폭발한다

`eraseToAnyPublisher()`가 없으면 반환 타입이 이렇게 된다.

```swift
Publishers.Print<
  Publishers.ReceiveOn<
    Publishers.Decode<
      Publishers.MapKeyPath<URLSession.DataTaskPublisher, Data>,
      T, JSONDecoder>,
    RunLoop>>
```

**연산자를 하나 추가할 때마다 한 겹씩 늘어난다.** 이 타입을 함수 시그니처에 적는 것은 현실적으로 불가능하고, 적었다 해도 연산자를 하나 바꾸면 시그니처를 다시 써야 한다.

[`some View`와 `ModifiedContent`](./some-keyword-opaque-types.md)에서 본 것과 똑같은 문제다.

### 무엇을 감추나

Apple 문서의 설명이다.

> `AnyPublisher` is a concrete implementation of `Publisher` that has no significant properties of its own, and passes through elements and completion values from its upstream publisher.
>
> Use `AnyPublisher` to wrap a publisher whose type has details you don't want to expose across API boundaries, such as different modules. **Wrapping a `Publisher` with `AnyPublisher` also prevents callers from accessing its `receive(subscriber:)` method.** When you use type erasure this way, you can change the underlying publisher implementation over time without affecting existing clients.

세 가지를 얻는다.

- **타입 세부사항을 감춘다** — 호출자는 `AnyPublisher<ExchangeRate, Error>`만 안다
- **`receive(subscriber:)` 접근을 막는다** — 저수준 구독 조작을 차단
- **구현을 바꿀 수 있다** — 연산자를 추가·제거해도 시그니처가 그대로다

마지막이 실용적으로 중요하다. 이 예제에서 `.print()`를 추가하거나 제거해도 `getExchangeRate()`의 반환 타입은 변하지 않는다.

### `eraseToAnyPublisher()`

타입 소거를 수행하는 연산자다.

> You can use Combine's `eraseToAnyPublisher()` operator to wrap a publisher with `AnyPublisher`.

**관례상 파이프라인의 마지막에 붙인다.**

```swift
func urlSession<T: Codable>(_ type: T.Type, with url: URL) -> AnyPublisher<T, Error> {
    URLSession.shared
        .dataTaskPublisher(for: url)
        // ... 연산자들
        .eraseToAnyPublisher()      // ← 마지막
}
```

`AnyPublisher(publisher)` 이니셜라이저로도 같은 일을 할 수 있지만, 연산자 형태가 체인에 자연스럽게 붙는다.

### `some Publisher`를 쓸 수도 있다

Swift 5.7 이후에는 opaque return type도 가능하다.

```swift
func getExchangeRate() -> some Publisher<ExchangeRate, Error> {
    // ...
}
```

| | `AnyPublisher` | `some Publisher` |
| --- | --- | --- |
| 방식 | 런타임 타입 소거 | **컴파일 타임 opaque** |
| 오버헤드 | 박싱 비용 있음 | **없음** |
| 프로퍼티 저장 | 가능 | 제약 있음 |
| 관례 | **널리 쓰임** | 상대적으로 새로움 |

`some`이 성능상 유리하지만, **Combine 생태계에서는 `AnyPublisher`가 사실상 표준**이다. 기존 코드와의 일관성, 프로퍼티로 저장할 수 있다는 점 때문이다. [`some`과 `any`의 차이](./some-keyword-opaque-types.md)에서 다룬 트레이드오프와 같은 구도다.

### 언제 쓰나

**써야 할 때**

- **함수·메서드의 반환 타입** — 이 예제
- 프로토콜 요구사항에서 publisher를 반환할 때
- 프로퍼티로 publisher를 저장할 때
- 모듈 경계를 넘을 때

```swift
protocol ExchangeRateFetching {
    func fetch() -> AnyPublisher<ExchangeRate, Error>    // 프로토콜에는 구체 타입이 필요하다
}
```

**안 써도 될 때**

- 같은 함수 안에서 바로 `sink`로 소비할 때 — 감출 이유가 없다

```swift
// 불필요
publisher
    .map { ... }
    .eraseToAnyPublisher()      // 바로 sink로 갈 거면 필요 없다
    .sink { ... }
```

### 이 코드에서 확인할 것

```swift
func getExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
    return urlSession(ExchangeRate.self, with: Endpoint.withSymbols.url!)
}
```

**`AnyPublisher` 사용은 적절하다.** 서비스 계층이 구현 세부사항을 감추고 호출자(`ViewModel`)에게 안정적인 시그니처를 제공한다.

**다만 `url!` 강제 언래핑이 위험하다.** `Endpoint.url`이 `URL?`이므로 `nil`이면 크래시한다. [URLComponents 문서](./urlcomponents-and-url-building.md)에서 다룬 문제이고, 오류를 publisher로 흘리는 편이 안전하다.

```swift
func getExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
    guard let url = Endpoint.withSymbols.url else {
        return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
    }
    return urlSession(ExchangeRate.self, with: url)
}
```

`Fail`은 즉시 오류를 내보내는 publisher다. 크래시 대신 오류로 전달된다.

### Combine의 주요 타입들

전체 그림을 잡는 데 도움이 되는 목록이다.

| 분류 | 타입 |
| --- | --- |
| Publisher 생성 | `Just`, `Empty`, `Fail`, `Future`, `Deferred` |
| Subject | `PassthroughSubject`, `CurrentValueSubject` |
| 타입 소거 | `AnyPublisher`, `AnySubscriber`, `AnyCancellable` |
| 프로퍼티 래퍼 | `@Published` |
| 스케줄러 | `RunLoop`, `DispatchQueue`, `OperationQueue`, `ImmediateScheduler` |

**`Subject`는 외부에서 값을 밀어 넣을 수 있는 publisher**다. 이벤트 버스처럼 쓸 때 유용하다.

```swift
let subject = PassthroughSubject<String, Never>()
subject.send("값")          // 외부에서 발행
```

## 학습 체크리스트

- [ ] `eraseToAnyPublisher()`를 지우고 반환 타입 에러 메시지에서 중첩 타입을 확인한다.
- [ ] `AnyPublisher`가 `struct`인지 정의로 점프해 확인한다.
- [ ] `.print()`를 추가·제거해도 `getExchangeRate()` 시그니처가 안 바뀌는 것을 확인한다.
- [ ] `some Publisher<ExchangeRate, Error>`로 바꿔 보고 컴파일되는지 확인한다.
- [ ] `Publisher`의 `Output`과 `Failure` 타입을 `print(type(of:))`로 확인한다.
- [ ] `replaceError` 전후로 `Failure` 타입이 어떻게 바뀌는지 확인한다.
- [ ] `Endpoint.withSymbols.url!`을 `guard` + `Fail`로 바꿔 크래시를 없애 본다.
- [ ] `Just("값").sink { print($0) }`로 가장 단순한 파이프라인을 만들어 본다.
- [ ] `PassthroughSubject`로 값을 밀어 넣어 본다.
- [ ] `@Published` 프로퍼티에 `$`를 붙여 publisher를 구독해 본다.
- [ ] 같은 서비스를 `async throws`로 다시 만들어 `AnyPublisher`가 불필요해지는 것을 확인한다.

## 참고 자료

- [Apple: Combine](https://developer.apple.com/documentation/combine)
- [Apple: Publisher](https://developer.apple.com/documentation/combine/publisher)
- [Apple: AnyPublisher](https://developer.apple.com/documentation/combine/anypublisher)
- [Apple: Publisher.eraseToAnyPublisher()](https://developer.apple.com/documentation/combine/publisher/erasetoanypublisher())
- [Apple: Subscriber](https://developer.apple.com/documentation/combine/subscriber)
- [Apple: Subscription](https://developer.apple.com/documentation/combine/subscription)
- [Apple: ObservableObject](https://developer.apple.com/documentation/combine/observableobject)
- [Apple: Published](https://developer.apple.com/documentation/combine/published)
- [Apple: Just](https://developer.apple.com/documentation/combine/just)
- [Apple: Fail](https://developer.apple.com/documentation/combine/fail)
- [Apple: PassthroughSubject](https://developer.apple.com/documentation/combine/passthroughsubject)
- [Apple: CurrentValueSubject](https://developer.apple.com/documentation/combine/currentvaluesubject)
- [Apple: Receiving and Handling Events with Combine](https://developer.apple.com/documentation/combine/receiving-and-handling-events-with-combine)
