# `AsyncStream` — 콜백을 이벤트 스트림으로 바꾸기

`for await` 구문과 `AsyncSequence` 자체는 [`for await` — 비동기 시퀀스를 반복하기](./105-for-await-async-sequence.md)에, 값이 **한 번만** 오는 콜백을 잇는 `withCheckedContinuation`은 [동기 vs 비동기와 중단](./143-sync-vs-async-and-suspension.md)에 정리했다. 이 문서는 **값이 여러 번 오는 콜백을 스트림으로 만드는 `AsyncStream`** 을 다룬다.

이 문서의 모든 출력은 **Apple Swift 6.4 툴체인에서 `-swift-version 6`으로 직접 컴파일·실행해 확인한 실측값**이다.

## 질문이 나온 코드

WebRTC 시그널링을 구독하는 장기 실행 루프다.

```swift
private func observeSignaling() {
    Task {
        for await event in signalingClient.events {
            handle(event)
        }
    }
}
```

이벤트가 없을 때 이 루프가 CPU를 태우는 busy loop인가, 그리고 이 구조를 어떻게 관리해야 하는가가 질문이다.

## 공부할 내용

### 결론 먼저

- `AsyncStream`은 **여러 번 도착하는 값을 `AsyncSequence`로 감싸는 타입**이다. 콜백·델리게이트·옵저버를 `for await`로 바꾸는 표준 도구다.
- 이벤트가 없으면 Task가 **중단(suspend)** 된다. busy loop가 아니다. 측정값으로 확인한다.
- 값을 넣는 쪽은 `Continuation`의 `yield`, 끝내는 쪽은 `finish()`다.
- **가장 큰 함정 둘**: ① 멀티캐스트가 아니다(소비자가 둘이면 이벤트를 나눠 갖는다) ② `events`를 계산 프로퍼티로 만들면 조용히 망가진다.
- 구독 `Task`는 반드시 **저장하고 취소**해야 한다.

### 왜 필요한가 — 콜백에서 스트림으로

콜백 기반 API는 이렇게 생겼다.

```swift
client.onEvent = { event in
    handle(event)
}
```

문제는 [143 문서](./143-sync-vs-async-and-suspension.md)에서 정리한 것과 같다. 호출 횟수도, 실행 스레드도, 에러 경로도 타입에 없다. 게다가 콜백 안에서는 `await`를 쓸 수 없고, 여러 콜백을 조합하려면 중첩이 깊어진다.

`AsyncStream`으로 바꾸면 이렇게 된다.

```swift
for await event in client.events {
    handle(event)
}
```

얻는 것이 분명하다.

- 루프 안에서 `await`를 쓸 수 있다
- `Task`의 취소가 루프 종료로 연결된다
- 소비 순서가 보장된다(스트림은 직렬이다)
- `break`, `return`, `try` 같은 제어 흐름을 그대로 쓴다

### 정말 busy loop가 아닌가 — 측정

이벤트를 하나도 보내지 않고 1초간 `for await`로 대기하는 프로그램과, 같은 1초를 `while`로 도는 프로그램의 CPU 시간을 비교했다.

```swift
// ① for await 로 1초 대기
let (stream, continuation) = AsyncStream.makeStream(of: Int.self)
let t = Task { for await _ in stream { } }
try await Task.sleep(for: .seconds(1))
continuation.finish()
_ = await t.value
```

```swift
// ② 같은 1초를 busy loop 로
let deadline = Date().addingTimeInterval(1)
var spin = 0
while Date() < deadline { spin += 1 }
```

`/usr/bin/time`으로 잰 결과다.

```text
① for await 대기 1초    real 1.35   user 0.00   sys 0.00
② busy loop 1초         real 1.33   user 0.99   sys 0.00   (59,508,145회 순회)
```

**`user` 시간이 0.00초다.** 벽시계로는 똑같이 1초가 흘렀지만 CPU를 전혀 쓰지 않았다. `await` 지점에서 Task가 중단되고 스레드를 협력 스레드 풀에 돌려주기 때문이다([런타임 아키텍처 문서](./151-concurrency-runtime-architecture.md)).

그래서 질문의 이해가 맞다. 개념적으로는 이 구조지만,

```swift
while 스트림이_끝나지_않았으면 {
    let event = await 다음_이벤트     // ← 여기서 멈춘다
    handle(event)
}
```

아래와는 완전히 다르다.

```swift
while true {
    checkEvent()                      // ← CPU 를 계속 태운다
}
```

### 만드는 세 가지 방법

**① `makeStream()` — 지금은 이것이 기본이다 (Swift 5.9+)**

```swift
let (stream, continuation) = AsyncStream.makeStream(of: String.self)
```

스트림과 continuation을 **튜플로 한 번에** 받는다. [SE-0388](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0388-async-stream-factory.md)이 추가한 API다.

**② 클로저 이니셜라이저 — 원래 방식**

```swift
var escaped: AsyncStream<Int>.Continuation?
let stream = AsyncStream<Int> { continuation in
    escaped = continuation
}
```

이 방식에서 자주 나오는 질문이 "클로저가 언제 실행되나"다. **초기화 시점에 동기적으로 즉시 실행된다.**

```text
① 시작 전
①   init 클로저 실행됨
① escaped 설정됨: true
```

그래서 `self.continuation = continuation`으로 continuation을 밖으로 빼내는 패턴이 동작한다. 다만 `makeStream()`이 있으므로 새 코드에서 이 우회는 필요 없다.

**③ `unfolding` 이니셜라이저 — pull 방식**

값을 밀어 넣는(push) 것이 아니라, 소비자가 요청할 때마다 하나씩 만들어 주는(pull) 형태다. `nil`을 반환하면 종료된다.

```swift
actor Ticker {
    var n = 0
    func next() -> Int? { n += 1; return n <= 3 ? n : nil }
}
let ticker = Ticker()
let stream = AsyncStream<Int>(unfolding: { await ticker.next() })
```

```text
⑨ unfolding 결과: [1, 2, 3]
```

콜백을 감쌀 때는 ①②, 직접 값을 생성할 때는 ③이다. **콜백 브리징이 목적이면 거의 항상 ①이다.**

### `Continuation` — 값을 넣고 끝내기

```swift
continuation.yield("joined")     // 값 하나를 보낸다
continuation.finish()            // 스트림을 끝낸다
```

`yield`는 **버려도 되지만 의미가 있는 반환값**(`YieldResult`)을 준다.

```swift
let (stream, c) = AsyncStream.makeStream(of: Int.self, bufferingPolicy: .bufferingNewest(2))
print(c.yield(1), c.yield(2), c.yield(3))
c.finish()
print(c.yield(99))
```

```text
③ yield 결과: enqueued(remaining: 1) / enqueued(remaining: 0) / dropped(1)
③ yield 이후 finish 뒤 yield: terminated
```

읽는 법은 이렇다.

| 반환값 | 의미 |
| --- | --- |
| `enqueued(remaining:)` | 버퍼에 들어갔다. 남은 자리 수를 알려 준다 |
| `dropped(값)` | 버퍼가 꽉 차서 **그 값이 버려졌다** |
| `terminated` | 스트림이 이미 끝났다. **조용히 무시된다** |

**`finish()` 이후의 `yield`는 에러가 아니라 무시된다.** 크래시도 경고도 없다. 이벤트가 사라지는 버그를 찾을 때 여기를 봐야 한다.

소비자가 아직 없어도 `yield`한 값은 버려지지 않는다(기본 정책이 `.unbounded`다).

```swift
c.yield(1); c.yield(2); c.yield(3); c.finish()
for await v in stream { got.append(v) }   // 나중에 순회
```

```text
② 소비 전에 yield한 값: [1, 2, 3]
```

### 버퍼링 정책 — 소비가 느릴 때 무엇을 버리나

생산이 소비보다 빠를 때의 정책을 이니셜라이저에서 정한다.

| 정책 | 동작 |
| --- | --- |
| `.unbounded` (기본) | 전부 쌓는다. **메모리가 무한정 늘 수 있다** |
| `.bufferingNewest(n)` | 최근 n개를 남기고 **오래된 것을 버린다** |
| `.bufferingOldest(n)` | 먼저 온 n개를 남기고 **새로 온 것을 버린다** |

1, 2, 3을 넣고 확인한 결과다.

```text
③ bufferingNewest(2) 결과: [2, 3]     ← 오래된 1 이 버려졌다
④ bufferingOldest(2) 결과: [1, 2]     ← 새로 온 3 이 버려졌다
```

선택 기준은 **이벤트의 성격**이다.

- 시그널링 메시지, 주문 이벤트처럼 **하나도 놓치면 안 되는 것** → `.unbounded`. 단 소비가 막히지 않도록 설계해야 한다.
- 위치 좌표, 센서 값, 진행률처럼 **최신 값만 의미 있는 것** → `.bufferingNewest(1)`
- 로그 앞부분만 필요할 때 → `.bufferingOldest(n)`

`AsyncStream`에는 **역압(backpressure)이 없다.** 생산자를 멈춰 세울 방법이 없어서 정책으로 버리거나 무한히 쌓는 선택뿐이다. 진짜 역압이 필요하면 `AsyncStream`이 아니라 다른 도구(예: swift-async-algorithms의 `AsyncChannel`)를 봐야 한다.

### 함정 ① — 멀티캐스트가 아니다

**가장 많이 틀리는 지점이다.** `AsyncStream`은 Combine의 `Publisher`처럼 여러 구독자에게 같은 값을 뿌리지 않는다. 소비자가 둘이면 **이벤트를 나눠 갖는다.**

```swift
let (stream, c) = AsyncStream.makeStream(of: Int.self)
let a = Task { for await v in stream { ... } }
let b = Task { for await v in stream { ... } }
for i in 1...6 { c.yield(i) }
```

```text
⑤ 소비자 A: [1, 3, 5]
⑤ 소비자 B: [2, 4, 6]
⑤ 합집합 크기: 6 (6이면 나눠 가진 것)
```

각 값은 **정확히 한 소비자에게만** 간다. 그래서 `observeSignaling()`을 두 번 호출하면 이벤트의 절반씩만 처리되는, 재현하기 어려운 버그가 된다.

여러 곳에서 같은 이벤트를 받아야 하면 선택지는 셋이다.

- 구독은 한 곳에서만 하고, 그 안에서 필요한 곳으로 나눠 준다 (권장)
- 소비자마다 **별도의 스트림**을 만들어 생산자가 전부에 `yield`한다
- 멀티캐스트가 본질이면 `AsyncStream`이 아니라 Combine이나 `@Observable`이 맞다

### 함정 ② — `events`를 계산 프로퍼티로 만들면 안 된다

이 코드가 왜 위험한지 실제로 확인했다.

```swift
final class BadClient {
    private var continuation: AsyncStream<String>.Continuation?
    var events: AsyncStream<String> {                 // ← 계산 프로퍼티
        AsyncStream { self.continuation = $0 }        // 접근할 때마다 새로 만들고 덮어쓴다
    }
    func emit(_ s: String) { continuation?.yield(s) }
}
```

```text
⑩ 첫 번째 구독: []
⑩ 두 번째 구독: ["joined", "offer"]
```

**첫 번째 구독자는 아무것도 받지 못한다.** `bad.events`에 접근할 때마다 새 스트림이 만들어지고 `continuation`이 마지막 것으로 덮여서, 앞서 만든 스트림은 값을 넣어 줄 주인을 잃는다. 에러도 경고도 없이 조용히 멈춘다.

저장 프로퍼티로 한 번만 만들어야 한다.

```swift
final class SignalingClient {
    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream(of: Event.self)
    }

    func emit(_ event: Event) { continuation.yield(event) }
    func close() { continuation.finish() }
}
```

```text
⑪ 단일 구독: ["joined", "offer"]
```

`signalingClient.events`가 **프로퍼티 접근처럼 생겼지만 구독 행위**라는 점이 헷갈림의 원인이다. 이름을 `events`로 두더라도 저장 프로퍼티로 만들어 두면 문제가 생기지 않는다.

### 종료와 취소

끝나는 경로는 둘이다.

```swift
continuation.finish()                 // 생산자가 끝낸다 → for await 루프 종료
signalingTask?.cancel()               // 소비자가 그만둔다 → for await 루프 종료
```

어느 쪽이든 루프가 끝나므로 `for await` 뒤의 코드로 흐른다. 어느 쪽으로 끝났는지는 `onTermination`이 알려 준다.

```swift
continuation.onTermination = { reason in print(reason) }
```

```text
⑥ onTermination: finished      ← finish() 로 끝났다
⑦ onTermination: cancelled     ← Task 가 취소됐다
⑦   루프 종료. isCancelled=true
⑦ 취소 후 yield: terminated
```

**`onTermination`이 자원 정리 지점이다.** 옵저버 해제, 소켓 닫기, 델리게이트 `nil` 처리를 여기에 둔다.

```swift
let stream = AsyncStream<Notification> { continuation in
    let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) {
        continuation.yield($0)
    }
    continuation.onTermination = { _ in
        NotificationCenter.default.removeObserver(token)   // ← 여기서 해제
    }
}
```

이것을 빼먹으면 **Task를 취소해도 옵저버가 남는다.** 콜백 브리징에서 가장 흔한 누수다.

### 구독 `Task`를 관리한다

`Task { }`를 변수에 담지 않으면 취소할 방법이 없다. 질문 코드가 그 상태다.

```swift
private var signalingTask: Task<Void, Never>?

private func observeSignaling() {
    signalingTask?.cancel()              // ← 중복 구독 방지
    signalingTask = Task { [weak self] in
        guard let self else { return }
        for await event in signalingClient.events {
            handle(event)
        }
    }
}

func endCall() {
    signalingTask?.cancel()
    signalingTask = nil
}
```

세 가지가 들어 있다.

- **`signalingTask?.cancel()`를 먼저** — 함정 ①의 이벤트 분할을 막는다
- **`[weak self]`** — Task가 살아 있는 동안 객체를 붙잡지 않는다([`[weak self]`와 `deinit`](./023-weak-self-and-deinit.md))
- **`nil` 대입** — 끝난 Task를 들고 있지 않는다

SwiftUI 뷰 안에서 소비한다면 `Task { }`를 직접 만들지 말고 `.task`를 쓴다. **뷰 생명주기에 묶여 자동으로 취소된다**([`.task` 문서](./103-task-modifier-and-async-lifecycle.md)).

```swift
.task {
    for await event in client.events { handle(event) }
}
```

### 에러가 날 수 있으면 `AsyncThrowingStream`

```swift
let (stream, c) = AsyncThrowingStream.makeStream(of: String.self)
c.yield("joined")
c.finish(throwing: SignalError.disconnected)

do {
    for try await v in stream { print(v) }
} catch {
    print("catch: \(error)")
}
```

```text
⑧   받음 joined
⑧ catch: disconnected
```

`finish(throwing:)`으로 끝내면 소비자 쪽에서 에러가 던져진다. `finish(throwing: nil)`은 정상 종료와 같다. 연결 끊김, 인증 만료처럼 **스트림 자체가 실패로 끝나는 경우**에 쓴다. 개별 이벤트가 실패일 뿐이라면 `Result`나 `case failure(Error)`를 이벤트 타입에 담는 편이 낫다.

### 무엇을 언제 쓰나

| 상황 | 도구 |
| --- | --- |
| 값이 **한 번** 오는 콜백 | `withCheckedContinuation` ([143](./143-sync-vs-async-and-suspension.md)) |
| 값이 **여러 번** 오는 콜백·델리게이트 | **`AsyncStream`** |
| 스트림이 에러로 끝날 수 있다 | `AsyncThrowingStream` |
| 소비자가 요청할 때 하나씩 생성 | `AsyncStream(unfolding:)` |
| 같은 이벤트를 **여러 곳**에서 받는다 | Combine, `@Observable` ([114](./114-combine-vs-async-await.md)) |
| UI 상태 변화 관찰 | `@Observable` ([050](./050-observation-framework-and-observable.md)) |
| 시스템 알림 | `NotificationCenter.notifications(named:)` ([109](./109-notification-center.md)) |
| 주기적 이벤트 | `Timer.publish` 또는 `Clock` ([110](./110-timer-publisher-and-onreceive.md)) |

Combine과의 대비가 핵심이다.

| | `AsyncStream` | Combine `Publisher` |
| --- | --- | --- |
| 구독자 수 | **하나** (나눠 갖는다) | 여럿 (같은 값을 받는다) |
| 취소 | `Task.cancel()` | `AnyCancellable` |
| 역압 | **없다** | `Subscriber.Demand` |
| 연산자 | `map`, `filter` 등 일부 | 풍부하다 |
| 에러 | `AsyncThrowingStream` | `Failure` 타입 |

### Swift 6에서 주의할 점

- `AsyncStream<Element>`의 `Element`는 **`Sendable`이어야** 격리 경계를 넘길 수 있다. 이벤트 타입을 값 타입으로 설계한다([액터 문서의 `Sendable` 절](./153-swift-actor-complete-guide.md)).
- `Continuation`은 `Sendable`이라 어느 문맥에서든 `yield`할 수 있다. 델리게이트 콜백이 어느 스레드에서 불리든 그대로 넣어도 된다.
- `for await` 루프가 도는 격리 도메인은 **그 `Task`를 만든 자리**가 정한다. `@MainActor`에서 만들었다면 `handle(event)`에서 UI 상태를 그냥 바꿀 수 있다.
- `onTermination` 클로저는 `@Sendable`이다. 안에서 액터 격리 상태를 건드리려면 `Task { @MainActor in }`이 필요하다.

### 정리

```text
AsyncStream = 여러 번 오는 값을 AsyncSequence 로 감싼 것

만들기
  makeStream()              ← 기본. 스트림 + continuation 튜플
  AsyncStream { c in }      ← init 클로저는 동기 즉시 실행
  AsyncStream(unfolding:)   ← pull 방식

넣고 끝내기
  yield(x)      → enqueued / dropped / terminated
  finish()      → 루프 종료, 이후 yield 는 조용히 무시
  onTermination → finished / cancelled, 자원 정리 지점

버퍼링 (역압 없음)
  .unbounded(기본) / .bufferingNewest(n) / .bufferingOldest(n)

함정
  ① 멀티캐스트가 아니다   소비자 둘 → [1,3,5] / [2,4,6] 로 나뉜다
  ② 계산 프로퍼티 금지     접근마다 새 스트림 → 첫 구독자가 조용히 죽는다
  ③ Task 를 저장하지 않으면 취소할 수 없다

CPU
  이벤트 없을 때 user 0.00s   busy loop 는 0.99s
  await 에서 중단되고 스레드를 놓아준다
```

## 학습 체크리스트

### 기본

- [ ] `makeStream()`으로 스트림을 만들고 `yield` → `for await` → `finish`를 한 번 돌린다.
- [ ] 클로저 이니셜라이저에 `print`를 넣어 **초기화 시점에 즉시 실행**되는 것을 확인한다.
- [ ] 소비자를 만들기 전에 `yield`한 값이 나중에 전부 도착하는 것을 확인한다.
- [ ] `AsyncStream(unfolding:)`으로 1~3을 내보내고 `nil` 반환이 종료가 되는 것을 확인한다.

### 측정과 관찰

- [ ] 이벤트 없이 `for await`로 1초 대기하는 프로그램의 `user` CPU 시간을 `/usr/bin/time`으로 재고 busy loop와 비교한다.
- [ ] `yield`의 반환값을 출력해 `enqueued` / `dropped` / `terminated`를 모두 관찰한다.
- [ ] `.bufferingNewest(2)`와 `.bufferingOldest(2)`에 1, 2, 3을 넣어 어느 값이 버려지는지 확인한다.
- [ ] `finish()` 뒤에 `yield`를 호출해 **아무 일도 일어나지 않는 것**을 확인한다.

### 함정

- [ ] 같은 스트림을 두 `Task`에서 `for await`로 순회해 이벤트가 나뉘는 것을 확인한다.
- [ ] `events`를 계산 프로퍼티로 만든 클래스에 두 번 구독해 첫 구독자가 아무것도 못 받는 것을 재현한다.
- [ ] 같은 코드를 저장 프로퍼티로 고쳐 문제가 사라지는 것을 확인한다.
- [ ] 구독 `Task`를 변수에 담지 않은 상태에서 취소할 방법이 없음을 확인한다.

### 종료와 정리

- [ ] `onTermination`을 붙이고 `finish()`와 `Task.cancel()`에서 각각 `finished` / `cancelled`가 나오는 것을 확인한다.
- [ ] `NotificationCenter` 옵저버를 `AsyncStream`으로 감싸고, `onTermination`에서 해제하지 않으면 옵저버가 남는 것을 확인한다.
- [ ] `AsyncThrowingStream`을 `finish(throwing:)`으로 끝내고 소비자의 `catch`로 들어오는 것을 확인한다.
- [ ] 질문 코드를 `signalingTask` 저장 + `cancel()` 형태로 고쳐 본다.
- [ ] SwiftUI 뷰에서 같은 구독을 `.task`로 바꿔 뷰가 사라질 때 자동 취소되는 것을 확인한다.

### 설계 판단

- [ ] 같은 이벤트를 두 곳에서 받아야 하는 요구를 `AsyncStream`으로 풀 때와 `@Observable`로 풀 때를 비교한다.
- [ ] 이벤트 타입을 `Sendable`이 아닌 class로 만들어 어떤 컴파일 에러가 나는지 읽는다.
- [ ] 역압이 필요한 상황을 하나 들고, `AsyncStream`으로는 왜 안 되는지 설명한다.

## 공식 참고 자료

### Swift Evolution

- [SE-0314: AsyncStream and AsyncThrowingStream](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0314-async-stream.md)
- [SE-0388: Convenience Async[Throwing]Stream.makeStream methods](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0388-async-stream-factory.md)

### Apple 공식 문서

- [Apple: AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [Apple: AsyncStream.Continuation](https://developer.apple.com/documentation/swift/asyncstream/continuation)
- [Apple: AsyncThrowingStream](https://developer.apple.com/documentation/swift/asyncthrowingstream)
- [Apple: AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence)
- [Apple: Task](https://developer.apple.com/documentation/swift/task)
- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)

### Swift 공식 문서

- [Swift Book: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

### 영상

- [WWDC21: Meet AsyncSequence](https://developer.apple.com/videos/play/wwdc2021/10058/)
