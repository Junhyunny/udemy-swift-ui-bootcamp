# Combine 연산자 — `replaceError`, `receive(on:)`, `map`, `decode`

구독 수명 관리는 [별도 문서](./combine-cancellable-and-store.md)에 정리했다. 이 문서는 **파이프라인 중간의 연산자들**을 다룬다.

## 질문이 나온 코드

`chapter-80/chapter-80/Services/ExchangeRateService.swift`

```swift
URLSession.shared
    .dataTaskPublisher(for: url)
    .map(\.data)
    .decode(type: type.self, decoder: JSONDecoder())
    .receive(on: RunLoop.main)
    .print()
    .eraseToAnyPublisher()
```

`chapter-80/chapter-80/ViewModels/ViewModel.swift`

```swift
.replaceError(with: ExchangeRate.placeholder)
```

## 1부 — `replaceError(with:)`

### 질문 확인: fallback 처리 방법이다

**맞다.** 다만 정확히는 **"오류를 값 하나로 바꾸고 스트림을 끝낸다"** 는 동작이다.

```swift
func replaceError(with output: Self.Output) -> Publishers.ReplaceError<Self>
```

> If the upstream publisher fails with an error, this publisher emits the provided element, then **finishes normally**.

Apple 문서의 예제가 동작을 잘 보여 준다.

```swift
struct MyError: Error {}
let fail = Fail<String, MyError>(error: MyError())
cancellable = fail
    .replaceError(with: "(replacement element)")
    .sink(
        receiveCompletion: { print ("\($0)") },
        receiveValue: { print ("\($0)", terminator: " ") }
    )

// Prints: "(replacement element) finished".
```

`failure`가 아니라 **`finished`로 끝난다**는 점이 핵심이다. 오류가 완전히 사라진다.

### 부수 효과 — `Failure`가 `Never`가 된다

이것이 실용적으로 중요하다.

```swift
// replaceError 전: AnyPublisher<ExchangeRate, Error>
// replaceError 후: Publishers.ReplaceError<...>  — Failure == Never
```

`Failure`가 `Never`이므로 **인자 하나짜리 `sink`를 쓸 수 있다.**

```swift
.replaceError(with: ExchangeRate.placeholder)
.sink { [weak self] in           // ← 이게 가능해진 이유
    self?.exchangeRate = $0
}
```

`replaceError`를 지우면 이 `sink`는 컴파일되지 않고 `sink(receiveCompletion:receiveValue:)`를 써야 한다.

### 이 코드의 문제 — 오류가 조용히 사라진다

```swift
.replaceError(with: ExchangeRate.placeholder)
```

`placeholder`는 `date`와 `rates`가 모두 `nil`인 빈 값이다.

```swift
static var placeholder: ExchangeRate {
    Self(date: nil, rates: nil)
}
```

**네트워크 실패, 디코딩 실패, API 키 오류가 모두 "빈 데이터"로 뭉개진다.** 사용자는 왜 아무것도 안 보이는지 알 수 없고, 개발자도 원인을 추적할 수 없다.

chapter-61의 `catch {}`와 같은 문제다. [오류 처리 문서](./swift-error-handling-forms.md)에서 다룬 내용이다.

### 다른 fallback 방법들

| 연산자 | 동작 | 스트림 |
| --- | --- | --- |
| `replaceError(with:)` | 값 하나로 대체 후 종료 | **끝난다** |
| `catch { }` | **다른 publisher로 교체** | 계속된다 |
| `retry(_:)` | 지정 횟수만큼 재시도 | 성공하면 계속 |
| `mapError { }` | 오류 타입만 변환 | 실패는 유지 |
| `assertNoFailure()` | 오류 시 크래시 (디버그용) | — |

**`catch`가 더 유연하다.**

> This `replaceError(with:)` functionality is useful when you want to handle an error by sending a single replacement element and end the stream. **Use `catch(_:)` to recover from an error and provide a replacement publisher** to continue providing elements to the downstream subscriber.

```swift
// 오류를 다른 publisher로 교체 — 캐시된 값을 내보내는 등
.catch { error in
    print("실패:", error)                    // 원인을 남긴다
    return Just(ExchangeRate.placeholder)
}

// 재시도 후 fallback
.retry(2)
.catch { _ in Just(ExchangeRate.placeholder) }
```

**오류를 상태로 노출하는 방식**이 실제 앱에는 더 적합하다.

```swift
enum LoadState {
    case loading
    case loaded(ExchangeRate)
    case failed(String)
}

.sink(
    receiveCompletion: { [weak self] completion in
        if case .failure(let error) = completion {
            self?.state = .failed(error.localizedDescription)
        }
    },
    receiveValue: { [weak self] rate in
        self?.state = .loaded(rate)
    }
)
```

## 2부 — `receive(on: RunLoop.main)`

### 질문 확인: 메인에서 실행하겠다는 의미다

**맞다.** 정확히는 **"이 아래(downstream)의 값과 완료를 지정한 스케줄러에서 전달하라"** 는 뜻이다.

> You use the `receive(on:options:)` operator to receive results and completion on a specific scheduler, such as **performing UI work on the main run loop**. In contrast with `subscribe(on:options:)`, which affects upstream messages, `receive(on:options:)` changes the execution context of **downstream** messages.

**upstream과 downstream의 구분이 중요하다.**

```swift
publisher
    .subscribe(on: backgroundQueue)   // ← 구독·요청이 시작되는 곳 (upstream)
    .map { ... }
    .receive(on: RunLoop.main)        // ← 이 아래로 값이 전달되는 곳 (downstream)
    .sink { ... }                     // 메인에서 실행된다
```

이 예제에서는 `.receive(on: RunLoop.main)` 아래에 `sink`가 있으므로, `sink` 안의 `self?.exchangeRate = $0`이 메인 스레드에서 실행된다.

**왜 필요한가**는 [MainActor 문서](./main-actor-and-ios-threading.md)에서 다룬 그대로다. `exchangeRate`는 `@Observable` 프로퍼티이고 UI를 갱신하므로 메인 스레드여야 한다. `URLSession`은 백그라운드에서 응답을 주므로 경계를 넘겨야 한다.

### `RunLoop.main` vs `DispatchQueue.main`

둘 다 쓸 수 있고 미묘하게 다르다.

| | `RunLoop.main` | `DispatchQueue.main` |
| --- | --- | --- |
| 정체 | 메인 런루프 | 메인 디스패치 큐 |
| 전달 시점 | **런루프가 한가할 때** | 다음 큐 사이클 |
| 스크롤 중 | **지연될 수 있다** | 비교적 즉시 |
| 일반 권장 | — | **이쪽이 안전** |

`RunLoop.main`은 사용자가 스크롤하는 등 런루프가 특정 모드에 있을 때 값 전달이 미뤄질 수 있다. **`DispatchQueue.main`이 더 예측 가능하다.**

```swift
.receive(on: DispatchQueue.main)      // 일반적으로 이쪽을 권장
```

Apple도 스케줄러 사용 자체를 권한다.

> Prefer `receive(on:options:)` over explicit use of dispatch queues when performing work in subscribers.

즉 `sink` 안에서 `DispatchQueue.main.async { }`를 쓰는 것보다 `receive(on:)`으로 선언하는 편이 낫다는 뜻이다.

## 3부 — 나머지 연산자들

### `map(\.data)`

`dataTaskPublisher`가 내보내는 것은 튜플이다.

```swift
(data: Data, response: URLResponse)
```

`map(\.data)`는 그중 `data`만 꺼낸다. `\.data`는 [key path](./foreach-id-and-identity-keypath.md)이고, `map { $0.data }`와 같다.

**주의할 점**: 이 코드는 `response`를 버리므로 **HTTP 상태 코드를 검사하지 않는다.** 401이나 404가 와도 그대로 디코딩을 시도한다. chapter-61의 async/await 버전은 상태 코드를 확인했는데 이쪽은 빠져 있다.

```swift
// 상태 코드를 확인하는 형태
.tryMap { data, response in
    guard let http = response as? HTTPURLResponse,
          (200...299).contains(http.statusCode) else {
        throw URLError(.badServerResponse)
    }
    return data
}
```

### `decode(type:decoder:)`

`Data`를 `Decodable` 타입으로 변환한다. 실패하면 스트림이 오류로 끝난다.

```swift
.decode(type: type.self, decoder: JSONDecoder())
```

`type.self`는 이미 `T.Type`인 `type`에 `.self`를 다시 붙인 형태다. 그냥 `type`으로 써도 된다.

```swift
.decode(type: type, decoder: JSONDecoder())
```

[메타타입 문서](./metatype-and-self.md)에서 다룬 `.self`다.

### `.print()`

디버깅용이다. 구독·값·완료 이벤트를 모두 콘솔에 찍는다.

```
receive subscription: (DataTaskPublisher)
request unlimited
receive value: (ExchangeRate(...))
receive finished
```

**릴리스 빌드에 남기지 않는 것이 좋다.** 파이프라인의 모든 이벤트를 출력하므로 로그가 지저분해지고 약간의 성능 비용도 있다.

```swift
#if DEBUG
    .print("ExchangeRate")
#endif
```

이렇게 감싸거나, 문제를 해결한 뒤 지운다.

### `eraseToAnyPublisher()`

반환 타입을 `AnyPublisher`로 감춘다. 없으면 이런 타입이 노출된다.

```swift
Publishers.Print<Publishers.ReceiveOn<Publishers.Decode<Publishers.MapKeyPath<URLSession.DataTaskPublisher, Data>, T, JSONDecoder>, RunLoop>>
```

연산자를 하나 추가할 때마다 타입이 중첩된다. [`some View`와 `ModifiedContent`](./some-keyword-opaque-types.md)에서 본 것과 같은 구조다. [AnyPublisher 문서](./combine.md)에서 이어서 다룬다.

### 연산자 순서가 중요하다

```swift
// 현재
.decode(...)
.receive(on: RunLoop.main)     // 디코딩은 백그라운드, 전달은 메인

// 뒤바꾸면
.receive(on: RunLoop.main)
.decode(...)                    // ⚠️ 디코딩도 메인에서 — UI가 멈출 수 있다
```

**무거운 작업은 `receive(on:)` 위에 두는 것이 맞다.** 현재 코드는 이 순서를 지키고 있다.

### 정리

```text
replaceError(with:)
  오류를 값 하나로 바꾸고 finished로 종료
  Failure가 Never가 되어 sink { } 한 인자 형태를 쓸 수 있다
  단점: 오류 원인이 사라진다 → catch나 상태 노출이 낫다

receive(on:)
  downstream 실행 문맥을 바꾼다 (upstream은 subscribe(on:))
  RunLoop.main보다 DispatchQueue.main이 예측 가능하다

map(\.data)   튜플에서 data만 — response를 버려 상태 코드 검사가 없다
decode        Data → Decodable, 실패 시 스트림 종료
print()       디버깅용, 릴리스에서는 제거
eraseToAnyPublisher()  중첩 타입을 감춘다

순서: 무거운 작업은 receive(on:) 위에
```

## 학습 체크리스트

- [ ] `replaceError`를 지우고 `sink { }`가 컴파일되지 않는 것을 확인한다.
- [ ] `sink(receiveCompletion:receiveValue:)`로 바꿔 `finished`가 오는지 확인한다.
- [ ] 잘못된 URL로 실패시키고 `placeholder`가 들어오는지 확인한다.
- [ ] `replaceError`를 `catch { error in print(error); return Just(...) }`로 바꿔 원인을 출력한다.
- [ ] `retry(2)`를 추가하고 실패 시 재시도되는지 관찰한다.
- [ ] `receive(on:)`을 지우고 `Thread.isMainThread`를 출력해 스레드를 확인한다.
- [ ] `RunLoop.main`을 `DispatchQueue.main`으로 바꿔 동작을 비교한다.
- [ ] `receive(on:)`을 `decode` 위로 옮기고 차이를 생각해 본다.
- [ ] `map(\.data)`를 `tryMap`으로 바꿔 상태 코드를 검사해 본다.
- [ ] 잘못된 API 키로 401을 받아 현재 코드가 그것을 감지하지 못하는 것을 확인한다.
- [ ] `.print()`의 출력을 읽고 어떤 이벤트가 흐르는지 파악한다.
- [ ] `.print("태그")`로 라벨을 붙여 본다.
- [ ] `eraseToAnyPublisher()`를 지우고 반환 타입 에러 메시지를 읽는다.
- [ ] `decode(type: type.self, ...)`를 `decode(type: type, ...)`로 바꿔도 되는지 확인한다.

## 공식 참고 자료

- [Apple: Publisher.replaceError(with:)](https://developer.apple.com/documentation/combine/publisher/replaceerror(with:))
- [Apple: Publisher.catch(_:)](https://developer.apple.com/documentation/combine/publisher/catch(_:))
- [Apple: Publisher.retry(_:)](https://developer.apple.com/documentation/combine/publisher/retry(_:))
- [Apple: Publisher.mapError(_:)](https://developer.apple.com/documentation/combine/publisher/maperror(_:))
- [Apple: Publisher.receive(on:options:)](https://developer.apple.com/documentation/combine/publisher/receive(on:options:))
- [Apple: Publisher.subscribe(on:options:)](https://developer.apple.com/documentation/combine/publisher/subscribe(on:options:))
- [Apple: Publisher.map(_:)](https://developer.apple.com/documentation/combine/publisher/map(_:)-99evh)
- [Apple: Publisher.tryMap(_:)](https://developer.apple.com/documentation/combine/publisher/trymap(_:))
- [Apple: Publisher.decode(type:decoder:)](https://developer.apple.com/documentation/combine/publisher/decode(type:decoder:))
- [Apple: Publisher.print(_:to:)](https://developer.apple.com/documentation/combine/publisher/print(_:to:))
- [Apple: Publisher.eraseToAnyPublisher()](https://developer.apple.com/documentation/combine/publisher/erasetoanypublisher())
- [Apple: Scheduler](https://developer.apple.com/documentation/combine/scheduler)
- [Apple: RunLoop](https://developer.apple.com/documentation/foundation/runloop)
- [Apple: Just](https://developer.apple.com/documentation/combine/just)
