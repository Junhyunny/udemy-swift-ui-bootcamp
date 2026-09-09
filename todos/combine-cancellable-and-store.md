# `AnyCancellable`, `sink`, `store(in:)` — 구독의 수명 관리

Combine 전반은 [별도 문서](./combine.md)에 정리했다. 이 문서는 **구독을 붙잡고 끊는 부분**을 다룬다.

## 질문이 나온 코드

`chapter-80/chapter-80/ViewModels/ViewModel.swift`

```swift
private var cancellableSet: Set<AnyCancellable> = []

func fetchRates() {
    ExchangeRateService.shared.getExchangeRate()
        .replaceError(with: ExchangeRate.placeholder)
        .sink { [weak self] in
            self?.exchangeRate = $0
        }
        .store(in: &cancellableSet)
}
```

## 공부할 내용

### `AnyCancellable` — 프로토콜이 아니라 클래스다

질문에 "어떤 프로토콜이야?"라고 되어 있는데 **`AnyCancellable`은 클래스**다.

```swift
final class AnyCancellable
```

프로토콜은 `Cancellable`이고, `AnyCancellable`이 그것을 타입 소거한 구현체다.

| 이름 | 종류 | 역할 |
| --- | --- | --- |
| `Cancellable` | **프로토콜** | `cancel()` 하나를 요구 |
| `AnyCancellable` | **클래스** | 타입 소거된 구현. `sink`가 이걸 돌려준다 |

> Subscriber implementations can use this type to provide a "cancellation token" that makes it possible for a caller to cancel a publisher, but not to use the `Subscription` object to request items.

**"취소 토큰"** 이라는 표현이 정확하다. 구독 자체를 조작하는 권한은 주지 않고, **끊을 권한만** 준다.

### 핵심 성질 — 참조가 사라지면 구독이 끊긴다

이것이 가장 중요하다.

> An `AnyCancellable` instance **automatically calls `cancel()` when deinitialized**.

**`AnyCancellable`이 해제되면 자동으로 구독이 취소된다.** 그래서 어딘가에 붙잡아 두지 않으면 즉시 끊긴다.

```swift
func fetchRates() {
    service.getExchangeRate()
        .sink { ... }        // ⚠️ 반환된 AnyCancellable을 버린다
}                            // 함수가 끝나면 해제 → 구독 즉시 취소
```

이 코드는 컴파일은 되지만 **응답이 오기 전에 구독이 끊겨 아무 일도 일어나지 않는다.** Combine을 처음 쓸 때 가장 흔히 겪는 문제다.

`Cancellable`의 설명이 무엇을 정리하는지 말해 준다.

> Calling `cancel()` frees up any allocated resources. It also stops side effects such as timers, network access, or disk I/O.

### `sink` — 구독을 시작한다

```swift
func sink(receiveValue: @escaping (Self.Output) -> Void) -> AnyCancellable
```

**publisher는 구독자가 붙기 전까지 아무것도 하지 않는다.** `sink`가 그 구독자 역할을 하며 실제 작업을 시작시킨다.

> A cancellable instance, which you use when you end assignment of the received value. **Deallocation of the result will tear down the subscription stream.**

두 가지 형태가 있다.

```swift
// ① 값만 받는다 — Failure == Never일 때만 쓸 수 있다
.sink { value in ... }

// ② 완료와 값을 모두 받는다
.sink(
    receiveCompletion: { completion in ... },   // .finished 또는 .failure(error)
    receiveValue: { value in ... }
)
```

**이 예제가 ①을 쓸 수 있는 이유**가 있다. 바로 위에 `replaceError(with:)`가 있어 오류가 사라지고 `Failure`가 `Never`가 되기 때문이다. `replaceError`를 지우면 ①은 컴파일되지 않는다. [Combine 연산자 문서](./combine-operators.md)에서 다룬다.

### `store(in:)` — 붙잡아 두는 곳

```swift
.store(in: &cancellableSet)
```

`AnyCancellable`을 컬렉션에 담아 수명을 늘린다. 매번 변수를 만들지 않아도 되게 해 주는 편의 메서드다.

```swift
// store 없이 직접 담으면
let c = publisher.sink { ... }
cancellableSet.insert(c)

// store를 쓰면 한 줄
publisher.sink { ... }.store(in: &cancellableSet)
```

`Set<AnyCancellable>`을 쓰는 것이 관례다. `[AnyCancellable]` 배열도 동작하지만, `Set`은 중복 저장을 막고 개별 제거가 쉽다.

### `&`는 무엇인가 — `inout`

질문의 `&` 키워드다. **참조 전달이 아니라 `inout` 파라미터를 넘긴다는 표시**다.

```swift
func store(in set: inout Set<AnyCancellable>)
```

`store`가 컬렉션에 원소를 **추가해야** 하므로 원본을 수정할 수 있어야 한다. `Set`은 값 타입이라 그냥 넘기면 복사본이 전달되어 원본이 바뀌지 않는다. `inout`이 그 문제를 해결하고, 호출부에서는 `&`로 "여기서 값이 바뀔 수 있다"를 명시한다.

이미 본 적이 있다. [`hash(into:)`](./hash-into-and-java-comparison.md)의 `inout Hasher`, [`PreferenceKey.reduce`](./preference-key-and-onpreferencechange.md)의 `inout Value`가 같은 문법이다.

`inout`은 [배타적 접근 규칙](./swift-memory-model.md)의 대상이라, 같은 변수를 두 `inout` 자리에 동시에 넘길 수 없다.

### 전체 흐름

```text
publisher (아직 아무것도 안 함)
      ↓ .sink { }
구독 시작 → AnyCancellable 반환
      ↓ .store(in: &set)
Set이 AnyCancellable을 붙잡는다 → 구독 유지
      ↓
ViewModel이 해제됨 → Set도 해제 → AnyCancellable 해제
      ↓
자동으로 cancel() → 구독 종료
```

### 이 코드의 `deinit`은 사실 불필요하다

```swift
deinit {
    cancellableSet.forEach { $0.cancel() }
}
```

**`AnyCancellable`이 해제될 때 자동으로 `cancel()`을 호출하므로 중복이다.** `ViewModel`이 해제되면 `cancellableSet`도 해제되고, 그 안의 `AnyCancellable`들이 각자 `cancel()`을 부른다.

명시적으로 써서 나쁠 것은 없고 의도가 드러나는 장점도 있다. 다만 "이게 없으면 누수된다"고 오해하지 않는 것이 중요하다. `deinit` 자체에 대해서는 [별도 문서](./weak-self-and-deinit.md)에서 다룬다.

**중간에 취소하고 싶을 때**는 명시적 호출이 필요하다.

```swift
func stopFetching() {
    cancellableSet.removeAll()      // 전부 해제 → 자동 취소
}
```

### `@Observable`과 Combine을 함께 쓰는 것에 대해

이 `ViewModel`은 `@Observable`이면서 Combine을 쓴다. 동작하지만 알아 둘 점이 있다.

```swift
@Observable
final class ViewModel {
    var exchangeRate: ExchangeRate? = nil        // @Observable이 추적
    private var cancellableSet: Set<AnyCancellable> = []   // Combine 구독 보관
}
```

`@Observable`은 **뷰 갱신**을 담당하고, Combine은 **비동기 데이터 흐름**을 담당한다. 역할이 다르므로 공존이 문제는 아니다.

다만 `cancellableSet`은 UI와 무관하므로 추적할 이유가 없다. [`@ObservationIgnored`](./observation-framework-and-observable.md)를 붙이는 편이 낫다.

```swift
@ObservationIgnored
private var cancellableSet: Set<AnyCancellable> = []
```

**async/await로 옮기면 이 모든 것이 사라진다.** `AnyCancellable`, `store`, `deinit`이 필요 없어진다. 선택 기준은 [Combine과 async/await 비교](./combine-vs-async-await.md)에 정리했다.

### 정리

```text
Cancellable      프로토콜 — cancel() 하나
AnyCancellable   클래스 — sink가 돌려주는 취소 토큰
                 해제되면 자동으로 cancel() 호출  ← 핵심

sink        구독을 시작하고 AnyCancellable을 돌려준다
            반환값을 버리면 즉시 구독이 끊긴다
store(in:)  AnyCancellable을 컬렉션에 담아 수명 유지
&           inout 표시 — Set을 수정해야 하므로 필요

deinit의 forEach cancel()은 중복이다 (자동 호출됨)
```

## 학습 체크리스트

- [ ] `.store(in: &cancellableSet)`을 지우고 응답이 오지 않는 것을 확인한다.
- [ ] `AnyCancellable`이 클래스인지 프로토콜인지 정의로 점프해 확인한다.
- [ ] `sink`의 반환 타입을 `print(type(of:))`로 확인한다.
- [ ] `replaceError`를 지우고 `sink { }` 한 인자 형태가 컴파일되지 않는 것을 확인한다.
- [ ] `sink(receiveCompletion:receiveValue:)` 형태로 바꿔 완료 이벤트를 출력한다.
- [ ] `deinit`의 `forEach { cancel() }`을 지우고도 정상 동작하는지 확인한다.
- [ ] `deinit`에 `print`를 넣어 `ViewModel`이 언제 해제되는지 관찰한다.
- [ ] `cancellableSet.removeAll()`로 중간에 구독을 끊어 본다.
- [ ] `store`의 시그니처에서 `inout`을 확인한다.
- [ ] `&`를 빼고 호출해 컴파일 에러를 확인한다.
- [ ] `Set<AnyCancellable>`을 `[AnyCancellable]`로 바꿔도 동작하는지 확인한다.
- [ ] `cancellableSet`에 `@ObservationIgnored`를 붙여 본다.
- [ ] `fetchRates()`를 여러 번 호출하고 `cancellableSet.count`를 확인한다.

## 공식 참고 자료

- [Apple: AnyCancellable](https://developer.apple.com/documentation/combine/anycancellable)
- [Apple: Cancellable](https://developer.apple.com/documentation/combine/cancellable)
- [Apple: Cancellable.cancel()](https://developer.apple.com/documentation/combine/cancellable/cancel())
- [Apple: AnyCancellable.store(in:)](https://developer.apple.com/documentation/combine/anycancellable/store(in:)-3hyxs)
- [Apple: Publisher.sink(receiveValue:)](https://developer.apple.com/documentation/combine/publisher/sink(receivevalue:))
- [Apple: Publisher.sink(receiveCompletion:receiveValue:)](https://developer.apple.com/documentation/combine/publisher/sink(receivecompletion:receivevalue:))
- [Apple: Subscriber](https://developer.apple.com/documentation/combine/subscriber)
- [Apple: Combine](https://developer.apple.com/documentation/combine)
- [Swift 공식 문서: Functions — In-Out Parameters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/#In-Out-Parameters)
