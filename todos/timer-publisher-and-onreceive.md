# `Timer.publish` + `onReceive` — 주기적 이벤트와 외부 이벤트 받기

Combine 전반은 [별도 문서](./combine.md)에, 연산자는 [여기](./combine-operators.md)에 정리했다. 이 문서는 **`onReceive`와 실무 활용**을 다룬다.

## 질문이 나온 코드

`chapter-94/chapter-94/HomeView.swift`

```swift
.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
    timerProgress(geo)
}
```

## 공부할 내용

### 짐작이 정확하다

> 1초마다 트리거를 만드는 이벤트 publisher를 설정하는건가? onReceive 함수에? 그러면 그 이벤트를 받을 때마다 클로져가 트리거되는건가?

**세 가지 모두 맞다.** 흐름을 정리하면 이렇다.

```text
Timer.publish(every: 1, ...)   1초마다 현재 시각을 내보내는 publisher를 만든다
        ↓ .autoconnect()
                                구독자가 붙으면 자동으로 타이머를 시작한다
        ↓ .onReceive(...)
                                뷰가 그 publisher를 구독한다
        ↓
1초마다 클로저 실행 → timerProgress(geo) 호출
```

### `Timer.publish` — 각 파라미터

```swift
static func publish(
    every interval: TimeInterval,
    tolerance: TimeInterval? = nil,
    on runLoop: RunLoop,
    in mode: RunLoop.Mode,
    options: RunLoop.SchedulerOptions? = nil
) -> Timer.TimerPublisher
```

> A publisher that repeatedly emits the current date on the given interval.

**내보내는 값은 `Date`** 다. 예제가 `{ _ in }`으로 무시하는 것도 시각이 필요 없기 때문이다. 필요하면 받아 쓸 수 있다.

```swift
.onReceive(timer) { now in
    print("현재:", now)
}
```

| 파라미터 | 의미 |
| --- | --- |
| `every` | 발동 간격(초). 예제는 `1` |
| `tolerance` | 허용 오차. 시스템이 배터리 절약을 위해 이 범위에서 조정 |
| `on` | 어느 **런루프**에서 돌릴지. 예제는 `.main` |
| `in` | 런루프 **모드**. 예제는 `.common` |
| `options` | 스케줄러 옵션 (거의 안 씀) |

**`on: .main`은 메인 런루프에서 발동한다는 뜻**이다. UI를 갱신하므로 메인이 맞다. [MainActor 문서](./main-actor-and-ios-threading.md)에서 다룬 규칙과 이어진다.

**`in: .common`이 중요하다.** 런루프 모드는 "지금 무슨 일을 하는 중인가"를 나타낸다.

| 모드 | 의미 |
| --- | --- |
| `.default` | 평상시 |
| `.tracking` | 스크롤·드래그 중 |
| **`.common`** | **여러 모드를 포함하는 집합** |

`.default`만 지정하면 **사용자가 스크롤하는 동안 타이머가 멈춘다.** `.common`은 tracking 모드까지 포함하므로 스크롤 중에도 계속 발동한다. 타이머 앱에서는 `.common`이 필수다.

### `autoconnect()` — 왜 필요한가

`Timer.publish`가 돌려주는 것은 **바로 발행하지 않는 publisher**다.

> The return type, `Timer.TimerPublisher`, conforms to `ConnectablePublisher`, which means **you must explicitly connect to the publisher to begin publishing events**. You can do this with a call to `connect()`, or by using `autoconnect()` to automatically connect when a subscriber attaches.

**`ConnectablePublisher`는 "연결하라고 말해야 시작하는" publisher**다. 구독자가 붙어도 값을 내보내지 않는다.

```swift
// autoconnect 없이 — 아무 일도 일어나지 않는다
Timer.publish(every: 1, on: .main, in: .common)
    .sink { print($0) }        // ⚠️ 타이머가 시작되지 않는다

// 직접 연결
let timer = Timer.publish(every: 1, on: .main, in: .common)
let cancellable = timer.sink { print($0) }
timer.connect()               // ← 여기서 시작

// autoconnect — 구독자가 붙으면 자동 연결
Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .sink { print($0) }        // ✅ 바로 시작
```

> For convenience when working with a single subscriber, the `autoconnect()` operator performs the `connect()` call when attached to by the subscriber.

**구독자가 하나뿐일 때 쓰는 편의 연산자**다. 여러 구독자에게 같은 스트림을 공유해야 하면 `connect()`를 직접 관리한다.

**왜 이런 구분이 있나**는 타이머의 성질에서 나온다. 구독자가 붙기 전에 타이머가 돌기 시작하면 이벤트가 버려진다. `ConnectablePublisher`는 "준비될 때까지 기다린다"를 표현하는 장치다.

### `onReceive` — publisher를 뷰에 연결한다

```swift
nonisolated func onReceive<P>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View
    where P : Publisher, P.Failure == Never
```

**publisher가 값을 내보낼 때마다 클로저를 실행한다.** SwiftUI가 제공하는 Combine 연결점이다.

**`P.Failure == Never` 제약**에 주목할 만하다. **실패할 수 있는 publisher는 받지 않는다.** 오류를 처리할 방법이 없으므로 [`replaceError`나 `catch`](./combine-operators.md)로 미리 없애야 한다.

```swift
somePublisher
    .replaceError(with: fallback)      // Failure를 Never로
    .eraseToAnyPublisher()
// 이제 onReceive에 넘길 수 있다
```

**`onReceive`가 해 주는 것**

| | `onReceive` | `sink` + `store` |
| --- | --- | --- |
| 구독 시작 | 뷰가 나타날 때 | 직접 호출 |
| 구독 해제 | **뷰가 사라질 때 자동** | `AnyCancellable` 관리 필요 |
| 실행 스레드 | **메인 보장** | `receive(on:)` 필요 |
| `AnyCancellable` | 불필요 | 필요 |

[구독 수명 관리](./combine-cancellable-and-store.md)에서 다룬 번거로움이 사라진다. **뷰 안에서 publisher를 쓸 때는 `onReceive`가 기본 선택지다.**

### 이 코드에서 벌어지는 일

```swift
.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
    timerProgress(geo)
}
```

```swift
private func timerProgress(_ geo: GeometryProxy) {
    if viewModel.time > 0 && viewModel.selectedTime > 0 && viewModel.buttonAnimation {
        viewModel.selectedTime -= 1                    // 1초 감소
        let progressHeight = geo.size.height / CGFloat(viewModel.time)
        let diff = viewModel.time - viewModel.selectedTime
        withAnimation {
            viewModel.timerHeightChange = CGFloat(diff) * progressHeight
        }
        if viewModel.selectedTime == 0 {
            viewModel.resetView()
        }
    }
}
```

**1초마다 남은 시간을 1 줄이고, 진행률에 맞춰 화면 높이를 애니메이션한다.**

**주의할 점이 하나 있다.** 타이머는 **조건과 무관하게 항상 발동**한다. `if` 문이 안에서 걸러 주지만, 타이머 자체는 앱이 열려 있는 동안 계속 돈다.

```swift
// 타이머가 필요할 때만 돌게 하려면
@State private var timerCancellable: AnyCancellable?
```

또는 조건부로 publisher를 바꾸는 방법도 있다. 다만 1초 간격이므로 실질적 부담은 크지 않다.

**더 나은 대안**도 있다. iOS 17+에서는 `TimelineView`가 같은 일을 더 효율적으로 한다.

```swift
TimelineView(.periodic(from: .now, by: 1)) { context in
    Text(viewModel.formatTime(seconds: viewModel.selectedTime))
}
```

**`.task`로 async 루프를 쓰는 방법**도 있다.

```swift
.task {
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        timerProgress(geo)
    }
}
```

[`.task`](./task-modifier-and-async-lifecycle.md)가 뷰 생명주기에 묶이므로 취소가 자동이다. Combine 의존이 사라지는 것도 이점이다.

## 실무에서 자주 쓰는 `onReceive` 사례

질문의 "타이머 말고 현업에서 자주 쓰이는 예시"에 답한다.

### ① 시스템 알림 수신 — 가장 흔하다

[`NotificationCenter`](./notification-center.md)의 이벤트를 받는다.

```swift
// 키보드가 올라올 때 레이아웃 조정
.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
    if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
        keyboardHeight = frame.height
    }
}
.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
    keyboardHeight = 0
}
```

**`onReceive`가 가장 많이 쓰이는 용도다.** SwiftUI에 대응 API가 없는 시스템 이벤트를 받을 때 사실상 유일한 방법이다.

```swift
// 스크린샷 감지
.onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
    logScreenshot()
}

// 앱이 백그라운드로
.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
    saveDraft()
}
```

`scenePhase`로도 앱 상태를 알 수 있지만, 더 세밀한 시점이 필요할 때는 알림이 정확하다.

### ② 검색어 디바운스

Combine의 강점이 드러나는 사례다.

```swift
@State private var searchText = ""
@State private var searchPublisher = PassthroughSubject<String, Never>()

TextField("검색", text: $searchText)
    .onChange(of: searchText) { _, new in
        searchPublisher.send(new)
    }
    .onReceive(
        searchPublisher
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .removeDuplicates()
    ) { query in
        Task { await search(query) }
    }
```

타이핑할 때마다 요청하는 대신 **400ms 동안 입력이 멈추면 한 번만** 요청한다. `onChange`만으로는 구현하기 번거로운 부분이다. [Combine과 async/await 비교](./combine-vs-async-await.md)에서 다룬 Combine의 강점이다.

### ③ 외부 데이터 스트림

```swift
// 위치 업데이트
.onReceive(locationManager.locationPublisher) { location in
    updateMap(to: location)
}

// 블루투스 기기 상태
.onReceive(bleManager.connectionPublisher) { state in
    isConnected = (state == .connected)
}

// WebSocket 메시지
.onReceive(socketClient.messagePublisher) { message in
    messages.append(message)
}
```

**서비스 계층이 publisher를 노출하고 뷰가 구독하는 구조**다. 뷰모델을 거치지 않아도 되는 단순한 경우에 적합하다.

### ④ 네트워크 연결 상태

```swift
.onReceive(networkMonitor.isConnectedPublisher) { connected in
    showOfflineBanner = !connected
}
```

### ⑤ 여러 상태를 합쳐 판단

```swift
.onReceive(
    Publishers.CombineLatest($username, $password)
        .map { !$0.isEmpty && $1.count >= 8 }
) { isValid in
    canSubmit = isValid
}
```

두 입력이 모두 조건을 만족할 때만 버튼을 활성화한다. **여러 스트림을 합치는 것이 Combine의 진짜 강점**이다.

### ⑥ 주기적 폴링

```swift
.onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
    Task { await refreshStatus() }
}
```

30초마다 서버 상태를 확인한다. 이 예제의 타이머와 같은 형태다.

### `onReceive`를 쓰지 말아야 할 때

**SwiftUI에 전용 API가 있으면 그것을 쓴다.**

| 목적 | `onReceive` 대신 |
| --- | --- |
| 앱 상태 변화 | [`@Environment(\.scenePhase)`](./environment-property-wrapper.md) |
| 값 변화 감지 | [`onChange(of:)`](./onchange-old-new-value.md) |
| 비동기 작업 | [`.task`](./task-modifier-and-async-lifecycle.md) |
| 주기적 화면 갱신 | `TimelineView` |
| `@Observable` 객체 관찰 | 그냥 프로퍼티를 읽으면 된다 |

**`@Observable`을 쓰면 `onReceive`가 필요 없어지는 경우가 많다.** [Observation 문서](./observation-framework-and-observable.md)에서 다룬 대로 프로퍼티를 읽는 것만으로 의존성이 등록된다.

### 정리

```text
Timer.publish(every: 1, on: .main, in: .common)
  1초마다 Date를 내보내는 publisher를 만든다
  on: .main    메인 런루프에서 발동
  in: .common  스크롤 중에도 멈추지 않는다 (.default면 멈춘다)

.autoconnect()
  Timer.publish는 ConnectablePublisher — 연결해야 시작한다
  구독자가 붙으면 자동으로 connect()를 호출해 준다

.onReceive(publisher) { }
  publisher가 값을 내보낼 때마다 클로저 실행  ✅ 짐작이 맞다
  뷰 생명주기에 묶여 자동 해제
  Failure == Never 제약 — 실패 가능한 publisher는 못 받는다

실무 사례
  ① 시스템 알림 (키보드, 앱 상태, 스크린샷)  ← 가장 흔하다
  ② 검색어 디바운스
  ③ 위치·BLE·WebSocket 스트림
  ④ 네트워크 연결 상태
  ⑤ 여러 상태 합성 (CombineLatest)
  ⑥ 주기적 폴링

전용 API가 있으면 그것을 먼저: scenePhase, onChange, .task, TimelineView
```

## 학습 체크리스트

- [ ] `.autoconnect()`를 지우고 타이머가 동작하지 않는 것을 확인한다.
- [ ] `in: .common`을 `.default`로 바꾸고 스크롤 중 타이머가 멈추는지 확인한다.
- [ ] `{ _ in }`을 `{ now in print(now) }`로 바꿔 `Date`가 오는 것을 확인한다.
- [ ] `every: 0.1`로 바꿔 발동 빈도가 늘어나는지 관찰한다.
- [ ] 타이머를 시작하지 않은 상태에서도 클로저가 매초 호출되는지 `print`로 확인한다.
- [ ] `Failure`가 `Never`가 아닌 publisher를 `onReceive`에 넘겨 컴파일 에러를 본다.
- [ ] 키보드 알림을 `onReceive`로 받아 높이를 출력해 본다.
- [ ] `NotificationCenter.default.publisher(for:)`로 앱 백그라운드 진입을 감지한다.
- [ ] `debounce`를 붙인 검색 publisher를 만들어 본다.
- [ ] `Publishers.CombineLatest`로 두 입력을 합쳐 유효성을 판단한다.
- [ ] 같은 타이머를 `.task` + `Task.sleep`으로 구현하고 비교한다.
- [ ] `TimelineView(.periodic(from: .now, by: 1))`로 바꿔 본다.
- [ ] `connect()`를 직접 호출하는 형태로 바꿔 `autoconnect`의 역할을 확인한다.

## 공식 참고 자료

- [Apple: Timer.publish(every:tolerance:on:in:options:)](https://developer.apple.com/documentation/foundation/timer/publish(every:tolerance:on:in:options:))
- [Apple: Timer.TimerPublisher](https://developer.apple.com/documentation/foundation/timer/timerpublisher)
- [Apple: ConnectablePublisher](https://developer.apple.com/documentation/combine/connectablepublisher)
- [Apple: ConnectablePublisher.autoconnect()](https://developer.apple.com/documentation/combine/connectablepublisher/autoconnect())
- [Apple: Publishers.Autoconnect](https://developer.apple.com/documentation/combine/publishers/autoconnect)
- [Apple: view.onReceive(_:perform:)](https://developer.apple.com/documentation/swiftui/view/onreceive(_:perform:))
- [Apple: RunLoop.Mode](https://developer.apple.com/documentation/foundation/runloop/mode)
- [Apple: NotificationCenter.publisher(for:object:)](https://developer.apple.com/documentation/foundation/notificationcenter/publisher(for:object:))
- [Apple: Publisher.debounce(for:scheduler:options:)](https://developer.apple.com/documentation/combine/publisher/debounce(for:scheduler:options:))
- [Apple: Publishers.CombineLatest](https://developer.apple.com/documentation/combine/publishers/combinelatest)
- [Apple: TimelineView](https://developer.apple.com/documentation/swiftui/timelineview)
- [Apple: Combine](https://developer.apple.com/documentation/combine)
