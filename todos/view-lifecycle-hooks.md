# SwiftUI의 생명주기 — App, Scene, View

UIKit의 `UIViewController` 생명주기와 SwiftUI의 `.task`, `.onAppear`, `.onDisappear`를 큰 구조에서 비교하려면 [SwiftUI와 UIKit 아키텍처 학습 노트](./swiftui-and-uikit-architecture.md)를 함께 본다.

## 질문이 나온 코드

`chapter-32/chapter-32/ContentView.swift`의 `.onAppear { ... }`와 `.onChange(of: todos) { ... }`

## 공부할 내용

### 먼저 짚을 것 — SwiftUI에는 UIKit 같은 "생명주기 콜백 목록"이 없다

`viewDidLoad` / `viewWillAppear` / `viewDidDisappear`처럼 정해진 메서드를 재정의하는 방식이 아니다. SwiftUI의 뷰는 **값(struct)** 이고 화면 갱신 때마다 새로 만들어졌다 버려진다. 그래서 "뷰 인스턴스의 생명주기"라는 개념 자체가 약하고, 대신 **화면에 나타남·사라짐·값 변경 같은 사건에 modifier로 반응**한다.

계층은 세 단계다.

```
App        앱 전체 진입점 (@main)
 └ Scene   창/화면 단위 (WindowGroup 등) — 활성/비활성 상태를 가진다
    └ View 화면 요소 — 나타남/사라짐에 반응
```

`Group`은 이 계층에 속하지 않는다. 여러 뷰를 묶어 modifier를 한 번에 거는 용도이고 생명주기와는 무관하다.

> "A type that collects multiple instances of a content type — like views, scenes, or commands — into a single unit."
>
> "The modifier applies to all members of the group — and not to the group itself."

다만 이 성질 때문에 `Group`에 `onAppear`를 걸면 **그룹 안의 모든 뷰 각각에** 걸린다는 점은 알아 둘 만하다.

### View 단계

**`onAppear(perform:)`** — "Adds an action to perform before this view appears."

> "The exact moment that SwiftUI calls this method depends on the specific view type that you apply it to, but the `action` closure completes before the first rendered frame appears."

**호출 시점이 뷰 종류에 따라 다르다**는 단서가 중요하다. `List`나 `LazyVStack` 안의 행이라면 스크롤로 나타날 때 호출되고, 한 번만 불린다는 보장도 없다. 지금 코드의 `print("rendering first time")`도 화면을 떠났다 돌아오면 다시 찍힌다.

**`onDisappear(perform:)`** — "Adds an action to perform after this view disappears." 이쪽은 사라진 **뒤에** 실행된다.

**`task`** — 비동기 작업용이다. "Adds a task to perform before this view appears or when a specified value changes." `onAppear` + `Task { }` 조합과 달리 **뷰가 사라지면 작업이 자동으로 취소된다.** `id:`를 주면 그 값이 바뀔 때 작업을 취소하고 다시 시작한다. 네트워크 호출처럼 비동기 초기화에는 `onAppear`보다 이쪽이 맞다.

**`onChange(of:initial:_:)`** — 값이 바뀔 때 반응한다.

> `func onChange<V>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View where V : Equatable`
>
> "You can use `onChange` to trigger a side effect as the result of a value changing, such as an `Environment` key or a `Binding`."

감시 대상은 `Equatable`이어야 한다. 지금 코드에서 `onChange(of: todos)`가 되는 것은 `Todo`가 `Hashable`(→ `Equatable`)이고 배열도 그에 따라 `Equatable`이기 때문이다. `initial: true`를 주면 처음 나타날 때도 한 번 실행되므로 `onAppear`와 겹치는 초기화를 하나로 합칠 수 있다.

> "The system may call the action closure on the main actor, so avoid long-running tasks in the closure."

### Scene 단계 — 앱이 앞/뒤로 오갈 때

화면 요소가 아니라 **앱이 활성 상태인지**를 알고 싶으면 `ScenePhase`를 본다.

> "An indication of a scene's operational state."
>
> "The system moves your app's `Scene` instances through phases that reflect a scene's operational state... You can perform actions when the phase changes."

```swift
@Environment(\.scenePhase) private var scenePhase

var body: some View {
    MyContent()
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:     // 앞으로 나옴
            case .inactive:   // 전환 중 / 앱 스위처
            case .background: // 뒤로 감
            @unknown default: break
            }
        }
}
```

> "How you interpret the value depends on where it's read from. If you read the phase from inside a `View` instance, you obtain a value that reflects the phase of the scene that contains the view."

`App`에서 읽으면 앱 전체, `View`에서 읽으면 그 뷰가 속한 scene 기준이라는 차이가 있다. 데이터 저장처럼 "앱이 백그라운드로 갈 때" 해야 하는 일은 `onAppear`가 아니라 여기서 처리한다. 홈으로 나가도 `onDisappear`는 불리지 않기 때문이다.

### App 단계

`@main`이 붙은 `App` 타입이 진입점이고 `body`에 `Scene`을 나열한다. 앱 시작 시 한 번만 할 일은 `App`의 `init()`에 둔다. 여기에도 `@Environment(\.scenePhase)`를 둘 수 있다.

### 요약표

| 하고 싶은 일 | 쓰는 것 | 단계 |
| --- | --- | --- |
| 앱 시작 시 1회 | `App`의 `init()` | App |
| 앱이 앞/뒤로 오갈 때 | `@Environment(\.scenePhase)` + `onChange` | Scene |
| 뷰가 나타날 때 | `onAppear` | View |
| 뷰가 사라진 뒤 | `onDisappear` | View |
| 나타날 때 비동기 작업 (자동 취소) | `task` | View |
| 특정 값이 바뀔 때 | `onChange(of:initial:)` | View |
| 나타남 + 값 변경을 한 번에 | `task(id:)` 또는 `onChange(initial: true)` | View |

### 주의할 점

- `onAppear`는 **한 번만 호출된다고 가정하면 안 된다.** 뷰 종류와 재사용 여부에 따라 여러 번 불린다.
- 앱 종료 직전 처리를 `onDisappear`에 두면 안 된다. `scenePhase`의 `.background`를 쓴다.
- 무거운 작업을 `onAppear`에 두면 첫 프레임이 늦어진다. `action` 클로저가 첫 프레임 전에 끝나기 때문이다. 비동기 작업은 `task`로 옮긴다.

## 학습 체크리스트

- [ ] `onAppear`와 `onDisappear`에 `print`를 넣고, 다른 화면으로 갔다 돌아올 때 몇 번씩 찍히는지 센다.
- [ ] `List`의 각 행에 `onAppear`를 걸고 스크롤하며 호출 시점을 관찰한다.
- [ ] `onChange(of: todos, initial: true)`로 바꿔 `onAppear` 없이도 초기 실행되는지 확인한다.
- [ ] `task { }`에 `try await Task.sleep(...)`을 넣고 화면을 빠져나갈 때 자동 취소되는지 확인한다.
- [ ] `onAppear` + `Task { }` 조합과 `task` 의 취소 동작 차이를 비교한다.
- [ ] `@Environment(\.scenePhase)`를 추가하고 홈 버튼으로 나갔다 돌아오며 각 phase가 언제 찍히는지 기록한다.
- [ ] 그때 `onDisappear`는 호출되지 않는 것을 확인한다.
- [ ] `App`의 `init()`에 `print`를 넣어 몇 번 호출되는지 본다.
- [ ] `Group`으로 뷰 두 개를 묶고 `onAppear`를 걸어 각각 호출되는지 확인한다.

## 참고 자료

- [Apple: View.onAppear(perform:)](https://developer.apple.com/documentation/swiftui/view/onappear(perform:))
- [Apple: View.onDisappear(perform:)](https://developer.apple.com/documentation/swiftui/view/ondisappear(perform:))
- [Apple: View.onChange(of:initial:_:)](https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:))
- [Apple: View.task(id:...)](https://developer.apple.com/documentation/swiftui/view/task(id:name:executorpreference:priority:file:line:_:))
- [Apple: ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase)
- [Apple: EnvironmentValues.scenePhase](https://developer.apple.com/documentation/swiftui/environmentvalues/scenephase)
- [Apple: App](https://developer.apple.com/documentation/swiftui/app)
- [Apple: Scene](https://developer.apple.com/documentation/swiftui/scene)
- [Apple: Group](https://developer.apple.com/documentation/swiftui/group)
- [Apple: View fundamentals](https://developer.apple.com/documentation/swiftui/view-fundamentals)
