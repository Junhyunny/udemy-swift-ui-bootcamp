# `@State`와 `_viewModel` — 프로퍼티 래퍼가 만드는 세 개의 이름

## 질문이 나온 코드

`chapter-146/chapter-146/Views/OnboardingView.swift`

```swift
struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    init(steps: [OnboardingStep], onComplete: @escaping () -> Void = {}) {
        self._viewModel = State(
            wrappedValue: .init(steps: steps, onComplete: onComplete)
        )
    }
    // ...
}
```

질문은 세 가지다.

1. `@State`는 무엇인가
2. `_viewModel`은 어디서 나온 이름인가
3. `_viewModel`을 쓰는 건 `private` 멤버에 접근하는 방법인가

## 공부할 내용

### 결론 먼저

**3번의 답은 "아니다"이다.** `_viewModel`은 `private`을 우회하는 트릭이 아니다. **컴파일러가 `@State`를 보고 자동으로 만들어 준 저장 프로퍼티의 진짜 이름**이고, 그 자체도 `private`이다. 같은 `struct` 안(여기서는 `init`)이라 접근이 되는 것뿐이다.

`@State private var viewModel: OnboardingViewModel` 한 줄을 쓰면 컴파일러는 **이름이 세 개** 생긴 것처럼 다뤄 준다.

| 표기 | 정체 | 타입 | 쓰는 곳 |
|---|---|---|---|
| `viewModel` | `wrappedValue` | `OnboardingViewModel` | 평소에 값 읽고 쓸 때 |
| `$viewModel` | `projectedValue` | `Binding<OnboardingViewModel>` | 양방향 바인딩을 넘길 때 |
| `_viewModel` | **래퍼 인스턴스 자체** | `State<OnboardingViewModel>` | `init`에서 초기화할 때 |

앞의 둘은 이미 [`@State`를 붙이면 타입이 바뀌는가 문서](./state-wrapper-type-and-binding.md)와 [프로퍼티 래퍼의 `$` 문서](./property-wrapper-dollar-sign.md)에서 다뤘다. **이 문서는 세 번째, `_` 를 다룬다.**

### 1. `@State`가 무엇인가

`@State`는 SwiftUI가 제공하는 **프로퍼티 래퍼**다. 공식 문서의 정의는 한 줄이다.

> A property wrapper type that can read and write a value managed by SwiftUI.

핵심은 **"SwiftUI가 관리하는(managed by SwiftUI)"**이다. `View`는 `struct`이고, 화면이 갱신될 때마다 **버려지고 새로 만들어진다.** 그래서 뷰 구조체에 값을 그냥 저장하면 갱신할 때마다 초기값으로 되돌아간다.

```text
일반 프로퍼티                @State 프로퍼티
─────────────                ─────────────
값이 struct 안에 있다        값은 SwiftUI가 뷰 바깥에 보관한다
뷰가 새로 만들어지면 사라짐   뷰가 새로 만들어져도 같은 값이 다시 연결됨
바꿔도 화면이 안 바뀜         바꾸면 그 값을 읽은 뷰가 다시 그려짐
```

그래서 `@State`는 두 가지를 동시에 한다.

- **값을 뷰 바깥에 보관**해 뷰 재생성에도 살아남게 한다
- **값이 바뀌면 그 값을 읽은 뷰를 다시 그린다**

공식 문서는 `private`을 붙이라고 권한다. 멤버와이즈 이니셜라이저로 밖에서 넣지 못하게 막아 SwiftUI의 저장소 관리와 충돌하지 않기 위해서다.

> Declare state as private to prevent setting it in a memberwise initializer, which can conflict with the storage management that SwiftUI provides.

### 2. `_viewModel`은 어디서 나왔나

프로퍼티 래퍼는 [SE-0258](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0258-property-wrappers.md)에서 언어에 들어온 기능이다. 컴파일러는 `@Wrapper var x: T`를 보면 대략 이런 코드로 바꾼다.

```swift
// 우리가 쓴 코드
@State private var viewModel: OnboardingViewModel

// 컴파일러가 만들어 내는 것 (개념적으로)
private var _viewModel: State<OnboardingViewModel>          // ← 실제 저장 프로퍼티

private var viewModel: OnboardingViewModel {                 // ← 편의 접근자
    get { _viewModel.wrappedValue }
    nonmutating set { _viewModel.wrappedValue = newValue }
}

private var $viewModel: Binding<OnboardingViewModel> {       // ← projectedValue
    _viewModel.projectedValue
}
```

**실제로 메모리에 저장되는 것은 `_viewModel` 하나뿐**이고, `viewModel`과 `$viewModel`은 그리로 가는 통로다. 언더스코어를 쓰는 것은 우연이 아니라 제안서에 명시된 규약이다.

> The use of the prefix `_` for the synthesized storage property name is deliberate: it provides a predictable name for the synthesized storage property that fits established conventions for private stored properties.

제안서는 **이 저장 프로퍼티가 항상 `private`**이라고도 못박는다. 즉 `_viewModel`은 `private`을 뚫는 이름이 아니라, **처음부터 `private`인 이름**이다. 다른 타입에서 `otherView._viewModel`을 쓰면 컴파일 오류가 난다. [Swift 접근 제어 문서](./access-control.md)와 이어진다.

### 3. `init`에서 왜 `_viewModel = State(...)`인가

`init`에서 이렇게 쓰고 싶어진다.

```swift
init(steps: [OnboardingStep], onComplete: @escaping () -> Void = {}) {
    self.viewModel = .init(steps: steps, onComplete: onComplete)   // ❌
}
```

하지만 이건 안 된다. `viewModel = ...`은 위에서 본 대로 **`_viewModel.wrappedValue`의 setter를 호출**하는 코드인데, `_viewModel`이 아직 초기화되지 않았기 때문이다. 저장 프로퍼티를 채우기 전에 그 값을 읽으려는 셈이라 컴파일러가 막는다.

**실제로 저장해야 할 프로퍼티는 `_viewModel`**이므로, 그 이름으로 `State` 인스턴스를 직접 만들어 넣는다.

```swift
self._viewModel = State(wrappedValue: .init(steps: steps, onComplete: onComplete))
```

`State`에는 초기화 방법이 두 가지 있다.

| 이니셜라이저 | 용도 |
|---|---|
| `State(wrappedValue:)` | 프로퍼티 래퍼 문법(`@State var x = ...`)이 내부적으로 호출하는 것. `init`에서 직접 쓸 때도 이쪽을 쓴다 |
| `State(initialValue:)` | 같은 일을 하는 명시적 이름. 래퍼 문법과 무관하게 값을 넣을 때 |

동작은 사실상 같다. 관례적으로 `wrappedValue:`를 더 많이 쓴다.

`.init(steps:onComplete:)`에서 타입 이름이 생략된 이유는 **`State<OnboardingViewModel>`의 `wrappedValue` 타입이 이미 정해져 있어** 컴파일러가 추론하기 때문이다.

### 꼭 알아야 할 함정 — `init`은 여러 번 돌지만 State는 한 번만 쓴다

이게 실무에서 가장 많이 헷갈리는 지점이다.

```text
부모 뷰가 다시 그려짐
        ↓
OnboardingView(steps:onComplete:) 가 다시 호출됨   ← init 실행됨
        ↓
State(wrappedValue: OnboardingViewModel(...)) 가 새로 만들어짐
        ↓
SwiftUI: "이 뷰는 이미 State 저장소가 있네"
        ↓
방금 만든 새 인스턴스는 버려지고, 기존 값이 유지됨
```

즉 **`@State`의 초기값은 뷰가 처음 등장할 때 한 번만 반영된다.** 결과적으로 두 가지를 각오해야 한다.

- 부모가 나중에 다른 `steps`를 넘겨도 **`viewModel`은 바뀌지 않는다.** 처음 값 그대로다.
- 그런데도 `OnboardingViewModel(...)`은 **`init`이 돌 때마다 새로 만들어졌다가 버려진다.**

공식 문서도 이 비용을 경고한다.

> A `State` property always instantiates its default value when SwiftUI instantiates the view. For this reason, avoid side effects and performance-intensive work when initializing the default value.

`OnboardingViewModel`의 `init`은 배열과 클로저를 저장만 하므로 지금은 문제가 없다. 하지만 여기서 네트워크 호출이나 파일 읽기를 했다면 **화면이 갱신될 때마다 그 작업이 실행된다.** 그런 경우 문서가 제시하는 대안은 옵셔널로 두고 `.task`에서 만드는 방식이다.

```swift
@State private var library: Library?

var body: some View {
    LibraryView(library: library)
        .task { library = Library() }   // 뷰가 처음 나타날 때 한 번
}
```

[`.task` 문서](./task-modifier-and-async-lifecycle.md)와 이어진다.

### `@Observable` 클래스를 `@State`에 담는 것이 맞나

맞다. 공식 문서가 직접 제시하는 패턴이다.

> You can also store observable objects that you create with the `@Observable` macro in `State`.

```swift
@Observable
class Library { var name = "My library of books" }

struct ContentView: View {
    @State private var library = Library()
    // ...
}
```

`@Observable`이 나오기 전에는 `@StateObject`를 썼다. 지금 코드의 `OnboardingViewModel`은 `@Observable`이 붙은 `final class`이므로 `@State`가 맞다. [`Observation` 모듈과 `@Observable` 문서](./observation-framework-and-observable.md), [상태 관리 래퍼 총정리](./state-wrapper-decision-guide.md)를 함께 본다.

역할 분담을 정리하면 이렇다.

```text
@State   → "이 뷰가 이 객체의 수명을 소유한다"  (한 번 만들고 계속 유지)
@Observable → "이 객체의 어떤 속성이 바뀌면 알려 준다" (변경 추적)
```

주의할 점 하나. `ObservableObject`(Combine 쪽)를 `@State`에 담으면 **참조가 바뀔 때만** 갱신되고 `@Published` 속성 변화는 무시된다. 이 경우는 `@StateObject`를 써야 한다. 문서의 Note가 그 얘기다.

### 이 코드에 적용하면

```swift
@State private var viewModel: OnboardingViewModel

init(steps: [OnboardingStep], onComplete: @escaping () -> Void = {}) {
    self._viewModel = State(
        wrappedValue: .init(steps: steps, onComplete: onComplete)
    )
}
```

- `steps`와 `onComplete`는 **밖에서 받아야 하는 값**이라 선언부에 초기값을 적을 수 없다. 그래서 `init`이 필요했다.
- `init`이 필요하면 `@State` 프로퍼티는 **`_` 이름으로 초기화**하는 수밖에 없다.
- `private`은 SwiftUI 권고를 따른 것이고, 같은 `struct`의 `init` 안이므로 `_viewModel` 접근은 정상이다.
- 이 `viewModel`은 화면이 몇 번 다시 그려져도 **같은 인스턴스**로 유지되고, `$viewModel.currentIndex`로 바인딩을 꺼내 `scrollPosition`에 넘긴다. 그 부분은 [`scrollPosition(id:)` 문서](./scroll-position-binding.md)에서 이어서 다룬다.

### 참고 — `@State` 매크로

공식 문서에 이런 안내가 붙어 있다.

> Important: When you build with Xcode 27 or later, the system uses the `State()` macro instead.

프로퍼티 래퍼에서 매크로로 구현이 바뀐다는 뜻이다. 사용하는 문법(`@State private var x`)은 그대로지만, 생성되는 코드의 형태는 달라질 수 있다. 지금 단계에서는 **"`_` 접두 이름이 컴파일러 생성물"이라는 원리만 잡아 두면 충분**하다. [Swift macro 문서](./swift-macros-and-build-pipeline.md)와 이어진다.

## 체크리스트

- [ ] `viewModel`, `$viewModel`, `_viewModel`의 타입을 각각 적어 본다.
- [ ] `_viewModel`이 `private`을 우회하는 것이 아님을 한 문장으로 설명한다.
- [ ] 다른 타입에서 `someView._viewModel`에 접근해 보고 어떤 오류가 나는지 확인한다.
- [ ] `init`에서 `self.viewModel = ...`로 바꿔 보고 컴파일 오류 메시지를 읽는다.
- [ ] `State(wrappedValue:)`와 `State(initialValue:)`의 차이를 확인한다.
- [ ] `init`에 `print`를 넣고 화면을 갱신시켜 **`init`은 여러 번 돌지만 `viewModel` 인스턴스는 유지**되는지 확인한다.
- [ ] 부모에서 다른 `steps`를 넘겨 보고 화면이 안 바뀌는 것을 직접 본다.
- [ ] `@State`와 `@StateObject`를 `ObservableObject` 기준으로 구분해 설명한다.
- [ ] 무거운 초기화를 `.task`로 옮기는 공식 대안을 코드로 써 본다.

## 공식 참고 자료

- [SwiftUI: State](https://developer.apple.com/documentation/swiftui/state)
- [SwiftUI: State — init(wrappedValue:)](https://developer.apple.com/documentation/swiftui/state/init(wrappedvalue:))
- [SwiftUI: State — projectedValue](https://developer.apple.com/documentation/swiftui/state/projectedvalue)
- [SwiftUI: Managing user interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)
- [SwiftUI: DynamicProperty](https://developer.apple.com/documentation/swiftui/dynamicproperty)
- [SwiftUI: Migrating from the Observable Object protocol to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [The Swift Programming Language: Properties — Property Wrappers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Property-Wrappers)
- [SE-0258: Property Wrappers](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0258-property-wrappers.md)
