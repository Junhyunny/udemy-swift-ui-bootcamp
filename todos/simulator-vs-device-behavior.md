# `#if !targetEnvironment(simulator)` — 이 코드로 무엇을 확인하려 했나

## 질문이 나온 코드

`chapter-94/chapter-94/chapter_94App.swift`

```swift
.onChange(of: scene) { _, newValue in
    // TODO, 시뮬레이터와 실제 디바이스 애플리케이션이 서로 다르게 동작하기 때문에
    //       이를 확인하기 위한 코드야. 어떤 부분을 확인하고 싶은거야? 추측해봐.
    #if !targetEnvironment(simulator)
        if newValue == .background {
            viewModel.leftTime = Date()
            print("App entered background")
        }
        if newValue == .active && viewModel.leftTime != nil {
            let diffInTime = Date().timeIntervalSince(viewModel.leftTime)
            let currentTime = viewModel.selectedTime - Int(diffInTime)
            print("Diff in time", diffInTime)
            print("Current time", currentTime)
            if currentTime >= 0 {
                withAnimation(.default) {
                    viewModel.selectedTime = currentTime
                }
            } else {
                viewModel.resetView()
            }
        }
    #endif
}
```

## 공부할 내용

### 이 코드가 하는 일 — 백그라운드 경과 시간 보정

먼저 로직을 읽으면 의도가 드러난다.

```text
① 앱이 백그라운드로 갈 때  → 그 시각을 leftTime에 기록
② 앱이 다시 활성화될 때    → 지금과 leftTime의 차이를 계산
③ 남은 시간에서 그 차이를 뺀다
④ 0보다 작으면 타이머가 이미 끝난 것 → resetView()
```

**왜 필요한가.** [`Timer.publish`](./timer-publisher-and-onreceive.md)는 앱이 백그라운드로 가면 **멈춘다.** 앱이 서스펜드되면 런루프가 돌지 않기 때문이다.

```text
타이머 60초 시작
   ↓ 10초 경과 (남은 시간 50)
앱을 백그라운드로 보낸다 → Timer가 멈춘다
   ↓ 실제로 30초 경과
앱으로 돌아온다 → Timer가 다시 시작
   ↓
보정 없으면: 남은 시간이 여전히 50초  ← 실제로는 20초여야 한다
보정 있으면: 50 - 30 = 20초           ✅
```

**이 코드는 "앱이 잠들어 있던 시간"을 시계로 계산해 메꾸는 것**이다.

### 그럼 왜 시뮬레이터에서 제외했나 — 추측

`#if !targetEnvironment(simulator)`는 **시뮬레이터가 아닐 때만** 이 블록을 컴파일한다. 즉 **실기기에서만 동작한다.**

**확인하려던 것은 이것으로 보인다.**

#### ① 시뮬레이터는 백그라운드 전환이 실기기와 다르다 — 가장 유력하다

**시뮬레이터에서는 앱이 실제로 서스펜드되지 않는 경우가 많다.**

- macOS가 시뮬레이터 프로세스를 실기기처럼 적극적으로 정지시키지 않는다
- 홈으로 나가도 타이머가 계속 도는 경우가 있다
- 그러면 `Timer`가 멈추지 않았는데 시간 보정까지 적용되어 **시간이 두 배로 빠지는** 현상이 생긴다

```text
시뮬레이터 (Timer가 계속 도는 경우)
  30초 백그라운드 → Timer가 30번 발동해 이미 30초 차감
                  → 복귀 시 보정으로 또 30초 차감
                  → 남은 시간이 60초나 줄어든다  ⚠️
```

**이것이 가장 그럴듯한 이유다.** 시뮬레이터에서 타이머가 이상하게 튀는 것을 겪고 실기기 전용으로 격리했을 가능성이 높다.

#### ② 알림이 시뮬레이터에서 다르게 동작한다

[알림 문서](./user-notifications-framework.md)에서 다룬 `UNTimeIntervalNotificationTrigger`도 시뮬레이터와 실기기가 다르다.

- 시뮬레이터는 배터리·성능 관리가 없어 트리거 타이밍이 다르다
- 소리가 macOS 설정에 따라 나지 않을 수 있다
- 앱이 서스펜드되지 않으면 `willPresent`가 계속 호출된다

#### ③ 시뮬레이터의 시각이 호스트와 얽혀 있다

`Date()`는 시스템 시각을 읽는다. 시뮬레이터는 macOS 시각을 따르므로, 맥이 절전에서 깨어나거나 시각을 조정하면 `timeIntervalSince` 결과가 튈 수 있다.

#### ④ `scenePhase` 전환 시점이 다르다

시뮬레이터에서 `⌘H`로 홈에 가는 것과 실기기에서 홈 제스처를 쓰는 것이 **같은 `scenePhase` 순서를 만들지 않을 수 있다.** `.inactive`를 거치는 방식이나 타이밍이 다르다.

### 어떤 것이 실제 이유였는지 확인하는 방법

**로그를 시뮬레이터에서도 남겨 보면 알 수 있다.**

```swift
.onChange(of: scene) { old, newValue in
    print("scenePhase: \(old) → \(newValue), leftTime: \(String(describing: viewModel.leftTime))")

    #if targetEnvironment(simulator)
        print("[SIM] 보정 로직 건너뜀")
    #endif
    // ...
}
```

**시뮬레이터에서 백그라운드로 보낸 뒤 타이머가 계속 도는지 확인**하면 ①이 원인인지 판별된다.

```swift
.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
    print("tick \(Date())")     // 백그라운드에서도 찍히나?
    timerProgress(geo)
}
```

백그라운드에서도 `tick`이 찍히면 ①이 맞다.

### `#if targetEnvironment(...)` 문법

**컴파일 시점 조건부 컴파일**이다. 런타임 분기가 아니다.

```swift
#if targetEnvironment(simulator)
    // 시뮬레이터 빌드에만 포함된다
#endif

#if !targetEnvironment(simulator)
    // 실기기 빌드에만 포함된다
#endif
```

**조건에 맞지 않는 코드는 컴파일조차 되지 않는다.** 그래서 시뮬레이터 빌드에서는 이 블록이 아예 없는 것과 같다.

**쓸 수 있는 조건들**

| 조건 | 의미 |
| --- | --- |
| `targetEnvironment(simulator)` | 시뮬레이터 |
| `targetEnvironment(macCatalyst)` | Mac Catalyst |
| `os(iOS)`, `os(macOS)`, `os(watchOS)` | 운영체제 |
| `arch(arm64)`, `arch(x86_64)` | 아키텍처 |
| `DEBUG` | 디버그 빌드 (빌드 설정으로 정의) |
| `canImport(UIKit)` | 모듈 사용 가능 여부 |
| `swift(>=5.9)` | Swift 버전 |

[`UIViewRepresentable` 문서](./uiviewrepresentable-and-uikit-bridge.md)에서 플랫폼별 분기에 `#if os(iOS)`를 쓴 것과 같은 문법이다.

### 이 접근이 좋은 방법인가

**임시 회피로는 이해되지만 몇 가지 문제가 있다.**

**① 시뮬레이터에서 기능을 테스트할 수 없다**

보정 로직이 시뮬레이터 빌드에 없으므로, **개발 중에 이 코드가 올바른지 검증할 수 없다.** 실기기에 매번 올려야 확인 가능하다.

**② 시뮬레이터 빌드와 실기기 빌드가 다른 코드가 된다**

같은 소스로 서로 다른 앱이 만들어진다. **"시뮬레이터에서는 되는데 실기기에서 안 된다"** 는 문제의 원인이 되기 쉽다.

**③ 근본 원인을 가린다**

시뮬레이터에서 타이머가 튀었다면, 문제는 **"백그라운드에서 타이머가 계속 도는 것"** 이다. 그것을 막는 편이 정확하다.

### 더 나은 방향

**① 타이머를 상태 기반으로 멈춘다**

```swift
.onReceive(timer) { _ in
    guard scenePhase == .active else { return }    // 활성 상태에서만
    timerProgress(geo)
}
```

**시뮬레이터든 실기기든 백그라운드에서는 차감하지 않는다.** 그러면 보정 로직이 두 환경에서 동일하게 동작한다.

**② 절대 시각 기반으로 계산한다 — 가장 견고하다**

"남은 시간을 1초씩 줄인다"는 접근 자체가 취약하다. **종료 시각을 기록하고 매번 계산**하면 백그라운드 문제가 사라진다.

```swift
@Observable
final class TimerViewModel {
    var endDate: Date?
    var totalSeconds = 0

    /// 지금 기준 남은 시간
    var remainingSeconds: Int {
        guard let endDate else { return totalSeconds }
        return max(0, Int(endDate.timeIntervalSinceNow.rounded()))
    }

    func start(seconds: Int) {
        totalSeconds = seconds
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
    }
}
```

**타이머는 화면을 갱신하는 역할만 한다.**

```swift
.onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
    if viewModel.remainingSeconds == 0 { viewModel.resetView() }
    // remainingSeconds는 계산 프로퍼티라 자동으로 최신 값이다
}
```

**얻는 것**

- 백그라운드 보정 코드가 **아예 필요 없다** — `endDate`가 절대 시각이므로 복귀 시 자동으로 맞는다
- 시뮬레이터/실기기 분기가 사라진다
- 타이머가 몇 번 발동했는지와 무관하게 정확하다
- 앱이 종료됐다 다시 켜져도 `endDate`를 저장해 두면 복원된다

`remainingSeconds`가 계산 프로퍼티인 것이 핵심이다. [계산 프로퍼티 문서](./computed-property-with-closure-body.md)에서 다룬 "접근할 때마다 계산"이 여기서는 장점이 된다.

**③ `leftTime`이 IUO인 문제도 함께 사라진다**

[암시적 언래핑 옵셔널 문서](./implicitly-unwrapped-optional.md)에서 지적한 `Date!`가 `Date?`(또는 `endDate`)로 정리된다.

### 시뮬레이터와 실기기가 실제로 다른 것들

이 예제와 별개로 알아 둘 만한 목록이다.

| 영역 | 차이 |
| --- | --- |
| **백그라운드 서스펜드** | 시뮬레이터는 덜 적극적이다 |
| **알림 소리·진동** | 진동 없음, 소리는 macOS 설정 따름 |
| **카메라·마이크** | Mac 하드웨어를 쓰거나 지원 안 함 |
| **Core Haptics** | **지원 안 함** — [chapter-51에서 겪은 로그](./deep-link-and-url-scheme.md)의 원인 |
| **성능** | Mac CPU를 쓰므로 훨씬 빠르다 |
| **메모리 압박** | 실기기보다 여유롭다 |
| **Keychain·생체 인증** | 동작이 다르거나 제한적 |
| **푸시 알림** | 원격 푸시는 별도 설정 필요 |
| **위치** | 시뮬레이션 값만 |
| **네트워크 상태 변화** | 실제 셀룰러↔WiFi 전환이 없다 |

**"시뮬레이터에서 되는데 실기기에서 안 된다"의 반대도 흔하다.** 시뮬레이터가 더 관대하므로, 실기기에서 처음 드러나는 문제가 많다.

### 정리

```text
이 코드가 하는 일
  앱이 백그라운드에 있던 시간을 시계로 계산해 남은 시간을 보정
  Timer.publish가 백그라운드에서 멈추기 때문에 필요하다

왜 시뮬레이터를 제외했나 — 추측
  ① 시뮬레이터는 앱을 실제로 서스펜드하지 않는 경우가 있다  ← 가장 유력
     → Timer가 계속 돌아 이미 차감된 상태에서 보정까지 적용
     → 시간이 두 배로 줄어드는 현상
  ② 알림 트리거·소리 동작이 다르다
  ③ Date()가 macOS 시각과 얽혀 있다
  ④ scenePhase 전환 순서가 다를 수 있다

확인 방법
  백그라운드에서 Timer의 tick이 찍히는지 로그로 본다

#if targetEnvironment(simulator)는 컴파일 시점 분기
  조건에 맞지 않는 코드는 컴파일조차 되지 않는다

더 나은 방향
  endDate(절대 시각)를 기록하고 remainingSeconds를 계산 프로퍼티로
  → 보정 코드와 시뮬레이터 분기가 모두 불필요해진다
```

## 학습 체크리스트

- [ ] `#if !targetEnvironment(simulator)`를 지우고 시뮬레이터에서 타이머를 백그라운드로 보낸 뒤 관찰한다.
- [ ] 타이머 `tick`에 `print(Date())`를 넣고 백그라운드에서도 찍히는지 확인한다.
- [ ] `scenePhase` 전환을 `print(old, "→", new)`로 찍어 순서를 확인한다.
- [ ] 시뮬레이터와 실기기에서 같은 로그를 비교한다.
- [ ] `#if targetEnvironment(simulator)` 블록에 컴파일 에러가 있는 코드를 넣고 실기기 빌드가 통과하는지 확인한다.
- [ ] `guard scenePhase == .active else { return }`를 타이머에 추가해 본다.
- [ ] `endDate` 기반으로 리팩터링하고 보정 코드를 제거해 본다.
- [ ] `remainingSeconds`를 계산 프로퍼티로 만들어 백그라운드 복귀 시 자동으로 맞는지 확인한다.
- [ ] `endDate`를 `UserDefaults`에 저장해 앱 종료 후에도 복원되게 만들어 본다.
- [ ] `#if os(iOS)`, `#if DEBUG` 등 다른 조건부 컴파일을 써 본다.
- [ ] `leftTime: Date!`을 `Date?`로 바꾸고 옵셔널 바인딩으로 처리한다.

## 공식 참고 자료

- [Swift 공식 문서: Statements — Conditional Compilation Block](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#Conditional-Compilation-Block)
- [Swift 공식 문서: Statements — targetEnvironment](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#Conditional-Compilation-Block)
- [Apple: EnvironmentValues.scenePhase](https://developer.apple.com/documentation/swiftui/environmentvalues/scenephase)
- [Apple: ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase)
- [Apple: About the background execution sequence](https://developer.apple.com/documentation/uikit/about-the-background-execution-sequence)
- [Apple: Preparing your UI to run in the background](https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background)
- [Apple: Running your app in Simulator or on a device](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)
- [Apple: Testing in Simulator versus testing on hardware devices](https://developer.apple.com/documentation/xcode/testing-in-simulator-versus-testing-on-hardware-devices)
- [Apple: Date](https://developer.apple.com/documentation/foundation/date)
- [Apple: Timer](https://developer.apple.com/documentation/foundation/timer)
