# `UserNotifications` 프레임워크와 delegate — 왜 두 함수가 모두 필요했나

`NS`·`UI`·`CG` 접두사는 [별도 문서](./ns-prefix-foundation-classes.md)에 정리했다. 이 문서는 **`UN` 접두사와 알림 delegate**를 다룬다.

## 질문이 나온 코드

`chapter-94/chapter-94/HomeView.swift`

```swift
private func publishNotification() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in }
    UNUserNotificationCenter.current().delegate = viewModel
}
```

`chapter-94/chapter-94/ViewModels/TimerViewModel.swift`

```swift
final class TimerViewModel: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        resetView()
        completionHandler()
    }
}
```

## 1부 — `UN` 접두사는 무엇인가

### `UserNotifications` 프레임워크다

`UN`은 **UserNotifications**의 약자다. [접두사 관례](./ns-prefix-foundation-classes.md)에 하나를 더하면 이렇다.

| 접두사 | 프레임워크 |
| --- | --- |
| `NS` | Foundation (NeXTSTEP) |
| `UI` | UIKit |
| `CG` | Core Graphics |
| `WK` | WebKit |
| **`UN`** | **UserNotifications** |

> User-facing notifications communicate important information to users of your app, **regardless of whether your app is running on the user's device**. For example, a sports app can let the user know when their favorite team scores.

**앱이 실행 중이 아니어도 사용자에게 알릴 수 있다**는 점이 핵심이다. [`NotificationCenter`](./notification-center.md)와 이름이 비슷하지만 완전히 다른 것이다.

| | `NotificationCenter` | `UNUserNotificationCenter` |
| --- | --- | --- |
| 소속 | Foundation | **UserNotifications** |
| 범위 | 앱 프로세스 안 | **시스템 — 앱 밖까지** |
| 사용자에게 보이나 | 아니오 | **예** (배너, 소리, 배지) |
| 목적 | 컴포넌트 간 통신 | 사용자 알림 |

### 주요 타입

이 예제가 쓰는 것들이다.

| 타입 | 역할 |
| --- | --- |
| `UNUserNotificationCenter` | 알림 시스템의 진입점. `.current()`로 접근 |
| `UNMutableNotificationContent` | 제목·본문·소리 등 내용 구성 |
| `UNTimeIntervalNotificationTrigger` | "N초 후" 발동 조건 |
| `UNNotificationRequest` | 내용 + 트리거 + 식별자를 묶은 요청 |
| `UNUserNotificationCenterDelegate` | 알림 표시·응답을 가로채는 프로토콜 |
| `UNNotificationPresentationOptions` | 포그라운드에서 무엇을 보여줄지 |

**트리거는 네 종류가 있다.**

| 트리거 | 조건 |
| --- | --- |
| `UNTimeIntervalNotificationTrigger` | 지정 시간 후 (이 예제) |
| `UNCalendarNotificationTrigger` | 특정 날짜·시각 |
| `UNLocationNotificationTrigger` | 특정 위치 진입·이탈 |
| `UNPushNotificationTrigger` | 서버 푸시 (직접 만들지 않는다) |

**로컬 알림과 원격 알림의 구분**도 알아 둘 만하다.

> For **local notifications**, the app creates the notification content and specifies a condition, like a time or location, that triggers the delivery. For **remote notifications**, your company's server generates push notifications, and Apple Push Notification service (APNs) handles the delivery.

이 예제는 **로컬 알림**이다. 서버가 필요 없다.

## 2부 — delegate가 자동 호출되는 구조인가

### 질문 확인: `performNotification`은 자동 호출되지 않는다

```swift
UNUserNotificationCenter.current().delegate = viewModel
```

**이 한 줄이 하는 일은 "알림 이벤트가 생기면 `viewModel`에게 알려 달라"는 등록**이다. `performNotification`은 delegate 프로토콜의 함수가 아니라 **직접 만든 함수**이므로 자동 호출과 무관하다.

```swift
// 직접 호출한다 — HomeView.startTimer()에서
viewModel.performNotification()
```

**자동 호출되는 것은 프로토콜에 정의된 함수들**이다.

```swift
func userNotificationCenter(_:willPresent:withCompletionHandler:)   // ← 자동
func userNotificationCenter(_:didReceive:withCompletionHandler:)     // ← 자동
```

### delegate 패턴의 동작 원리

**"내가 특정 시점에 너를 부를게"** 라는 계약이다.

```text
① UNUserNotificationCenterDelegate 프로토콜이 "부를 함수 목록"을 정의
② TimerViewModel이 그 프로토콜을 채택해 함수를 구현
③ center.delegate = viewModel  ← 참조를 넘긴다
④ 알림 이벤트 발생 → 시스템이 viewModel의 해당 함수를 호출
```

**`NSObject`를 상속하는 이유**가 여기 있다. `UNUserNotificationCenterDelegate`는 Objective-C 프로토콜이라 채택하는 타입이 `NSObject` 계열이어야 한다. [NS 접두사 문서](./ns-prefix-foundation-classes.md)에서 다룬 Objective-C 런타임 의존성이다.

**`delegate`는 `weak` 참조다.** `viewModel`을 다른 곳에서 강하게 붙잡고 있지 않으면 해제되어 알림이 동작하지 않는다. 이 예제는 `chapter_94App`의 `@StateObject`가 붙잡고 있으므로 안전하다.

## 3부 — 왜 두 함수가 모두 필요했나

### 질문의 핵심 — Apple 문서에 정확한 답이 있다

> **If your delegate does not implement this method, the system behaves as if you had passed the `UNNotificationPresentationOptions()` option to the completionHandler block.** If you do not provide a delegate at all for the `UNUserNotificationCenter` object, the system uses the notification's original options to alert the user.

**이 두 문장이 겪은 현상을 설명한다.**

| 상황 | 결과 |
| --- | --- |
| delegate를 **설정하지 않음** | 알림의 원래 옵션대로 표시 → **알림이 뜬다** |
| delegate 설정 + `willPresent` **미구현** | **빈 옵션으로 취급 → 아무것도 표시되지 않는다** |
| delegate 설정 + `willPresent` 구현 + `completionHandler([.banner, .sound])` | **배너와 소리가 난다** |

**즉 `delegate`를 설정하는 순간 "포그라운드에서 무엇을 보여줄지" 결정 책임이 개발자에게 넘어온다.** 구현하지 않으면 시스템은 "아무것도 표시하지 말라"로 해석한다.

`publishNotification()`이 `delegate = viewModel`을 설정하므로, `willPresent`를 구현하지 않으면 **타이머가 끝나도 알림이 보이지 않는다.** 이것이 겪으신 현상의 원인이다.

### 두 함수의 역할은 완전히 다르다

**`willPresent` — 앱이 포그라운드일 때 호출**

> **If your app is in the foreground when a notification arrives**, the shared user notification center calls this method to deliver the notification directly to your app. If you implement this method, you can take whatever actions are necessary to process the notification and update your app. When you finish, call the completionHandler block and **specify how you want the system to alert the user, if at all**.

앱을 보고 있는 중에 알림이 오면 iOS는 기본적으로 배너를 띄우지 않는다. "이미 앱을 보고 있으니 방해할 필요 없다"는 판단이다. **그래서 배너를 원하면 명시적으로 요청해야 한다.**

```swift
completionHandler([.banner, .sound])    // 배너와 소리를 표시해 달라
completionHandler([])                    // 아무것도 표시하지 마라
```

`UNNotificationPresentationOptions`의 값들이다.

| 옵션 | 의미 |
| --- | --- |
| `.banner` | 화면 상단 배너 |
| `.sound` | 소리 |
| `.badge` | 앱 아이콘 배지 |
| `.list` | 알림 센터 목록에 추가 |
| `.alert` | **deprecated** — `.banner` + `.list`로 분리됨 |

**`didReceive` — 사용자가 알림을 탭했을 때 호출**

> Use this method to process the user's response to a notification. If the user selected one of your app's custom actions, the response parameter contains the identifier for that action. (The response can also indicate that the user dismissed the notification interface, or launched your app, without selecting a custom action.) **If you do not implement this method, your app never responds to custom actions.**

이 예제는 알림을 탭하면 `resetView()`로 타이머를 초기화한다.

**정리하면 두 함수는 서로를 대체할 수 없다.**

| | `willPresent` | `didReceive` |
| --- | --- | --- |
| 호출 시점 | **알림이 도착할 때** (앱이 포그라운드) | **사용자가 알림을 탭할 때** |
| 목적 | 무엇을 표시할지 결정 | 사용자 응답 처리 |
| `completionHandler` | `(UNNotificationPresentationOptions) -> Void` | `() -> Void` |
| 미구현 시 | **포그라운드에서 알림이 안 보인다** | 탭 응답을 처리하지 못한다 |

### 시퀀스 다이어그램

**앱이 포그라운드일 때**

```text
HomeView          TimerViewModel        UNUserNotificationCenter        iOS
   │                    │                        │                      │
   │ startTimer()       │                        │                      │
   ├───────────────────>│                        │                      │
   │                    │ performNotification()  │                      │
   │                    ├───────────────────────>│                      │
   │                    │   add(request)         │                      │
   │                    │                        ├─ 트리거 등록 ────────>│
   │                    │                        │                      │
   │                    │              ⏱ N초 경과 (앱은 포그라운드)      │
   │                    │                        │<─── 트리거 발동 ──────┤
   │                    │                        │                      │
   │                    │  willPresent 호출      │                      │
   │                    │<───────────────────────┤                      │
   │                    │                        │                      │
   │                    │ completionHandler(     │                      │
   │                    │   [.banner, .sound])   │                      │
   │                    ├───────────────────────>│                      │
   │                    │                        ├─ 배너 + 소리 ────────>│
   │                    │                        │                      │
   │              👆 사용자가 배너를 탭            │                      │
   │                    │                        │<──────────────────────┤
   │                    │  didReceive 호출       │                      │
   │                    │<───────────────────────┤                      │
   │                    │ resetView()            │                      │
   │                    │ completionHandler()    │                      │
   │                    ├───────────────────────>│                      │
```

**`willPresent`를 구현하지 않았을 때**

```text
   │                    │                        │<─── 트리거 발동 ──────┤
   │                    │                        │                      │
   │            (delegate는 있지만 willPresent 없음)                     │
   │                    │                        │                      │
   │                    │            시스템이 빈 옵션으로 간주            │
   │                    │                        ├─ ❌ 아무것도 표시 안 함
   │                    │                        │                      │
   │              사용자는 알림을 보지 못한다 → didReceive도 오지 않는다  │
```

**`didReceive`가 오지 않는 것도 연쇄 효과다.** 배너가 보이지 않으면 탭할 대상이 없으므로 응답 함수도 호출되지 않는다. 두 함수를 모두 구현했을 때 비로소 전체 흐름이 완성된 것이다.

### 백그라운드일 때는 다르다

`willPresent`는 **포그라운드일 때만** 호출된다. 앱이 백그라운드나 종료 상태면 시스템이 알아서 배너를 띄우고, `willPresent`는 건너뛴다.

이 예제가 `chapter_94App`에서 `scenePhase`를 확인하는 것도 그 때문이다.

```swift
.onChange(of: scene) { _, newValue in
    if newValue == .background { viewModel.leftTime = Date() }
    // ...
}
```

백그라운드로 간 시점을 기록해 돌아왔을 때 경과 시간을 보정한다. [시뮬레이터와 실기기 차이 문서](./simulator-vs-device-behavior.md)에서 이어서 다룬다.

## 4부 — "nearly matches optional requirement" 경고

### 원인 — `@Sendable`이 빠졌다

```
Instance method 'userNotificationCenter(_:willPresent:withCompletionHandler:)'
nearly matches optional requirement ... of protocol 'UNUserNotificationCenterDelegate'
```

**최신 SDK의 선언에는 `@Sendable`이 붙어 있다.**

```swift
optional func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
)
```

예제 코드에는 `@Sendable`이 없다.

```swift
withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
```

**시그니처가 미묘하게 달라 "거의 일치한다"는 경고가 난다.** 프로토콜 요구사항이 `optional`이라 컴파일은 통과하지만, **실제로는 요구사항을 구현한 것으로 인식되지 않을 수 있다.** Objective-C의 `@optional` 프로토콜이라 런타임에 셀렉터로 조회되기 때문에, 시그니처가 다르면 호출되지 않는다.

**해결 ① `@Sendable` 추가**

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
) {
    completionHandler([.banner, .sound])
}
```

**해결 ② async 버전으로 바꾼다 — 이쪽이 최신 방식이다**

Apple이 두 형태를 모두 제공한다.

> You can call this method from synchronous code using a completion handler, as shown on this page, **or you can call it as an asynchronous method** that has the following declaration:
> ```swift
> optional func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions
> ```

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
}

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    await MainActor.run { resetView() }
}
```

**completion handler가 사라져 훨씬 깔끔하다.** `@Sendable` 경고도 없다. [Combine과 async/await 비교](./combine-vs-async-await.md)에서 다룬 흐름과 같다 — Apple의 새 API는 async 기반으로 정리되고 있다.

## 5부 — 아키텍처 검토

### 질문의 지적이 타당하다

`TimerViewModel`이 세 가지를 겸하고 있다.

```swift
final class TimerViewModel: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var time: Int = 0                    // ① 타이머 상태
    @Published var selectedTime: Int = 0
    @Published var timerViewOffset: CGFloat = ...    // ② 뷰 레이아웃 값
    @Published var buttonAnimation: Bool = false

    func performNotification() { ... }               // ③ 알림 발행
    func userNotificationCenter(...) { ... }         // ④ 알림 delegate
}
```

**책임이 큰 것이 맞다.** 타이머 상태, 화면 오프셋, 알림 발행, 알림 응답 처리가 한 클래스에 있다.

### 무엇이 문제인가

**① delegate 객체를 예상하기 어렵다**

`UNUserNotificationCenter.current().delegate = viewModel`을 `HomeView`에서 설정하는데, `TimerViewModel`의 선언만 봐서는 이것이 언제 어디서 delegate로 쓰일지 알 수 없다. 지적한 그대로다.

**② 테스트가 어렵다**

알림 delegate를 테스트하려면 `TimerViewModel` 전체를 만들어야 하고, 타이머 상태 테스트에도 `NSObject` 상속과 알림 의존이 따라온다.

**③ `UIScreen.main`으로 UIKit에 의존한다**

```swift
@Published var timerViewOffset: CGFloat = UIScreen.main.bounds.height
```

뷰모델이 화면 크기를 알아야 하는 구조다. [UIScreen.main 문서](./uiscreen-main-deprecated.md)에서 다룬다.

**④ `willPresent`가 뷰 상태를 건드리지 않는데도 뷰모델에 있다**

`willPresent`는 표시 옵션만 결정한다. 뷰모델 상태와 무관하므로 여기 있을 이유가 약하다.

### 나눈다면 이렇게

```swift
/// 알림 발행과 표시 정책만 담당
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    /// 알림을 탭했을 때 알릴 콜백. 뷰모델이 주입한다.
    var onNotificationTapped: (@MainActor () -> Void)?

    func requestAuthorization() async -> Bool { ... }
    func scheduleTimerNotification(after seconds: Int) { ... }

    func userNotificationCenter(_ c: UNUserNotificationCenter,
                                willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ c: UNUserNotificationCenter,
                                didReceive r: UNNotificationResponse) async {
        await onNotificationTapped?()
    }
}
```

```swift
/// 타이머 상태만 담당
@Observable
final class TimerViewModel {
    var time = 0
    var selectedTime = 0

    private let notifications: NotificationService

    init(notifications: NotificationService) {
        self.notifications = notifications
        notifications.onNotificationTapped = { [weak self] in self?.resetView() }
    }
}
```

**얻는 것**

- 알림 로직을 독립적으로 테스트할 수 있다
- `TimerViewModel`이 `NSObject`를 상속하지 않아 [`@Observable`](./observation-framework-and-observable.md)로 옮기기 쉬워진다
- delegate가 어디서 쓰이는지 `NotificationService`만 보면 안다
- 뷰 레이아웃 값(`timerViewOffset`)은 뷰의 `@State`로 옮길 수 있다

### 다만 — 현재 구조도 방어할 수 있다

**"상태 의존성이 강해서 어쩔 수 없는 것 같기도 하다"** 는 판단도 일리가 있다.

- `didReceive`에서 `resetView()`를 불러야 하므로 뷰모델 상태에 접근이 필요하다
- 콜백으로 분리하면 간접 계층이 하나 늘어난다
- **학습 예제 규모에서는 분리 비용이 이득보다 클 수 있다**

**실무 기준으로는 나누는 편이 낫다.** 알림, 타이머, 화면 애니메이션은 각각 다른 이유로 변경되고, 한 클래스에 있으면 하나를 고칠 때 나머지가 영향받는다.

**절충안**은 delegate만 별도 클래스로 빼고 상태는 뷰모델에 두는 것이다. 위 예제의 `onNotificationTapped` 콜백 방식이 그 형태다.

### 정리

```text
UN = UserNotifications 프레임워크
  NotificationCenter(앱 내부)와 완전히 다르다 — 시스템 알림

delegate = viewModel 은 "이벤트가 생기면 알려 달라"는 등록
  performNotification은 프로토콜 함수가 아니라 직접 호출한다

두 함수가 모두 필요했던 이유  ← 질문의 핵심
  willPresent  앱이 포그라운드일 때 "무엇을 표시할지" 결정
  didReceive   사용자가 탭했을 때 응답 처리

  Apple 문서: delegate가 있는데 willPresent를 구현하지 않으면
             시스템이 빈 옵션으로 간주 → 아무것도 표시하지 않는다
  → 배너가 안 보이니 탭할 수도 없고 didReceive도 오지 않았다

"nearly matches" 경고 = @Sendable 누락
  해결: @Sendable 추가 또는 async 버전 사용 (최신 방식)

아키텍처: 책임이 크다는 지적이 타당하다
  알림 delegate를 NotificationService로 분리하고
  콜백으로 뷰모델과 연결하는 편이 낫다
```

## 학습 체크리스트

- [ ] `willPresent`를 주석 처리하고 포그라운드에서 알림이 안 보이는 것을 재현한다.
- [ ] `delegate = viewModel` 줄도 함께 주석 처리하고 알림이 다시 보이는지 확인한다.
- [ ] `completionHandler([])`로 바꿔 아무것도 표시되지 않는 것을 확인한다.
- [ ] `completionHandler([.banner])`로 소리만 빼 본다.
- [ ] `.list`를 추가하고 알림 센터에 남는지 확인한다.
- [ ] 앱을 백그라운드로 보낸 뒤 알림이 오면 `willPresent`가 호출되는지 로그로 확인한다.
- [ ] `didReceive`에 `print`를 넣고 배너를 탭해 호출되는지 확인한다.
- [ ] `@Sendable`을 추가해 "nearly matches" 경고가 사라지는지 확인한다.
- [ ] async 버전으로 두 함수를 바꿔 보고 completion handler가 사라지는 것을 확인한다.
- [ ] `NSObject` 상속을 지우고 어떤 에러가 나는지 확인한다.
- [ ] `requestAuthorization`의 `granted`를 확인해 권한 거부 시 동작을 처리해 본다.
- [ ] `UNCalendarNotificationTrigger`로 특정 시각 알림을 만들어 본다.
- [ ] `NotificationService`로 delegate를 분리하고 콜백으로 연결해 본다.
- [ ] `getPendingNotificationRequests`로 등록된 알림 목록을 조회해 본다.

## 공식 참고 자료

- [Apple: User Notifications](https://developer.apple.com/documentation/usernotifications)
- [Apple: UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Apple: UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
- [Apple: userNotificationCenter(_:willPresent:withCompletionHandler:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/usernotificationcenter(_:willpresent:withcompletionhandler:))
- [Apple: userNotificationCenter(_:didReceive:withCompletionHandler:)](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/usernotificationcenter(_:didreceive:withcompletionhandler:))
- [Apple: UNNotificationPresentationOptions](https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions)
- [Apple: UNMutableNotificationContent](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent)
- [Apple: UNTimeIntervalNotificationTrigger](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger)
- [Apple: UNNotificationRequest](https://developer.apple.com/documentation/usernotifications/unnotificationrequest)
- [Apple: Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Apple: Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Apple: Handling notifications and notification-related actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)
- [Apple HIG: Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
