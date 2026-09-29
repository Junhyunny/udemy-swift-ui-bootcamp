# `for await` — 비동기 시퀀스를 반복하기

`async/await` 실행 모델은 [별도 문서](./101-swift-async-await-model.md)에 정리했다. 이 문서는 **`for await` 구문과 `AsyncSequence`** 를 다룬다.

## 질문이 나온 코드

`chapter-65/chapter-65/ContentView.swift`

```swift
for await notification in center.notifications(named: name) {
    // 알림이 올 때마다 실행된다
}
```

## 공부할 내용

### 결론 먼저

- 질문의 이해가 맞다. **비동기로 도착하는 데이터를 `for` 루프처럼 순회하는 구문**이다.
- 일반 `for`와 문법은 같지만, **각 요소를 기다린다**는 점이 다르다.
- 대상은 `Sequence`가 아니라 **`AsyncSequence`** 여야 한다.
- 이 예제처럼 **끝나지 않는 스트림**에도 쓸 수 있다. 그래서 루프가 영원히 돈다.

### `AsyncSequence`란

Apple 문서의 설명이 정확하다.

> An `AsyncSequence` resembles the `Sequence` type — offering a list of values you can step through one at a time — and adds asynchronicity. **An `AsyncSequence` may have all, some, or none of its values available when you first use it.** Instead, you use `await` to receive values as they become available.

핵심은 강조한 문장이다. **처음 순회를 시작할 때 값이 하나도 없어도 된다.** 값은 나중에 하나씩 도착한다.

`Sequence`와 나란히 두면 차이가 분명하다.

| | `Sequence` | `AsyncSequence` |
| --- | --- | --- |
| 값의 존재 | **이미 다 있다** | 시간이 지나며 도착 |
| 순회 | `for x in seq` | **`for await x in seq`** |
| 다음 값 | `next()` (동기) | **`next()` (async)** |
| 끝 | 반드시 끝난다 | **끝나지 않을 수 있다** |
| 예 | `Array`, `Range`, `String` | 알림, 파일 스트림, 네트워크 바이트 |

### 왜 `await`이 붙는가

구조를 보면 이유가 나온다.

> Along with defining the type of values as an associated type called `Element`, the `AsyncSequence` defines a `makeAsyncIterator()` method. This returns an instance of type `AsyncIterator`. Like the standard `IteratorProtocol`, the `AsyncIteratorProtocol` defines a single `next()` method to produce elements. **The difference is that the `AsyncIterator` defines its `next()` method as `async`, which requires a caller to wait for the next value with the `await` keyword.**

즉 `for await`은 이런 루프의 축약이다.

```swift
var iterator = sequence.makeAsyncIterator()
while let element = await iterator.next() {    // ← 여기서 기다린다
    // 본문
}
```

**`await`이 붙는 자리가 "다음 값을 기다리는 지점"** 이다. [async/await 문서](./101-swift-async-await-model.md)에서 다룬 대로 `await`은 실행이 멈출 수 있는 지점을 표시하는데, 여기서는 **매 반복마다** 멈출 수 있다.

Apple 문서의 예제가 이해에 도움이 된다.

```swift
for await number in Counter(howHigh: 10) {
    print(number, terminator: " ")
}
// Prints "1 2 3 4 5 6 7 8 9 10 "
```

출력만 보면 일반 `for`와 같지만, 각 숫자가 도착할 때까지 기다린 것이다.

### 이 예제에서 벌어지는 일

```swift
for await notification in center.notifications(named: name) {
    // 본문
}
```

**중요한 특징: 이 루프는 끝나지 않는다.**

`notifications(named:)`가 돌려주는 시퀀스는 **알림이 올 때마다 요소를 하나씩 내보내고, 끝을 알리지 않는다.** 그래서 흐름이 이렇게 된다.

```text
루프 진입
   ↓
다음 알림을 기다린다 (여기서 정지 — 스레드를 점유하지 않는다)
   ↓
누군가 post → 알림 도착
   ↓
본문 실행 (counter += 1)
   ↓
다시 기다린다 → 무한 반복
```

**"기다린다"가 스레드를 붙잡고 있는 것이 아니라는 점이 핵심이다.** 일반 `while` 루프로 폴링하면 CPU를 소모하지만, `await`은 실행을 **일시 중단(suspend)** 하고 스레드를 놓아준다. 알림이 오면 재개된다.

`SenderView`의 버튼을 누를 때마다 이 루프가 한 번씩 돈다.

### 언제 쓰나

**시간에 따라 값이 도착하는 모든 경우**다.

| 상황 | API |
| --- | --- |
| 알림 수신 | `NotificationCenter.notifications(named:)` |
| 파일을 한 줄씩 읽기 | `URL.lines` |
| 네트워크 응답을 바이트 단위로 | `URLSession.bytes(for:)` |
| 타이머 | `Timer.publish(...).values` |
| 직접 만든 스트림 | `AsyncStream`, `AsyncThrowingStream` |
| Combine publisher | `publisher.values` |

**`AsyncStream`으로 직접 만들 수도 있다.** 콜백을 스트림으로 감싸는 방법과 그 함정은 [`AsyncStream` 문서](./154-async-stream.md)에 따로 정리했다.

```swift
let stream = AsyncStream<Int> { continuation in
    for i in 1...5 {
        continuation.yield(i)
    }
    continuation.finish()
}

for await value in stream {
    print(value)
}
```

콜백 기반 API를 `AsyncSequence`로 감쌀 때 쓴다.

### 일반 `for`와 무엇이 같고 다른가

**같은 것**

- 문법 구조가 동일하다
- `break`, `continue`로 흐름을 제어한다
- `where` 절을 쓸 수 있다

```swift
for await notification in center.notifications(named: name) where someCondition {
    // ...
}
```

**다른 것**

- **`await`이 필요하다** — 그래서 `async` 문맥 안에서만 쓸 수 있다
- **끝나지 않을 수 있다**
- **취소에 반응한다** — `Task`가 취소되면 루프가 빠져나온다

마지막 항목이 중요하다. 이 예제의 무한 루프가 앱을 망가뜨리지 않는 이유가 여기 있다.

```swift
Task(priority: .background) {
    await receiveNotifications()      // 무한 루프
}
```

`Task`가 취소되면 `await` 지점에서 루프가 종료된다. 다만 **이 예제는 `Task`를 변수에 담지 않아 취소할 수단이 없다.** [`.task` 문서](./103-task-modifier-and-async-lifecycle.md)에서 다룬 문제다.

`.task`를 쓰면 뷰가 사라질 때 자동으로 취소된다.

```swift
.task {
    await receiveNotifications()      // 뷰가 사라지면 자동 취소
}
```

### 에러가 날 수 있으면 `try`

시퀀스가 에러를 던질 수 있으면 `try`도 붙는다.

```swift
for try await line in url.lines {
    print(line)
}
```

[`async throws` 문서](./102-async-throws-and-custom-errors.md)에서 다룬 대로 `try`와 `await`이 함께 온다. `NotificationCenter`의 알림 시퀀스는 에러를 던지지 않으므로 이 예제에는 `try`가 없다.

### `for await x in` vs `for x in await ...` — `await`은 무엇에 붙는가

둘 다 실제로 쓰이는 문법이고, 헷갈리기 쉽다. 구분 기준은 하나다. **무엇이 비동기인가.**

| 무엇이 비동기인가 | 문법 | 기다리는 횟수 |
| --- | --- | --- |
| **순회 대상**(시퀀스)이 비동기 | `for await n in stream` | 요소마다 매번 |
| **값을 구하는 호출**이 비동기 | `for n in await fetchArray()` | 처음 한 번 |
| 둘 다 | `for await n in await makeStream()` | 한 번 + 매번 |
| 아무것도 아님 | `for n in array` | 안 기다림 |

```swift
// A. 스트림이 비동기 — 요소가 도착할 때마다 기다린다
for await n in stream { }

// B. 배열을 "가져오는 일"만 비동기 — 배열을 받고 나면 평범한 순회다
for n in await fetchArray() { }        // fetchArray() -> [Int]

// C. 스트림을 얻는 것도 비동기, 순회도 비동기
for await n in await makeStream() { }  // makeStream() -> AsyncStream<Int>
```

**B의 `await`은 루프와 아무 상관이 없다.** `let arr = await fetchArray()`의 `await`과 완전히 같은 것으로, 그냥 표현식 앞에 붙는 `await`이다. 아래 두 코드는 동일하다.

```swift
for n in await fetchArray() { print(n) }

let arr = await fetchArray()   // ← 여기의 await 과 같다
for n in arr { print(n) }
```

반면 **A의 `await`은 루프 문법의 일부**라 떼어낼 수 없다.

#### 컴파일러의 진짜 판정 기준 — 프로토콜 스위치

메시지를 보면 `await`의 정체가 분명해진다. **`for` 뒤의 `await` 유무가 "어느 프로토콜을 요구할지"를 고른다.**

| 코드 | 결과 |
| --- | --- |
| `for n in stream` | ❌ `for-in loop requires 'AsyncStream<Int>' to conform to 'Sequence'` |
| `for await n in array` | ❌ `for-in loop requires '[Int]' to conform to 'AsyncSequence'` |

즉 이렇게 읽으면 된다.

- `for n in ...` → 대상이 **`Sequence`** 여야 한다
- `for await n in ...` → 대상이 **`AsyncSequence`** 여야 한다

`fetchArray()`는 `async` 함수지만 **반환 타입은 그냥 `[Int]`** 다. `[Int]`는 `AsyncSequence`가 아니므로 `for await n in fetchArray()`는 실패한다.

```swift
for await n in fetchArray() { }
// ❌ for-in loop requires '[Int]' to conform to 'AsyncSequence'
```

반대로 `await`을 빼면 "호출이 비동기인데 표시가 없다"고 한다.

```swift
for n in fetchArray() { }
// ❌ expression is 'async' but is not marked with 'await'
```

이 둘을 결정적으로 보여주는 예가 `for n in await stream`이다. 오류와 경고가 **함께** 나온다.

```swift
for n in await stream { }
// ❌ for-in loop requires 'AsyncStream<Int>' to conform to 'Sequence'
// ⚠️ no 'async' operations occur within 'await' expression
```

`await`을 표현식 자리에 놓아 봐야 루프는 여전히 `Sequence`를 요구하고, 표현식 `stream`에는 기다릴 것이 없어 경고까지 붙는다. **두 `await`은 이름만 같지 서로 다른 문법**이라는 증거다.

#### `try`가 붙는 자리도 같은 기준이다

| 무엇이 던지는가 | 문법 |
| --- | --- |
| 시퀀스가 순회 중 던짐 | `for try await n in throwingStream` |
| 값을 구하는 호출이 던짐 | `for n in try await fetchThrows()` |
| 둘 다 | `for try await n in try await makeStream()` |

`AsyncThrowingStream`을 `try` 없이 돌리면 이렇게 알려준다.

```swift
for await n in throwingStream { }
// ❌ for-in loop can throw, but is not marked with 'try'
```

순서는 **`for try await`로 고정**이다. 바꿔 쓸 수 없다.

```swift
for await try n in throwingStream { }   // ❌ expected pattern
```

#### 실전에서 B 형태를 자주 만나는 곳 — 액터

`for x in await ...`가 실제 코드에 가장 많이 등장하는 자리는 액터 프로퍼티 접근이다. 프로퍼티 **읽기 자체가** 비동기일 뿐, 결과는 평범한 배열이다.

```swift
actor Store {
    var items: [Int] = [1, 2, 3]
    var stream: AsyncStream<Int> { ... }
}

for n in await store.items { }        // 읽기만 비동기, 순회는 동기
for await n in await store.stream { } // 읽기도 비동기, 순회도 비동기
```

[액터 문서](./153-swift-actor-complete-guide.md)에서 본 격리 도메인 때문에 `await`이 붙는 것이지, 시퀀스가 비동기라서가 아니다.

#### 판단 순서

낯선 루프를 만나면 이렇게 끊어 읽는다.

1. **`in` 뒤 표현식의 타입이 무엇인가?** `[T]`/`Range` 같은 `Sequence`면 `for x in`, `AsyncStream`/`AsyncSequence`면 `for await x in`
2. **그 표현식을 구하는 데 `await`이 필요한가?** 필요하면 `in` 뒤에 `await`을 하나 더 붙인다
3. **1번이 던지면** `for try await`, **2번이 던지면** `in try await`

헷갈리면 **일단 변수로 빼 보는 것**이 가장 빠른 진단법이다.

```swift
let seq = await makeStream()   // 2번이 여기로 분리된다
for await n in seq { }         // 남은 await 이 1번이다
```

### 루프 없이 값 하나만 얻기

`AsyncSequence`에도 `Sequence`처럼 메서드가 있다.

> Single-value methods eliminate the need for a `for await-in` loop, and instead let you make a single `await` call.

```swift
let found = await Counter(howHigh: 10).contains(5)   // true
```

**첫 번째 알림 하나만 받고 끝내려면 이렇게 쓸 수 있다.**

```swift
if let first = await center.notifications(named: name).first(where: { _ in true }) {
    // 첫 알림만 처리
}
```

**변환 메서드도 있다.**

```swift
let stream = Counter(howHigh: 10)
    .map { $0 % 2 == 0 ? "Even" : "Odd" }

for await s in stream {
    print(s, terminator: " ")
}
// Prints "Odd Even Odd Even Odd Even Odd Even Odd Even "
```

`map`, `filter`, `prefix`, `dropFirst` 등이 제공된다. 이 예제에 적용하면 `userInfo` 추출을 시퀀스 단계에서 할 수도 있다.

```swift
let courses = center.notifications(named: name)
    .compactMap { $0.userInfo?["Course"] as? DTCourse }

for await course in courses {
    additionalInfo = "\(course.name) by: \(course.author)"
}
```

**지연 평가된다는 점**도 알아 둘 만하다.

> These returned sequences don't eagerly await the next member of the sequence, which allows the caller to decide when to start work.

`map`을 호출한다고 바로 실행되지 않는다. `for await`으로 순회를 시작해야 동작한다.

### 정리

```text
for await x in asyncSeq { }
  = while let x = await iterator.next() { }

Sequence      값이 이미 다 있다        for x in
AsyncSequence 값이 시간에 따라 도착한다  for await x in

특징
  await 지점에서 스레드를 놓아준다 (폴링이 아니다)
  끝나지 않는 스트림도 가능 — 이 예제가 그 경우
  Task 취소에 반응해 루프를 빠져나온다
  에러를 던지면 for try await

용도
  알림, 파일 라인, 네트워크 바이트, 타이머, AsyncStream
```

## 학습 체크리스트

- [ ] `for await` 루프 안에 `print`를 넣어 알림마다 한 번씩 도는 것을 확인한다.
- [ ] 루프 뒤에 `print("끝")`을 넣고 실행되지 않는 것을 확인한다 (끝나지 않는 스트림).
- [ ] `await`을 지우고 컴파일 에러를 확인한다.
- [ ] `receiveNotifications()`에서 `async`를 지우고 어떤 에러가 나는지 본다.
- [ ] `Task`를 변수에 담아 `cancel()`을 호출하고 루프가 종료되는지 확인한다.
- [ ] `onAppear` + `Task`를 `.task`로 바꿔 자동 취소가 되는지 확인한다.
- [ ] `break`로 루프를 빠져나온 뒤 알림이 더 이상 수신되지 않는 것을 확인한다.
- [ ] `AsyncStream`으로 1부터 5까지 내보내는 시퀀스를 직접 만들어 본다.
- [ ] `.compactMap`으로 `userInfo` 추출을 시퀀스 단계로 옮겨 본다.
- [ ] `.prefix(3)`을 붙여 세 번만 받고 끝내 본다.
- [ ] `URL.lines`로 파일을 한 줄씩 읽어 본다 (`for try await` 필요).
- [ ] Apple 문서의 `Counter` 예제를 그대로 구현해 실행한다.
- [ ] `map`을 호출만 하고 순회하지 않았을 때 아무 일도 안 일어나는 것을 확인한다.
- [ ] `async` 함수가 `[Int]`를 반환하게 만들고 `for n in await f()`로 순회한다.
- [ ] 같은 함수에 `for await n in f()`를 써서 `AsyncSequence` 요구 오류를 본다.
- [ ] `for n in await stream`을 써서 오류와 `await` 불필요 경고가 함께 나오는 것을 확인한다.
- [ ] `await makeStream()`을 지역 변수로 분리해 남는 `await`이 무엇인지 확인한다.
- [ ] `AsyncThrowingStream`을 `try` 없이 순회해 `for-in loop can throw` 메시지를 본다.
- [ ] `for await try`로 순서를 바꿔 써 보고 컴파일되지 않는 것을 확인한다.
- [ ] `actor`에 배열 프로퍼티를 두고 `for n in await store.items`를 써 본다.

## 공식 참고 자료

- [Apple: AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence)
- [Apple: AsyncIteratorProtocol](https://developer.apple.com/documentation/swift/asynciteratorprotocol)
- [Apple: AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [Apple: AsyncThrowingStream](https://developer.apple.com/documentation/swift/asyncthrowingstream)
- [Apple: NotificationCenter.notifications(named:object:)](https://developer.apple.com/documentation/foundation/notificationcenter/notifications(named:object:))
- [Apple: NotificationCenter.Notifications](https://developer.apple.com/documentation/foundation/notificationcenter/notifications-swift.struct)
- [Apple: URL.lines](https://developer.apple.com/documentation/foundation/url/lines)
- [Apple: URLSession.bytes(for:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/bytes(for:delegate:))
- [The Swift Programming Language: Concurrency — Asynchronous Sequences](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Asynchronous-Sequences)
- [The Swift Programming Language: Statements — For-In Statement](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#For-In-Statement)
- [Swift 공식 문서: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift 공식 문서: Statements — For-In Statement](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#For-In-Statement)
- [Apple: Sequence](https://developer.apple.com/documentation/swift/sequence)
