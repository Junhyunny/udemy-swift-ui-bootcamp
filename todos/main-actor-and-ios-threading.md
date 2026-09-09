# `MainActor`는 왜 필요한가 — iOS의 스레드 모델

`async/await` 실행 모델은 [별도 문서](./swift-async-await-model.md)에, Swift의 메모리 구조는 [여기](./swift-memory-model.md)에 정리했다. 이 문서는 **메인 스레드와 액터 격리**를 다룬다.

## 질문이 나온 코드

`chapter-65/chapter-65/ContentView.swift`

```swift
for await notification in center.notifications(named: name) {
    if let userInfo = notification.userInfo,
       let moreInfo = userInfo["Course"] as? DTCourse {
        await MainActor.run {
            additionalInfo = "\(moreInfo.name) by: \(moreInfo.author)"
        }
    }
    await MainActor.run {
        counter += 1
    }
}
```

```swift
@MainActor
func orientationChangeNotification() async { ... }
```

## 1부 — iOS의 스레드 모델

### 대전제: UI는 메인 스레드에서만

iOS에서 지켜야 할 규칙은 단순하다. **UIKit·SwiftUI의 UI 갱신은 반드시 메인 스레드에서 일어나야 한다.**

이유는 **UI 프레임워크가 스레드 안전하지 않기 때문**이다. 여러 스레드가 동시에 뷰 계층을 건드리면 내부 상태가 깨진다. 화면이 깜빡이거나, 레이아웃이 어긋나거나, 크래시가 난다.

**메인 스레드가 하는 일**은 이렇다.

```text
메인 런루프 (초당 60~120회)
  ├─ 터치·제스처 입력 처리
  ├─ 상태 변경 반영
  ├─ 레이아웃 계산
  ├─ 화면 그리기
  └─ 다음 프레임 준비
```

그래서 메인 스레드에서 무거운 작업을 하면 **화면이 멈춘다.** 네트워크 요청이나 파일 IO를 백그라운드로 보내는 이유다.

**정리하면 두 방향의 규칙이 있다.**

| | 어디서 |
| --- | --- |
| UI 갱신 | **반드시 메인 스레드** |
| 네트워크, 파일 IO, 무거운 계산 | **백그라운드** |

### 전통적인 방식 — GCD

Swift 동시성 이전에는 `DispatchQueue`로 직접 관리했다.

```swift
DispatchQueue.global(qos: .background).async {
    let data = heavyWork()                  // 백그라운드
    DispatchQueue.main.async {
        self.label.text = data              // 메인으로 복귀
    }
}
```

**문제는 컴파일러가 검증해 주지 않는다는 것**이다. `DispatchQueue.main.async`를 빠뜨려도 컴파일은 통과하고, 런타임에 간헐적으로 문제가 생긴다. 재현이 어려운 버그의 단골 원인이었다.

### Swift 동시성 — 액터로 규칙을 타입 시스템에 넣다

Swift 5.5부터 **액터(actor)** 개념이 도입됐다. 액터는 **자기 상태를 한 번에 하나의 작업만 건드리도록 보장하는 타입**이다.

`MainActor`는 그중 특별한 것이다.

```swift
@globalActor final actor MainActor
```

**메인 스레드를 대표하는 전역 액터**다. `@MainActor`가 붙은 코드는 메인 스레드에서 실행되는 것이 **컴파일 타임에 보장된다.**

```text
GCD 시대     "메인에서 해야 한다"를 개발자가 기억
Swift 동시성  "메인에서 해야 한다"를 타입 시스템이 강제
```

## 2부 — 이 코드에서 `MainActor`가 필요한 이유

### 질문 확인: 직접 바꾸면 안 되는가

**안 된다. 그리고 컴파일러가 막아 준다.**

```swift
Task(priority: .background) {
    await receiveNotifications()      // 백그라운드에서 실행
}
```

```swift
private func receiveNotifications() async {     // @MainActor가 없다
    for await notification in ... {
        counter += 1                             // ⚠️ 여기가 문제
    }
}
```

`receiveNotifications()`는 `@MainActor`가 붙어 있지 않으므로 **어느 스레드에서 실행될지 보장되지 않는다.** `Task(priority: .background)`로 시작했으니 백그라운드일 가능성이 높다.

그런데 `counter`는 `@State` 프로퍼티다.

```swift
struct ReceiverView: View {
    @State private var counter = 0
}
```

**SwiftUI의 `View`와 `@State`는 `@MainActor`에 격리되어 있다.** 백그라운드에서 건드리면 안 된다.

`await MainActor.run { }`이 그 경계를 넘는 수단이다.

```swift
static func run<T>(resultType: T.Type = T.self, body: @MainActor @Sendable () throws -> T) async rethrows -> T where T : Sendable
```

파라미터 `body`에 **`@MainActor`가 붙어 있다.** 이 클로저 안의 코드는 메인 액터에서 실행된다.

### 직접 바꾸면 무슨 일이 생기나

**Swift 6 언어 모드에서는 컴파일 에러다.**

```
error: main actor-isolated property 'counter' can not be mutated from a nonisolated context
```

Swift 5 모드에서는 **경고**로 나오거나, 설정에 따라 통과할 수도 있다. 통과했을 때 생기는 문제는 이렇다.

- **데이터 경쟁(data race)** — 여러 스레드가 같은 메모리를 동시에 읽고 쓴다
- **UI 갱신이 누락되거나 지연된다** — SwiftUI가 변경을 감지하지 못할 수 있다
- **런타임 경고** — Xcode의 Main Thread Checker가 보라색 경고를 띄운다
- **간헐적 크래시** — 재현이 어렵다

**데이터 경쟁은 정의되지 않은 동작(undefined behavior)** 이다. "대부분 잘 동작하다가 가끔 깨지는" 최악의 버그 유형이다. Swift 동시성이 이것을 컴파일 타임에 잡으려는 이유다.

### 세 가지 방법 비교

이 코드는 `MainActor.run`을 두 번 호출한다. 더 나은 방법이 있다.

**① `await MainActor.run { }` — 현재 방식**

```swift
await MainActor.run {
    counter += 1
}
```

**부분적으로만 메인 액터로 넘어간다.** 매번 컨텍스트 전환 비용이 들고, 코드가 장황해진다. 이 예제는 루프 안에서 **두 번** 호출하므로 전환도 두 번이다.

**② `@MainActor` 함수 — 더 깔끔하다**

같은 파일의 다른 코드가 이 방식을 쓴다.

```swift
@MainActor
func orientationChangeNotification() async {
    for await notification in center.notifications(named: name) {
        if let device = notification.object as? UIDevice {
            orientation = .portrait        // MainActor.run이 필요 없다
        }
    }
}
```

**함수 전체가 메인 액터에 격리**되므로 안에서 상태를 직접 바꿀 수 있다. 훨씬 읽기 쉽다.

`receiveNotifications()`도 같은 방식으로 바꿀 수 있다.

```swift
@MainActor
private func receiveNotifications() async {
    for await notification in center.notifications(named: name) {
        if let moreInfo = notification.userInfo?["Course"] as? DTCourse {
            additionalInfo = "\(moreInfo.name) by: \(moreInfo.author)"
        }
        counter += 1
    }
}
```

`MainActor.run` 두 개가 사라진다.

**"메인 액터에서 도는데 UI가 멈추지 않나?"** 걱정할 수 있지만 아니다. `for await`은 값을 기다리는 동안 **실행을 중단하고 스레드를 놓아준다**([for await 문서](./for-await-async-sequence.md) 참조). 메인 스레드를 붙잡고 있지 않다.

**③ `.task` + `onReceive` — SwiftUI다운 방식**

애초에 `Task(priority: .background)`가 불필요하다.

```swift
.task {
    await receiveNotifications()    // 뷰 생명주기에 묶이고 자동 취소
}
```

또는 알림 수신 자체를 SwiftUI에 맡긴다.

```swift
.onReceive(NotificationCenter.default.publisher(for: .dtAlert)) { notification in
    if let course = notification.userInfo?["Course"] as? DTCourse {
        additionalInfo = "\(course.name) by: \(course.author)"
    }
    counter += 1
}
```

**`onReceive`는 메인 스레드를 보장하므로 `MainActor` 관련 코드가 전부 사라진다.** [NotificationCenter 문서](./notification-center.md)에서 다룬 방식이다.

### `priority: .background`가 적절한가

```swift
Task(priority: .background) {
    await receiveNotifications()
}
```

**의도는 이해되지만 실효가 없다.** 결국 `MainActor.run`으로 메인에 넘기므로 백그라운드에서 하는 일이 없다. 알림을 기다리는 것은 CPU를 쓰지 않는 대기이므로 우선순위가 의미를 갖지 않는다.

우선순위 자체에 대해서는 [TaskPriority 문서](./task-priority-and-scheduling.md)에서 다룬다.

### `Task { @MainActor in }` — `chapter-88`의 네 번째 방법

`chapter-88/chapter-88/Services/NetworkManager.swift`에 또 다른 문법이 나온다.

```swift
let (data, _) = try await URLSession.shared.data(from: url)
let decoder = JSONDecoder()

// TODO, 이건 새로운 문법이네? 이건 이전의 MainActor.run , Task 방식과 뭐가 달라?
Task { @MainActor in
    let results = try decoder.decode(Results.self, from: data)
    posts = results.hits
}
```

**`Task`의 클로저에 `@MainActor`를 붙인 형태**다. "이 작업 전체를 메인 액터에서 실행하라"는 뜻이다.

### 세 방법을 나란히 놓고 비교

| | `await MainActor.run { }` | `Task { @MainActor in }` | `@MainActor func` |
| --- | --- | --- | --- |
| 정체 | 메인 액터로 **전환하고 기다린다** | 메인 액터에서 도는 **새 작업 생성** | 함수 전체를 격리 |
| 호출부에서 대기 | **예** (`await`) | **아니오** — 바로 다음 줄로 넘어간다 |  예 |
| 반환값 | 받을 수 있다 | 받기 어렵다 | 받을 수 있다 |
| 취소 연결 | 현재 작업에 붙는다 | **비구조적 — 끊어진다** | 붙는다 |
| 오류 전파 | `try await`으로 전파 | **전파되지 않는다** | 전파된다 |

**`Task { @MainActor in }`의 결정적 차이는 "기다리지 않는다"는 것**이다.

```swift
func fetchPosts() async {
    let (data, _) = try await URLSession.shared.data(from: url)

    Task { @MainActor in
        posts = try decoder.decode(Results.self, from: data)   // 나중에 실행된다
    }
    // ← 여기로 즉시 넘어온다. 위 작업이 끝나기를 기다리지 않는다
}                                                              // 함수가 먼저 끝날 수 있다
```

`MainActor.run`은 반대다.

```swift
await MainActor.run {
    posts = ...
}
// ← 위 블록이 끝난 뒤에 도달한다
```

### 이 코드에는 실제 문제가 있다

**① 오류가 사라진다**

```swift
Task { @MainActor in
    let results = try decoder.decode(Results.self, from: data)   // ← try
    posts = results.hits
}
```

**이 `try`의 오류를 아무도 받지 않는다.**

`Task`의 클로저가 throwing이면 `Task<Void, Error>`가 만들어지고, 오류는 그 `Task`의 `value`나 `result`를 통해서만 꺼낼 수 있다. 여기서는 `Task`를 변수에 담지도 않으므로 **오류가 조용히 버려진다.**

바깥의 `catch`도 잡지 못한다.

```swift
do {
    let (data, _) = try await URLSession.shared.data(from: url)
    Task { @MainActor in
        try decoder.decode(...)      // 이 오류는
    }
} catch {
    print(error)                     // ← 여기로 오지 않는다
}
```

`Task`가 **별개의 작업**이므로 오류 흐름이 끊긴다. 앞서 겪은 `"The data couldn't be read because it is missing."` 메시지가 보였다면, 그건 이전 버전(`Task` 안에 `do-catch`가 있던 코드)에서 나온 것이다. 현재 코드는 같은 오류가 나도 **아무것도 출력되지 않는다.**

**② 취소가 연결되지 않는다**

`.task { await networkManager.fetchPosts() }`로 호출하므로 뷰가 사라지면 `fetchPosts`는 취소된다. 하지만 **안에서 만든 `Task`는 별개**라 계속 실행된다. [`.task` 문서](./task-modifier-and-async-lifecycle.md)에서 다룬 구조적 동시성의 이점이 여기서 끊긴다.

**③ 디코딩을 메인 액터에서 한다**

`decode`는 CPU 작업이다. 항목이 많으면 메인 스레드를 점유해 UI가 멈출 수 있다. **디코딩은 백그라운드에서 하고 대입만 메인에서** 하는 것이 맞다.

### 권장하는 형태

**`@MainActor` 함수로 만드는 것이 가장 단순하다.**

```swift
@Observable
final class NetworkManager {
    var posts = [Post]()

    @MainActor
    func fetchPosts() async throws {
        guard let url = URL(string: "https://hn.algolia.com/api/v1/search?tags=story") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let results = try JSONDecoder().decode(Results.self, from: data)
        posts = results.hits
    }
}
```

`Task`, `MainActor.run`이 모두 사라진다. **`await` 지점에서 스레드를 놓아주므로 UI를 막지 않는다.**

`throws`로 바꿨으므로 뷰에서 오류를 처리한다.

```swift
.task {
    do {
        try await networkManager.fetchPosts()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**디코딩을 백그라운드로 분리하려면** 클래스 전체를 격리하지 않고 대입 지점만 넘긴다.

```swift
func fetchPosts() async throws {
    let (data, _) = try await URLSession.shared.data(from: url)
    let results = try JSONDecoder().decode(Results.self, from: data)   // 백그라운드

    await MainActor.run {
        posts = results.hits                                            // 메인
    }
}
```

`MainActor.run`을 쓰되 **오류가 나는 코드는 밖에 두는 것**이 요령이다. `try`가 `MainActor.run` 안에 있으면 오류 전파가 복잡해진다.

### 언제 `Task { @MainActor in }`이 적절한가

**"결과를 기다릴 필요가 없는 UI 갱신"** 에는 유효하다.

```swift
// 동기 함수에서 UI를 갱신해야 할 때
func handleNotification(_ note: Notification) {      // 동기 콜백
    Task { @MainActor in
        self.badgeCount += 1                          // await할 필요 없다
    }
}
```

동기 문맥에서는 `await MainActor.run`을 쓸 수 없으므로 이 방법이 필요하다. [`Task { }`가 동기·비동기 경계를 넘는 다리](./task-modifier-and-async-lifecycle.md)라는 점과 같은 맥락이다.

**하지만 이미 `async` 함수 안이라면** `MainActor.run`이나 `@MainActor` 함수가 낫다. 굳이 새 작업을 만들 이유가 없고, 오류·취소 연결도 유지된다.

### `@MainActor`를 붙이는 위치

| 위치 | 효과 |
| --- | --- |
| `@MainActor func` | 그 함수만 |
| `@MainActor class` / `struct` | **모든 멤버가** 메인 액터에 격리 |
| `@MainActor var` | 그 프로퍼티만 |
| 클로저 파라미터 | 그 클로저 |

**SwiftUI의 `View`는 이미 `@MainActor`다.** `body`와 `@State`가 자동으로 메인에 격리되므로, 뷰 안의 일반 코드에서는 신경 쓸 필요가 없다. 문제는 **`Task`나 `async` 함수로 격리를 벗어났다가 돌아올 때** 생긴다.

이 파일의 `SystemNotificationExample`도 같은 상황이다.

```swift
@Observable
final class SystemNotificationExample {
    var orientation: DTOrientation = .portrait

    init() {
        Task(priority: .background) {
            await orientationChangeNotification()    // @MainActor 함수
        }
    }
}
```

클래스 자체에는 `@MainActor`가 없고 메서드에만 붙어 있다. 클래스 전체에 붙이는 편이 더 안전하다.

```swift
@MainActor
@Observable
final class SystemNotificationExample { ... }
```

### `Sendable`과 `@unchecked Sendable`

이 파일 마지막 줄이 눈에 띈다.

```swift
extension NotificationCenter: @unchecked Sendable {}
```

**`Sendable`은 "액터 경계를 안전하게 넘을 수 있는 타입"을 나타내는 프로토콜**이다. 값 타입이거나 내부적으로 동기화가 보장되어야 한다.

`@unchecked`는 **"컴파일러 검증을 끄고 내가 책임진다"** 는 선언이다. 컴파일 경고를 없애는 가장 빠른 방법이지만, **안전 보장도 함께 사라진다.**

`NotificationCenter`는 실제로 스레드 안전하게 구현되어 있어 이 선언이 사실과 다르지는 않다. 하지만 **최신 SDK에서는 이미 `Sendable`로 표시되어 있을 가능성이 높아** 이 extension 자체가 불필요할 수 있다. 경고가 나온다면 지워 보고 확인하는 편이 낫다.

**일반론으로는 `@unchecked Sendable`을 남발하면 안 된다.** 컴파일러가 잡아 주려던 문제를 눈감는 것이므로, 정말 안전한지 근거가 있을 때만 쓴다.

### 정리

```text
iOS 스레드 규칙
  UI 갱신 → 반드시 메인 스레드
  무거운 작업 → 백그라운드
  이유: UI 프레임워크가 스레드 안전하지 않다

GCD 시대       개발자가 기억해야 했다 (DispatchQueue.main.async)
Swift 동시성    타입 시스템이 강제한다 (@MainActor)

이 코드에서 MainActor.run이 필요한 이유
  Task(priority: .background)로 백그라운드에서 실행
  counter는 @State → View는 @MainActor 격리
  직접 바꾸면 데이터 경쟁 (Swift 6에서는 컴파일 에러)

더 나은 방법
  ① @MainActor func       — 함수 전체 격리, MainActor.run 불필요
  ② .task                 — 뷰 생명주기에 묶임
  ③ onReceive             — 메인 보장, 가장 간단
```

## 학습 체크리스트

- [ ] `MainActor.run`을 지우고 직접 `counter += 1`을 해서 어떤 경고·에러가 나는지 본다.
- [ ] Swift 언어 모드를 6으로 올리고 같은 코드가 컴파일 에러가 되는지 확인한다.
- [ ] `receiveNotifications()`에 `@MainActor`를 붙이고 `MainActor.run`을 모두 제거해 본다.
- [ ] 그 상태에서 UI가 멈추지 않는 것을 확인한다 (`for await`이 스레드를 놓아준다).
- [ ] `Thread.isMainThread`를 출력해 각 지점의 스레드를 확인한다.
- [ ] `onAppear` + `Task`를 `.task`로 바꿔 본다.
- [ ] `onReceive` 방식으로 바꿔 `MainActor` 코드가 모두 사라지는 것을 확인한다.
- [ ] Xcode의 Main Thread Checker를 켜고 백그라운드 UI 갱신 시 경고를 확인한다.
- [ ] `SystemNotificationExample` 클래스 전체에 `@MainActor`를 붙여 본다.
- [ ] `extension NotificationCenter: @unchecked Sendable {}`을 지우고 경고가 나는지 확인한다.
- [ ] `Task(priority: .background)`를 `Task { }`로 바꿔 차이가 있는지 관찰한다.
- [ ] `DispatchQueue.main.async`로 같은 코드를 작성하고 `MainActor.run`과 비교한다.
- [ ] 백그라운드에서 무거운 계산을 하고 메인으로 결과만 넘기는 코드를 작성한다.

## 공식 참고 자료

- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Apple: MainActor.run(resultType:body:)](https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:))
- [Apple: MainActor.assumeIsolated(_:file:line:)](https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:))
- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)
- [Apple: Actor](https://developer.apple.com/documentation/swift/actor)
- [Apple: GlobalActor](https://developer.apple.com/documentation/swift/globalactor)
- [Swift 공식 문서: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift 공식 문서: Concurrency — Actors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)
- [Swift 공식 문서: Concurrency — Sendable Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types)
- [Swift 공식 문서: Memory Safety](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/memorysafety/)
- [Swift 공식 문서: Attributes — MainActor](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/)
- [Apple: Dispatch](https://developer.apple.com/documentation/dispatch)
- [Apple: DispatchQueue.main](https://developer.apple.com/documentation/dispatch/dispatchqueue/main)
- [Apple: Updating an app to use strict concurrency](https://developer.apple.com/documentation/swift/updating-an-app-to-use-strict-concurrency)
