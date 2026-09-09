# 상태 관리 래퍼 총정리 — 왜 이렇게 종류가 많은가

개별 래퍼는 여러 문서에서 다뤘다. [`@Observable`](./observation-framework-and-observable.md), [`@Environment`](./environment-property-wrapper.md), [프로퍼티 래퍼의 `$`](./property-wrapper-dollar-sign.md), [`@State`의 타입](./state-wrapper-type-and-binding.md). 이 문서는 **전체를 한 자리에 놓고 선택 기준**을 정리한다.

## 질문이 나온 코드

`chapter-94`에 세 방식이 한꺼번에 나온다.

```swift
// chapter_94App.swift
@StateObject var viewModel = TimerViewModel()
ContentView().environmentObject(viewModel)
```

```swift
// TimerViewModel.swift
final class TimerViewModel: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var time: Int = 0
}
```

```swift
// CircularPickerView.swift
@EnvironmentObject var timerVM: TimerViewModel          // 주입받는다
@StateObject private var viewModel = CircularPickerViewModel()   // 직접 소유
```

## 1부 — 왜 헷갈리나: 두 세대가 공존한다

### 질문 확인: 버전에 따른 차이가 맞다

**규칙이 없는 것이 아니라 두 세대의 API가 섞여 있는 것**이다.

| 세대 | 시기 | 모델 | 뷰에서 잡기 |
| --- | --- | --- | --- |
| **1세대** | iOS 13 (2019) | `ObservableObject` + `@Published` | `@StateObject`, `@ObservedObject`, `@EnvironmentObject` |
| **2세대** | **iOS 17 (2023)** | `@Observable` 매크로 | `@State`, 일반 프로퍼티, `@Environment` |

**같은 일을 하는 두 벌의 API가 존재한다.** 강의나 블로그가 어느 시기에 쓰였는지에 따라 다른 방식이 나오므로 헷갈리는 것이 자연스럽다.

### 1세대 — `ObservableObject`

```swift
final class TimerViewModel: ObservableObject {
    @Published var time: Int = 0        // ← @Published가 필요하다
}
```

`ObservableObject`는 **Combine의 프로토콜**이다. [Combine 문서](./combine.md)에서 다룬 대로 `objectWillChange` publisher를 제공한다.

- **`@Published`를 붙인 프로퍼티만** 변경을 알린다
- 변경이 생기면 **구독한 모든 뷰가 갱신된다** (어느 프로퍼티가 바뀌었는지 구분하지 않는다)
- `import Combine`이 필요할 수 있다

### 2세대 — `@Observable`

```swift
@Observable
final class TimerViewModel {
    var time: Int = 0                   // ← 아무 표시도 필요 없다
}
```

- **모든 저장 프로퍼티가 자동으로 추적된다**
- **뷰가 읽은 프로퍼티에 의존한 뷰만** 갱신된다 → 성능 이점
- 계산 프로퍼티, 컬렉션 변화도 추적한다
- Combine 의존이 없다

Apple이 이점을 명시한다.

> Updating views based on changes to the observable properties that a view's `body` reads instead of any property changes that occur to an observable object, **which can help improve your app's performance**.

### `@Published`가 있기도 없기도 한 이유

**모델이 어느 세대인지에 따라 결정된다.**

```swift
// 1세대 — @Published가 필수
class A: ObservableObject {
    @Published var x = 0        // 없으면 뷰가 갱신되지 않는다
}

// 2세대 — @Published를 쓸 수 없다
@Observable
class B {
    var x = 0                   // @Published를 붙이면 오히려 에러
}
```

**`@Observable`에 `@Published`를 붙이면 컴파일 에러다.** 두 시스템을 섞을 수 없다.

### "프로토콜을 상속해서 사용하는" 경우

질문의 이 표현은 두 가지를 가리킬 수 있다.

**① `ObservableObject` 채택** — 1세대 방식

```swift
class TimerViewModel: ObservableObject { }
```

**② `NSObject` 상속 + delegate 프로토콜** — 이 예제

```swift
final class TimerViewModel: NSObject, UNUserNotificationCenterDelegate, ObservableObject { }
```

`NSObject` 상속은 **상태 관리와 무관하다.** [알림 delegate](./user-notifications-framework.md)를 채택하려면 Objective-C 계열 타입이어야 해서 붙은 것이다.

**이 조합이 `@Observable`로 옮기기 어려운 이유**도 여기 있다. `@Observable`은 `NSObject` 상속과 함께 쓸 수 있지만, delegate 책임을 분리하는 편이 낫다. [알림 문서의 아키텍처 절](./user-notifications-framework.md)에서 다뤘다.

## 2부 — 래퍼별 선택 기준

### 전체 대응표

| 상황 | 1세대 | **2세대 (권장)** |
| --- | --- | --- |
| 값 타입 상태를 뷰가 소유 | `@State` | `@State` |
| 부모의 값을 자식이 수정 | `@Binding` | `@Binding` |
| **객체를 뷰가 소유(생성)** | `@StateObject` | **`@State`** |
| **객체를 전달받음** | `@ObservedObject` | **일반 프로퍼티** |
| **객체를 환경에서 꺼냄** | `@EnvironmentObject` | **`@Environment(Type.self)`** |
| 환경 값 읽기 | `@Environment(\.key)` | `@Environment(\.key)` |
| 객체 프로퍼티에 바인딩 | `@ObservedObject` + `$` | **`@Bindable`** |

**`@State`, `@Binding`, `@Environment(\.key)`는 두 세대에서 동일하다.** 바뀐 것은 **객체(클래스)를 다루는 래퍼들**이다.

### 질문 확인: `@StateObject` vs `@EnvironmentObject`

**둘은 대체 관계가 아니라 역할이 다르다.**

| | `@StateObject` | `@EnvironmentObject` |
| --- | --- | --- |
| 역할 | **객체를 만들고 소유한다** | **환경에서 꺼내 쓴다** |
| 생성 | `= TimerViewModel()` | 생성하지 않는다 |
| 수명 | 뷰의 수명에 묶인다 | 주입한 조상이 관리 |
| 없으면 | — | **런타임 크래시** |
| 개수 | 뷰마다 각자 하나 | 조상이 주입한 하나를 공유 |

**`@StateObject`의 핵심은 "한 번만 만든다"** 는 것이다.

```swift
@StateObject var viewModel = TimerViewModel()
```

SwiftUI는 뷰를 자주 다시 만드는데, `@StateObject`가 없으면 **매번 새 `TimerViewModel()`이 생성되어 상태가 초기화된다.** [chapter-69의 `var cart = Cart()` 문제](./observation-framework-and-observable.md)가 정확히 그것이었다.

**`@EnvironmentObject`는 "누군가 넣어 둔 것을 꺼낸다"** 는 것이다.

```swift
@EnvironmentObject var timerVM: TimerViewModel    // 생성하지 않는다
```

**주입되지 않았으면 크래시한다.** 컴파일 시점에는 잡히지 않으므로 프리뷰에서 자주 겪는 문제다.

```swift
#Preview {
    CircularPickerView()
        .environmentObject(TimerViewModel())    // ← 프리뷰에도 주입해야 한다
}
```

### `CircularPickerView`가 둘을 함께 쓰는 것이 올바른 예다

```swift
struct CircularPickerView: View {
    @EnvironmentObject var timerVM: TimerViewModel                  // 공유 상태
    @StateObject private var viewModel = CircularPickerViewModel()  // 이 뷰 전용
}
```

**공유해야 할 것과 이 뷰만 쓰는 것을 구분했다.** 타이머 상태는 앱 전체가 공유하고, 원형 피커의 드래그 각도 같은 것은 이 뷰만 알면 된다. **좋은 판단이다.**

`private`을 붙인 것도 적절하다. 밖에서 주입받을 것이 아니므로 노출할 이유가 없다.

## 3부 — `environmentObject` 주입은 Bean과 같은가

### 질문 확인: 발상은 비슷하지만 다르다

**"조상이 넣어 두면 자손이 꺼내 쓴다"** 는 점에서 DI 컨테이너와 닮았다. 하지만 중요한 차이가 있다.

| | Spring `@Bean` / DI 컨테이너 | SwiftUI `environmentObject` |
| --- | --- | --- |
| 범위 | **애플리케이션 전역** | **뷰 계층 아래로만** |
| 등록 | 컨테이너에 타입 등록 | **뷰 트리의 특정 지점** |
| 조회 | 어디서나 | **조상이 주입한 자손만** |
| 검증 | 컴파일·시작 시점 | **런타임 (없으면 크래시)** |
| 개수 | 타입당 하나 (기본) | **타입당 하나, 계층별로 덮어쓰기 가능** |
| 생명주기 | 컨테이너가 관리 | 주입한 뷰가 관리 |

**가장 큰 차이는 "뷰 계층에 묶인다"는 것**이다.

```swift
WindowGroup {
    ContentView()
        .environmentObject(viewModel)    // 여기 아래로만 유효
}
```

`ContentView`의 자손은 모두 꺼낼 수 있지만, **뷰 트리 밖의 코드는 접근할 수 없다.** 서비스 클래스나 백그라운드 작업에서는 쓸 수 없다.

**계층별로 다른 값을 주입할 수도 있다.**

```swift
VStack {
    ChildA().environmentObject(modelA)
    ChildB().environmentObject(modelB)    // 같은 타입이지만 다른 인스턴스
}
```

Spring에서는 같은 타입 Bean을 이렇게 나눠 주기 어렵다. **뷰 계층 기반이라는 점이 제약이면서 동시에 유연성이다.**

### 여러 개 주입할 수 있나 — 가능하다

```swift
ContentView()
    .environmentObject(timerViewModel)
    .environmentObject(settingsStore)
    .environmentObject(authManager)
```

**타입이 다르면 여러 개 주입할 수 있다.** 꺼낼 때는 타입으로 구분한다.

```swift
@EnvironmentObject var timer: TimerViewModel
@EnvironmentObject var settings: SettingsStore
```

**같은 타입을 두 번 주입하면 나중 것이 이긴다.** 타입이 키 역할을 하므로 하나만 남는다.

2세대에서는 `environment(_:)`를 쓴다.

```swift
ContentView()
    .environment(timerViewModel)      // @Observable 객체
    .environment(settingsStore)
```

### 어느 방식이 Best Practice인가

**질문의 마지막 추측이 정확하다 — 상황에 따라 고른다.** 하나가 항상 옳은 것이 아니다.

**판단 기준**

```text
이 상태를 몇 개의 뷰가 쓰는가?
│
├─ 하나 → @State (또는 @StateObject)
│         뷰 안에 두고 private으로 감춘다
│
├─ 부모-자식 1~2단계 → 프로퍼티 전달 또는 @Binding
│         가장 명시적이고 추적하기 쉽다
│
├─ 여러 화면이 공유 (3단계 이상) → environment 주입
│         중간 뷰가 관여하지 않아도 된다
│
└─ 앱 전역 단일 상태 → App에서 주입
          이 예제의 TimerViewModel이 여기 해당
```

**"뷰마다 뷰모델을 만드는 것"과 "전역 주입" 중 어느 쪽이냐**는 상태의 성격이 결정한다.

| 상태 | 방식 |
| --- | --- |
| 화면 하나의 입력값, 스크롤 위치, 애니메이션 플래그 | **뷰별 소유** (`@State`) |
| 로그인 상태, 테마 설정, 장바구니 | **전역 주입** |
| 목록 → 상세로 넘기는 선택 항목 | **프로퍼티 전달** |
| 여러 화면이 함께 편집하는 문서 | 전역 또는 상위 주입 |

**실무 경향**은 이렇다.

- **환경 주입을 남용하지 않는다.** 어디서 오는지 불명확해지고, 프리뷰마다 주입 코드가 필요해진다
- **기본은 프로퍼티 전달**이고, 계층이 깊어질 때만 환경으로 올린다
- 전역 상태는 **개수를 적게** 유지한다 (인증, 설정 정도)

**이 예제의 판단은 타당하다.** `TimerViewModel`은 앱의 유일한 핵심 상태이고 여러 뷰가 함께 쓰므로 App 수준 주입이 맞다.

### 다만 개선 여지가 있다

**① `@Observable`로 옮기면 더 단순해진다**

```swift
// 현재
@StateObject var viewModel = TimerViewModel()
ContentView().environmentObject(viewModel)

// 2세대
@State private var viewModel = TimerViewModel()
ContentView().environment(viewModel)
```

받는 쪽도 바뀐다.

```swift
// 현재
@EnvironmentObject var timerVM: TimerViewModel

// 2세대
@Environment(TimerViewModel.self) private var timerVM
```

**옵셔널로 받아 크래시를 피할 수도 있다.**

```swift
@Environment(TimerViewModel.self) private var timerVM: TimerViewModel?
```

[Observation 문서의 마이그레이션 절](./observation-framework-and-observable.md)에 절차를 정리했다.

**② `HomeView`의 중복 주입**

```swift
CircularPickerView()
    .environmentObject(viewModel)      // ← 이미 App에서 주입했다
```

`chapter_94App`에서 `ContentView`에 주입했으므로 자손인 `CircularPickerView`도 자동으로 접근할 수 있다. **이 줄은 불필요하다.**

**③ `timerViewOffset` 같은 뷰 레이아웃 값**

```swift
@Published var timerViewOffset: CGFloat = UIScreen.main.bounds.height
```

화면 오프셋은 뷰의 관심사다. 뷰모델에 두면 [`UIScreen.main` 의존](./uiscreen-main-deprecated.md)이 생기고 테스트가 어려워진다. 뷰의 `@State`로 옮기는 편이 낫다.

### 정리

```text
왜 헷갈리나 — 두 세대가 공존한다  ✅ 버전 차이가 맞다
  1세대 (iOS 13): ObservableObject + @Published
                 @StateObject / @ObservedObject / @EnvironmentObject
  2세대 (iOS 17): @Observable
                 @State / 일반 프로퍼티 / @Environment

@Published 유무 = 모델이 어느 세대인지
  ObservableObject → 필수
  @Observable → 쓸 수 없다 (에러)

@StateObject vs @EnvironmentObject — 대체 관계가 아니다
  @StateObject       객체를 만들고 소유. 한 번만 생성
  @EnvironmentObject 환경에서 꺼낸다. 없으면 크래시

environmentObject ≈ DI 컨테이너지만 다르다
  뷰 계층 아래로만 유효 / 런타임 검증 / 계층별 덮어쓰기 가능
  타입이 다르면 여러 개 주입 가능

BP는 상황에 따라 다르다  ✅ 마지막 추측이 맞다
  뷰 하나 → @State
  1~2단계 → 프로퍼티 전달
  3단계 이상 공유 → environment
  앱 전역 → App에서 주입
  환경 주입을 남용하지 않는다
```

## 학습 체크리스트

- [ ] `@StateObject`를 `var`로 바꾸고 뷰 갱신 시 상태가 초기화되는지 확인한다.
- [ ] `@EnvironmentObject`를 쓰는 뷰의 프리뷰를 주입 없이 실행해 크래시를 확인한다.
- [ ] 프리뷰에 `.environmentObject(TimerViewModel())`을 추가해 해결한다.
- [ ] `HomeView`의 `.environmentObject(viewModel)` 줄을 지우고도 동작하는지 확인한다.
- [ ] `@Published`를 하나 지우고 그 값이 바뀔 때 뷰가 갱신되지 않는 것을 확인한다.
- [ ] `@Observable` 클래스에 `@Published`를 붙여 컴파일 에러를 확인한다.
- [ ] `TimerViewModel`을 `@Observable`로 옮기고 `@StateObject` → `@State`로 바꿔 본다.
- [ ] `@EnvironmentObject` → `@Environment(TimerViewModel.self)`로 바꿔 본다.
- [ ] 옵셔널로 받아 주입되지 않아도 크래시하지 않게 만들어 본다.
- [ ] 서로 다른 타입 객체 두 개를 동시에 주입해 본다.
- [ ] 같은 타입을 두 번 주입하고 어느 것이 쓰이는지 확인한다.
- [ ] `CircularPickerViewModel`을 환경으로 옮겨 보고 왜 부적절한지 판단한다.
- [ ] `timerViewOffset`을 뷰의 `@State`로 옮겨 본다.

## 공식 참고 자료

- [Apple: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Apple: Migrating from the Observable Object protocol to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Apple: State](https://developer.apple.com/documentation/swiftui/state)
- [Apple: StateObject](https://developer.apple.com/documentation/swiftui/stateobject)
- [Apple: ObservedObject](https://developer.apple.com/documentation/swiftui/observedobject)
- [Apple: EnvironmentObject](https://developer.apple.com/documentation/swiftui/environmentobject)
- [Apple: Environment](https://developer.apple.com/documentation/swiftui/environment)
- [Apple: Bindable](https://developer.apple.com/documentation/swiftui/bindable)
- [Apple: Binding](https://developer.apple.com/documentation/swiftui/binding)
- [Apple: view.environmentObject(_:)](https://developer.apple.com/documentation/swiftui/view/environmentobject(_:))
- [Apple: view.environment(_:)](https://developer.apple.com/documentation/swiftui/view/environment(_:))
- [Apple: ObservableObject](https://developer.apple.com/documentation/combine/observableobject)
- [Apple: Published](https://developer.apple.com/documentation/combine/published)
- [Apple: Observable() 매크로](https://developer.apple.com/documentation/observation/observable())
- [Apple: Model data](https://developer.apple.com/documentation/swiftui/model-data)
