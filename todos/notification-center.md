# `NotificationCenter` — 멀리 떨어진 컴포넌트끼리 통신하기

## 질문이 나온 코드

`chapter-65/chapter-65/ContentView.swift`

```swift
// 보내는 쪽
let center = NotificationCenter.default
let name = Notification.Name("DTAlert")
let course = DTCourse(name: "Practical SwiftData in SwiftUI", author: "DevTechie.com")
let additionalInfo = ["Course": course]

center.post(name: name, object: nil, userInfo: additionalInfo)
```

```swift
// 받는 쪽
for await notification in center.notifications(named: name) {
    if let userInfo = notification.userInfo,
       let moreInfo = userInfo["Course"] as? DTCourse {
        // ...
    }
}
```

## 1부 — 무엇이고 언제 쓰나

### 앱 안의 방송국이다

`NotificationCenter`는 **발신자와 수신자가 서로를 모르는 채로 메시지를 주고받는** 브로드캐스트 장치다.

핵심 성질을 Apple 문서가 명시한다.

> Each running app has a `default` notification center, and you can create new notification centers to organize communications in particular contexts.
>
> **A notification center can deliver notifications only within a single program.**

**질문 확인: 앱 메모리 상에서만 동작하는가 — 그렇다.** 프로세스 밖으로 나가지 않는다. 다른 앱이나 프로세스와 통신하려면 macOS의 `DistributedNotificationCenter`가 별도로 있다. iOS에는 그 방법이 없다.

디스크에 저장되지도 않는다. 앱이 종료되면 사라진다. **푸시 알림(`UNNotification`)과는 완전히 다른 것**이다. 이름이 비슷해 혼동하기 쉽다.

| | `NotificationCenter` | 푸시 알림 (`UserNotifications`) |
| --- | --- | --- |
| 범위 | **앱 프로세스 안** | 서버 → 기기 |
| 사용자에게 보이나 | 아니오 | 예 (배너, 소리) |
| 목적 | 컴포넌트 간 통신 | 사용자 알림 |

### 질문 확인: 멀리 떨어진 컴포넌트 간 통신인가

**맞다. 그것이 주 용도다.**

이 예제가 그 구조를 보여 준다.

```text
ContentView
 ├─ ReceiverView    ← 수신
 └─ SenderView      ← 발신
```

두 뷰는 형제다. SwiftUI의 일반적인 방법으로 통신하려면 **공통 부모까지 올라갔다 내려와야 한다.**

```swift
// 일반적인 방법 — 부모가 상태를 소유하고 양쪽에 전달
struct ContentView: View {
    @State private var counter = 0
    var body: some View {
        VStack {
            ReceiverView(counter: counter)
            SenderView(onSend: { counter += 1 })
        }
    }
}
```

계층이 깊어지면 중간 뷰들이 자기가 쓰지도 않는 값을 계속 넘겨야 한다. React의 prop drilling과 같은 문제다. [`@Environment` 문서](./environment-property-wrapper.md)에서 다룬 그 문제다.

**`NotificationCenter`는 계층을 완전히 우회한다.** 발신자와 수신자가 서로의 존재를 몰라도 되고, 중간 뷰는 아무것도 하지 않는다.

### 다른 방법들과의 비교

**SwiftUI에서는 `NotificationCenter`가 첫 선택지가 아니다.** 대안이 여럿 있고, 대부분의 경우 그쪽이 낫다.

| 방법 | 적합한 상황 | 타입 안전성 |
| --- | --- | --- |
| 프로퍼티 전달 | 부모 → 자식 (1~2단계) | ✅ |
| [`@Binding`](./property-wrapper-dollar-sign.md) | 자식이 부모 상태를 수정 | ✅ |
| [`@Environment`](./environment-property-wrapper.md) | 계층 깊은 곳까지 값 전달 | ✅ |
| [`@Observable` 공유 객체](./observation-framework-and-observable.md) | 여러 뷰가 상태 공유 | ✅ |
| [`PreferenceKey`](./preference-key-and-onpreferencechange.md) | 자식 → 조상 | ✅ |
| **`NotificationCenter`** | **시스템 이벤트, 프레임워크 경계** | ❌ |

`NotificationCenter`의 결정적 약점은 **타입 안전성이 없다는 것**이다. 문자열 이름과 `[AnyHashable: Any]` 딕셔너리로 통신하므로 컴파일러가 아무것도 검증해 주지 않는다.

**그래서 `NotificationCenter`가 정당한 경우는 좁다.**

**① 시스템 이벤트 수신 — 이게 주 용도다**

이 파일의 다른 예제가 정확히 그 사례다.

```swift
let name = UIDevice.orientationDidChangeNotification
for await notification in center.notifications(named: name) { ... }
```

기기 회전, 키보드 표시/숨김, 앱 상태 전환, 배터리 변화 같은 이벤트는 **시스템이 `NotificationCenter`로 보낸다.** 받는 쪽에서 선택의 여지가 없다.

| 알림 | 용도 |
| --- | --- |
| `UIDevice.orientationDidChangeNotification` | 기기 회전 |
| `UIResponder.keyboardWillShowNotification` | 키보드 표시 |
| `UIApplication.didBecomeActiveNotification` | 앱 활성화 |
| `NSManagedObjectContext.didSaveObjectsNotification` | Core Data 저장 |

**② 프레임워크·모듈 경계를 넘을 때**

서로 직접 의존하지 않아야 하는 모듈 사이에서 쓴다. 라이브러리가 이벤트를 알릴 때도 이 방식이 흔하다.

**③ UIKit 코드와 SwiftUI가 섞인 앱**

기존 UIKit 코드가 이미 알림을 쓰고 있다면 그대로 받는 것이 자연스럽다.

**④ 정말 광범위한 이벤트**

로그아웃, 테마 변경처럼 앱 전역에 영향을 주고 수신자가 언제 몇 개일지 모르는 경우.

**반대로 이 예제처럼 형제 뷰 두 개가 통신하는 상황이라면**, `@Observable` 공유 객체가 더 나은 선택이다.

```swift
@Observable
final class MessageStore {
    var counter = 0
    var additionalInfo = ""
}

struct ContentView: View {
    @State private var store = MessageStore()
    var body: some View {
        VStack {
            ReceiverView()
            SenderView()
        }
        .environment(store)
    }
}
```

타입 안전하고, 문자열 이름을 맞출 필요도 없다. 이 예제는 **`NotificationCenter`를 학습하기 위한 코드**로 이해하면 된다.

## 2부 — `post`의 세 파라미터

```swift
func post(name aName: NSNotification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable : Any]? = nil)
```

### `name` — 질문 확인: 인식이 맞다

**"보내는 쪽과 받는 쪽이 같은 이름을 맞춘다"는 이해가 정확하다.**

```swift
// 양쪽 모두
let name = Notification.Name("DTAlert")
```

이름이 **라우팅 키**다. `notifications(named:)`로 등록한 이름과 `post`의 이름이 일치해야 전달된다. 문자열이 다르면 아무 일도 일어나지 않고, **에러도 나지 않는다.** 조용히 실패하므로 오타가 가장 흔한 버그 원인이다.

**그래서 이름을 상수로 빼는 것이 관례다.**

```swift
extension Notification.Name {
    static let dtAlert = Notification.Name("DTAlert")
}
```

```swift
center.post(name: .dtAlert, object: nil, userInfo: info)
for await notification in center.notifications(named: .dtAlert) { ... }
```

`extension`으로 `static let`을 추가하는 패턴이다([extension 문서](./extension-keyword.md) 참조). 오타가 컴파일 에러가 되고 자동완성도 된다. **이 예제처럼 양쪽에서 문자열을 각각 쓰는 것은 실무에서 피해야 할 형태다.**

### `object` — 발신자를 식별한다

**"누가 보냈는가"를 나타낸다.** 두 가지 용도가 있다.

**① 보내는 쪽 — 자기 자신을 밝힌다**

```swift
center.post(name: .dtAlert, object: self, userInfo: info)
```

**② 받는 쪽 — 특정 발신자만 걸러 받는다**

```swift
// 이 객체가 보낸 것만 받는다
center.notifications(named: .dtAlert, object: specificSender)

// nil이면 발신자를 가리지 않고 모두 받는다
center.notifications(named: .dtAlert, object: nil)
```

같은 이름의 알림을 여러 객체가 보낼 때 유용하다. 예를 들어 여러 텍스트 필드가 각각 변경 알림을 보내면, 특정 필드의 것만 받을 수 있다.

**이 예제는 `object: nil`이다.** 발신자가 하나뿐이라 구분할 필요가 없다.

시스템 알림에서는 `object`에 의미 있는 값이 들어오는 경우가 많다. 같은 파일의 회전 예제가 그렇다.

```swift
if let device = notification.object as? UIDevice {
    if device.orientation.isPortrait { ... }
}
```

`UIDevice.orientationDidChangeNotification`은 `object`에 `UIDevice.current`를 실어 보낸다. 그래서 캐스팅해서 꺼내 쓴다.

### `userInfo` — 부가 데이터를 담는다

> The user information dictionary stores any additional objects that objects receiving the notification might use.

타입은 `[AnyHashable: Any]?`다. **키는 `Hashable`이면 무엇이든, 값은 아무거나** 담을 수 있다.

```swift
let additionalInfo = ["Course": course]
center.post(name: name, object: nil, userInfo: additionalInfo)
```

### 질문 확인: `Codable`이 필요한가 — 아니다

**`userInfo`에 넣는 값은 `Codable`일 필요가 전혀 없다.**

값의 타입이 `Any`이므로 **아무 제약이 없다.** 예제의 `DTCourse`가 `Codable`을 채택하고 있지만, `NotificationCenter` 때문이 아니다. 지워도 동작한다.

```swift
struct DTCourse {          // Codable 없이도 userInfo에 담긴다
    var name: String
    var author: String
}
```

**실제 조건을 정리하면 이렇다.**

| 대상 | 조건 |
| --- | --- |
| **키** | `Hashable` (보통 `String`) |
| **값** | **없음** — `Any`이므로 무엇이든 |

`Codable`이 필요하다는 오해가 생기는 이유는 **Objective-C 시절의 제약** 때문일 것이다. 예전에는 `userInfo`가 `NSDictionary`라 값이 `NSObject`여야 했다. Swift에서는 `Any`이므로 `struct`, `enum`, 클로저까지 담을 수 있다.

**다만 실무에서 주의할 점이 있다.**

- **Swift 동시성에서는 `Sendable`이 문제가 될 수 있다.** 알림이 다른 실행 문맥으로 넘어가면 컴파일러가 경고할 수 있다. 이 예제 마지막 줄의 `extension NotificationCenter: @unchecked Sendable {}`이 그 경고를 우회하려는 시도로 보인다
- **꺼낼 때 반드시 캐스팅해야 한다.** 그래서 `as?`가 필요하고, [타입 캐스팅 문서](./swift-type-casting.md)에서 다룬다
- **키 문자열도 오타 위험이 있다.** 이름과 마찬가지로 상수로 빼는 것이 안전하다

```swift
enum NotificationKey {
    static let course = "Course"
}
```

### 값을 꺼내는 쪽

```swift
if let userInfo = notification.userInfo,
   let moreInfo = userInfo["Course"] as? DTCourse {
    // ...
}
```

두 단계의 옵셔널을 통과한다.

1. `userInfo` 자체가 `[AnyHashable: Any]?` — 없을 수 있다
2. `userInfo["Course"]`가 `Any?` — 키가 없거나 타입이 다를 수 있다

[`if let`의 조건 결합](./if-conditions-and-optional-binding.md)에서 다룬 `,` 연결이고, 앞의 바인딩을 뒤에서 쓰는 구조다.

Apple 문서의 예제도 정확히 같은 형태다.

```swift
if let fieldEditor = notification.userInfo?["NSFieldEditor"] as? NSText,
    let postingObject = notification.object as? NSControl
{
    // work with the field editor and posting object
}
```

## 3부 — 받는 방법 세 가지

Apple 문서가 세 가지 수신 방식을 제시한다.

**① `for await` + `notifications(named:object:)` — 이 예제**

```swift
for await notification in center.notifications(named: name) { ... }
```

가장 현대적인 Swift 방식이다. [AsyncSequence 문서](./for-await-async-sequence.md)에서 다룬다.

**장점**은 옵저버 해제를 신경 쓰지 않아도 된다는 것이다. `Task`가 취소되면 자동으로 구독이 끊긴다.

**② 클로저 기반 옵저버**

```swift
let token = center.addObserver(forName: name, object: nil, queue: .main) { notification in
    // ...
}
// 나중에
center.removeObserver(token)
```

**반드시 해제해야 한다.** 잊으면 옵저버가 남아 메모리 누수와 예상치 못한 호출을 유발한다.

**③ SwiftUI의 `onReceive` — Combine 기반**

```swift
.onReceive(NotificationCenter.default.publisher(for: name)) { notification in
    // ...
}
```

**SwiftUI에서 가장 간단한 방법이다.** 뷰 생명주기에 자동으로 묶이고 메인 스레드에서 실행된다. [Combine 문서](./combine.md)에서 다룬 publisher 개념이다.

이 예제를 `onReceive`로 바꾸면 이렇게 된다.

```swift
struct ReceiverView: View {
    @State private var counter = 0
    @State private var additionalInfo = ""

    var body: some View {
        ZStack { /* ... */ }
            .onReceive(NotificationCenter.default.publisher(for: .dtAlert)) { notification in
                if let course = notification.userInfo?["Course"] as? DTCourse {
                    additionalInfo = "\(course.name) by: \(course.author)"
                }
                counter += 1
            }
    }
}
```

`Task`, `MainActor.run`, `onAppear`가 모두 사라진다. `onReceive`가 메인 스레드를 보장하므로 상태를 직접 바꿔도 된다. [MainActor 문서](./main-actor-and-ios-threading.md)에서 이 부분을 다룬다.

**세 방식 비교**

| | `for await` | `addObserver` | `onReceive` |
| --- | --- | --- | --- |
| 해제 | 자동 (Task 취소) | **수동 필수** | 자동 (뷰 생명주기) |
| 스레드 | 직접 관리 | `queue:`로 지정 | 메인 보장 |
| SwiftUI 적합도 | 보통 | 낮음 | **높음** |
| 코드량 | 보통 | 많음 | 적음 |

### 정리

```text
NotificationCenter
  앱 프로세스 안에서만 동작하는 브로드캐스트
  발신자와 수신자가 서로를 모른다 → 멀리 떨어진 컴포넌트 통신에 유효

하지만 SwiftUI에서 첫 선택지는 아니다
  타입 안전성이 없다 (문자열 이름 + Any 딕셔너리)
  형제 뷰 통신이라면 @Observable 공유 객체가 낫다
  정당한 용도: 시스템 이벤트, 프레임워크 경계, UIKit 혼용

post의 세 파라미터
  name     라우팅 키 — 양쪽이 맞춰야 한다 (상수로 빼는 것이 안전)
  object   발신자 식별 — 특정 발신자만 걸러 받을 때
  userInfo 부가 데이터 — [AnyHashable: Any], Codable 불필요

받는 방법
  for await   자동 해제, 현대적
  addObserver 수동 해제 필수
  onReceive   SwiftUI에서 가장 간단  ← 권장
```

## 학습 체크리스트

- [ ] `Notification.Name` 문자열을 한쪽만 바꿔 조용히 실패하는 것을 확인한다.
- [ ] `extension Notification.Name { static let dtAlert = ... }`로 상수를 만들어 양쪽에 적용한다.
- [ ] `DTCourse`에서 `Codable`을 지우고 여전히 `userInfo`에 담기는지 확인한다.
- [ ] `userInfo`에 클로저를 담아 보고 전달되는지 확인한다.
- [ ] `userInfo["Course"]`의 키를 틀리게 써서 `as?`가 `nil`이 되는지 확인한다.
- [ ] `object: self`로 발신자를 지정하고 받는 쪽에서 `object:`로 필터링해 본다.
- [ ] 두 개의 `SenderView`를 만들어 `object`로 구분해 받아 본다.
- [ ] `notification.object`를 출력해 이 예제에서는 `nil`인 것을 확인한다.
- [ ] 회전 알림에서 `notification.object`가 `UIDevice`인 것을 확인한다.
- [ ] `for await` 방식을 `onReceive`로 바꿔 코드가 얼마나 줄어드는지 비교한다.
- [ ] `addObserver`로 구현하고 해제를 잊었을 때 어떤 일이 생기는지 관찰한다.
- [ ] 같은 기능을 `@Observable` 공유 객체로 구현하고 타입 안전성을 비교한다.
- [ ] 키보드 알림(`keyboardWillShowNotification`)을 받아 본다.
- [ ] `userInfo`의 키를 `enum`이나 `static let` 상수로 정리해 본다.

## 공식 참고 자료

- [Apple: NotificationCenter](https://developer.apple.com/documentation/foundation/notificationcenter)
- [Apple: NotificationCenter.default](https://developer.apple.com/documentation/foundation/notificationcenter/default)
- [Apple: NotificationCenter.post(name:object:userInfo:)](https://developer.apple.com/documentation/foundation/notificationcenter/post(name:object:userinfo:))
- [Apple: NotificationCenter.notifications(named:object:)](https://developer.apple.com/documentation/foundation/notificationcenter/notifications(named:object:))
- [Apple: NotificationCenter.addObserver(forName:object:queue:using:)](https://developer.apple.com/documentation/foundation/notificationcenter/addobserver(forname:object:queue:using:))
- [Apple: NotificationCenter.publisher(for:object:)](https://developer.apple.com/documentation/foundation/notificationcenter/publisher(for:object:))
- [Apple: Notification](https://developer.apple.com/documentation/foundation/notification)
- [Apple: Notification.Name](https://developer.apple.com/documentation/foundation/nsnotification/name)
- [Apple: Notification.userInfo](https://developer.apple.com/documentation/foundation/notification/userinfo)
- [Apple: view.onReceive(_:perform:)](https://developer.apple.com/documentation/swiftui/view/onreceive(_:perform:))
- [Apple: UIDevice.orientationDidChangeNotification](https://developer.apple.com/documentation/uikit/uidevice/orientationdidchangenotification)
- [Apple: DistributedNotificationCenter](https://developer.apple.com/documentation/foundation/distributednotificationcenter)
