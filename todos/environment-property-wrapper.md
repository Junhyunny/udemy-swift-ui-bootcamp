# `@Environment` — 언제 쓰고, 무엇을 받을 수 있는가

## 질문이 나온 코드

`chapter-48/chapter-48/ContentView.swift`

```swift
struct OpenURLExample: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Visit Junhyunny's blog") {
            openURL(
                URL(string: "https://junhyunny.github.io")!
            )
        }
    }
}
```

```swift
struct ExternalLink: View {
    let url: URL
    let label: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: { openURL(url) }) {
            Text(label)
        }
    }
}
```

## 공부할 내용

### 무엇을 하는 래퍼인가

> Use the `Environment` property wrapper to read a value stored in a view's environment. Indicate the value to read using an `EnvironmentValues` key path in the property declaration.

핵심은 **읽기(read)** 다. 뷰 계층 어딘가 위쪽에 놓여 있는 값을 **key path로 꺼내 온다.**

```swift
@Environment(\.colorScheme) var colorScheme: ColorScheme
```

프로퍼티 래퍼이므로 프로퍼티 이름을 그대로 쓰면 감싼 값이 나온다.

```swift
if colorScheme == .dark {   // Checks the wrapped value.
    DarkContent()
} else {
    LightContent()
}
```

`@State`, `@Binding`과 나란히 두면 성격이 분명해진다. 프로퍼티 래퍼 일반과 `$` 문법은 [프로퍼티 래퍼의 `$` 사용 기준](./property-wrapper-dollar-sign.md)에 정리했다.

| 래퍼 | 값의 출처 | 쓰기 |
| --- | --- | --- |
| `@State` | 이 뷰가 소유 | 가능 |
| `@Binding` | 부모가 소유 | 가능 |
| `@Environment` | **뷰 계층 어딘가 위** | **불가** (읽기 전용) |

Apple이 이 제약을 명시한다.

> You can use this property wrapper to read — but not set — an environment value.

### 왜 쓰는가 — prop drilling을 피한다

가장 큰 이유는 **중간 뷰를 거치지 않고 값을 내려보낼 수 있다는 것**이다.

```text
App
 └ ContentView
     └ TabView
         └ NavigationStack
             └ List
                 └ Row
                     └ ExternalLink   ← 여기서 openURL이 필요하다
```

`openURL`을 프로퍼티로 전달하려면 중간의 모든 뷰가 그 값을 받아 넘겨야 한다. 정작 자기들은 쓰지 않는데도 시그니처가 오염된다. `@Environment`는 이 사슬 전체를 건너뛴다.

`ExternalLink`의 시그니처를 보면 효과가 드러난다.

```swift
struct ExternalLink: View {
    let url: URL          // 이 뷰가 실제로 필요한 데이터
    let label: String     // 이 뷰가 실제로 필요한 데이터
    @Environment(\.openURL) private var openURL   // 환경에서 알아서 온다
}
```

`ContentView`는 `ExternalLink(url:label:)`만 넘기면 된다. "URL을 여는 방법"은 시스템이 환경에 넣어 둔 것을 쓴다.

### 값이 바뀌면 뷰가 갱신된다

`@Environment`는 단순 조회가 아니라 **의존성 등록**이다.

> If the value changes, SwiftUI updates any parts of your view that depend on the value. For example, that might happen in the above example if the user changes the Appearance settings.

사용자가 다크 모드로 바꾸거나 글자 크기를 키우면, 그 값을 읽는 뷰만 자동으로 다시 그려진다. 시스템 설정에 반응하는 UI를 별도 코드 없이 만들 수 있는 이유다.

### 어떤 값들을 받을 수 있는가

주입 가능한 값은 `EnvironmentValues` 구조체의 프로퍼티 전체다.

> For the complete list of environment values SwiftUI provides, see the properties of the `EnvironmentValues` structure.

수백 개라 전부 외울 필요는 없고, **범주로 기억**하는 편이 실용적이다. 아래는 `EnvironmentValues` 문서의 분류를 따른 것이다.

**① Actions — 동작을 꺼내 쓴다 (이 예제가 속한 범주)**

값이 아니라 **호출 가능한 동작**이 담겨 있다.

| key path | 용도 |
| --- | --- |
| `\.openURL` | URL 열기 |
| `\.dismiss` | 시트 닫기 / 네비게이션 pop |
| `\.refresh` | pull-to-refresh 동작 |
| `\.openWindow` | 새 창 열기 (macOS/iPadOS) |
| `\.openSettings` | 설정 열기 |
| `\.requestReview` | 앱 리뷰 요청 |
| `\.dismissSearch` | 검색 종료 |
| `\.rename` | 이름 변경 시작 |

**② Display characteristics — 화면 특성**

| key path | 용도 |
| --- | --- |
| `\.colorScheme` | 라이트/다크 모드 |
| `\.horizontalSizeClass`, `\.verticalSizeClass` | compact/regular — 아이폰·아이패드 분기 |
| `\.displayScale` | 화면 배율 (2x, 3x) |
| `\.colorSchemeContrast` | 고대비 여부 |
| `\.imageScale` | 이미지 크기 |

**③ Text styles — 글자 관련**

`\.font`, `\.lineLimit`, `\.lineSpacing`, `\.dynamicTypeSize`, `\.layoutDirection`, `\.multilineTextAlignment`, `\.truncationMode`

`\.layoutDirection`은 [좌표 공간 문서](./coordinate-space-local-global-named.md)에서 다룬 RTL 대응과 이어진다.

**④ State — 현재 상태**

| key path | 용도 |
| --- | --- |
| `\.isEnabled` | 활성/비활성 (기본값 `true`) |
| `\.scenePhase` | active / inactive / background |
| `\.editMode` | 리스트 편집 모드 |
| `\.isSearching` | 검색 중인지 |
| `\.isPresented` | 현재 표시 중인지 |
| `\.isFocused` | 포커스 여부 |

`\.scenePhase`는 [생명주기 문서](./view-lifecycle-hooks.md)에서 다룬 앱 상태 전환과 직결된다.

**⑤ Global objects — 시스템 객체**

`\.locale`, `\.calendar`, `\.timeZone`, `\.undoManager`, `\.modelContext`(SwiftData), `\.managedObjectContext`(Core Data)

**⑥ Accessibility — 접근성 설정**

`\.accessibilityReduceMotion`, `\.accessibilityVoiceOverEnabled`, `\.accessibilityReduceTransparency`, `\.accessibilityDifferentiateWithoutColor`, `\.legibilityWeight`

애니메이션을 줄여야 하는 사용자를 배려하는 코드가 대표적이다.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

.animation(reduceMotion ? nil : .spring(), value: selected)
```

**⑦ View attributes / Scrolling / Widgets**

`\.symbolRenderingMode`([관련 문서](./symbol-rendering-mode.md)), `\.redactionReasons`, `\.isScrollEnabled`, `\.widgetFamily` 등.

### 가장 많이 쓰이는 케이스 정리

실무 빈도로 추리면 대체로 이 순서다.

**1. `\.dismiss` — 시트·네비게이션 닫기**

아마 가장 흔하다.

```swift
private struct SheetContents: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Done") {
            dismiss()
        }
    }
}
```

> You can use this action to:
> - Dismiss a modal presentation, like a sheet or a popover.
> - Pop the current view from a `NavigationStack`.

**함정이 하나 있다.** `dismiss`는 **선언한 위치의 환경**을 기준으로 동작한다.

```swift
private struct DetailView: View {
    @State private var isSheetPresented = false
    @Environment(\.dismiss) private var dismiss // Applies to DetailView.

    var body: some View {
        Button("Show Sheet") { isSheetPresented = true }
        .sheet(isPresented: $isSheetPresented) {
            Button("Done") {
                dismiss() // Fails to dismiss the sheet.
            }
        }
    }
}
```

> If you do this, the sheet fails to dismiss because the action applies to the environment where you declared it, which is that of the detail view, rather than the sheet. In fact, in macOS and iPadOS, if the `DetailView` is the root view of a window, the dismiss action closes the window instead.

**닫으려는 뷰 안에서 선언해야 한다.** 이 예제의 `ExternalLink`가 자기 안에서 `openURL`을 선언한 것과 같은 원칙이다.

**2. `\.colorScheme` — 다크 모드 분기**

```swift
@Environment(\.colorScheme) private var colorScheme

var shadowColor: Color {
    colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.2)
}
```

**3. `\.horizontalSizeClass` — 기기·방향별 레이아웃**

```swift
@Environment(\.horizontalSizeClass) private var sizeClass

var body: some View {
    if sizeClass == .compact {
        VStack { content }
    } else {
        HStack { content }
    }
}
```

**4. `\.openURL` — 이 예제**

**5. `\.isEnabled` — 커스텀 컴포넌트가 비활성 상태를 반영**

부모가 `.disabled(true)`를 걸면 자식이 그 사실을 읽는다.

```swift
struct FancyButton: View {
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Text("Tap")
            .opacity(isEnabled ? 1.0 : 0.4)
    }
}
```

**6. `\.scenePhase` — 앱 상태 전환 시 저장/정리**

**7. `\.modelContext` / `\.managedObjectContext` — 데이터 저장소 접근**

**8. `\.locale`, `\.calendar` — 지역화 대응 포매팅**

### `\.openURL`을 좀 더 들여다보기

이 예제가 쓰는 값의 타입은 `OpenURLAction`이다.

```swift
@MainActor @preconcurrency var openURL: OpenURLAction { get set }
```

`openURL(url)`처럼 **변수를 함수처럼 호출**할 수 있는 이유가 있다.

> You call the instance directly because it defines a `callAsFunction(_:)` method that Swift calls when you call the instance.

Swift의 `callAsFunction` 기능이다. `dismiss()`, `refresh()`도 같은 방식이다.

**성공 여부를 알고 싶다면** 완료 핸들러를 붙인다.

```swift
openURL(url) { accepted in
    print(accepted ? "Success" : "Failure")
}
```

**기본 동작**은 이렇다.

> The system provides a default open URL action with behavior that depends on the contents of the URL. For example, the default action opens a Universal Link in the associated app if possible, or in the user's default web browser if not.

**동작을 가로챌 수도 있다.** 여기가 `@Environment`의 진짜 강력한 부분이다.

```swift
Text("Visit [Example Company](https://www.example.com) for details.")
    .environment(\.openURL, OpenURLAction { url in
        handleURL(url) // Define this method to take appropriate action.
        return .handled
    })
```

> Any views that read the action from the environment, including the built-in `Link` view and `Text` views with markdown links, or links in attributed strings, use your action.

즉 앱 내부 브라우저로 열거나 딥링크를 가로채는 처리를 **한 곳에서** 바꿀 수 있다. 이 예제의 두 뷰도 코드를 전혀 고치지 않고 동작만 바뀐다.

### 값을 넣는 쪽 — `environment(_:_:)`

읽기가 `@Environment`라면, 쓰기는 `environment(_:_:)` modifier다.

```swift
MyView()
    .environment(\.lineLimit, 2)
```

> The value that you set affects the environment for the view that you modify — including its descendants in the view hierarchy — but only up to the point where you apply a different environment modifier.
>
> This modifier affects the given view, as well as that view's descendant views. It has no effect outside the view hierarchy on which you call it.

**아래로만 흐르고, 더 안쪽에서 덮어쓸 수 있다.** [PreferenceKey](./preference-key-and-onpreferencechange.md)가 자식→조상인 것과 정확히 반대 방향이다.

```text
environment  : 조상 → 자손  (위에서 아래로)
preference   : 자손 → 조상  (아래에서 위로)
```

**전용 modifier가 있으면 그쪽을 쓴다.**

> SwiftUI provides dedicated view modifiers for setting some values, which typically makes your code easier to read. For example, rather than setting the `lineLimit` value directly, as in the previous example, you should instead use the `lineLimit(_:)` modifier.

```swift
MyView().environment(\.lineLimit, 2)   // 가능하지만
MyView().lineLimit(2)                   // 이쪽이 권장
```

전용 modifier가 추가 동작을 하는 경우도 있다.

> For example, you must use the `preferredColorScheme(_:)` modifier rather than setting `colorScheme` directly to ensure that the new value propagates up to the presenting container when presenting a view like a popover.

### 커스텀 환경 값 만들기 — `@Entry`

내 값도 환경에 실을 수 있다. 예전에는 `EnvironmentKey`를 직접 구현해야 했지만, 지금은 매크로 한 줄이면 된다.

```swift
extension EnvironmentValues {
    @Entry var myCustomValue: String = "Default value"
    @Entry var anotherCustomValue = true
}

extension View {
    func myCustomValue(_ myCustomValue: String) -> some View {
        environment(\.myCustomValue, myCustomValue)
    }
}
```

`extension View`로 전용 modifier를 함께 제공하는 것이 관용적이다. Apple도 그렇게 권한다.

> Prefer the dedicated modifier when available, and offer your own when defining custom environment values.

`extension`의 적용 범위와 파일 관리 이야기는 [extension 문서](./extension-keyword.md)에 정리했다.

### 객체를 환경에 넣기 — `@Observable`과 함께

`@Environment`는 key path뿐 아니라 **타입 자체**로도 객체를 꺼낼 수 있다.

```swift
@Observable
class Library {
    var books: [Book] = [Book(), Book(), Book()]
    var availableBooksCount: Int { books.filter(\.isAvailable).count }
}

@main
struct BookReaderApp: App {
    @State private var library = Library()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
        }
    }
}
```

```swift
struct LibraryView: View {
    @Environment(Library.self) private var library
    var body: some View { /* ... */ }
}
```

**주의점이 있다.** 객체가 환경에 없으면 크래시한다.

> By default, reading an object from the environment returns a non-optional object when using the object type as the key. This default behavior assumes that a view in the current hierarchy previously stored a non-optional instance of the type using the `environment(_:)` modifier. If a view attempts to retrieve an object using its type and that object isn't in the environment, SwiftUI throws an exception.

보장할 수 없다면 옵셔널로 받는다.

```swift
@Environment(Library.self) private var library: Library?
```

`@EnvironmentObject`는 구형 API다. Apple의 안내가 명확하다.

> If your observable object conforms to the `Observable` protocol, use `Environment` instead of `EnvironmentObject` and set the model object in an ancestor view by calling its `environment(_:)` or `environment(_:_:)` modifiers.

### 언제 쓰지 말아야 하는가

- **이 뷰만 쓰는 값** — 프로퍼티로 직접 전달한다. 환경은 암묵적 의존성이라 추적이 어렵다.
- **자주 바뀌는 값** — 읽는 모든 뷰가 갱신된다. 범위가 넓으면 비용이 커진다.
- **필수 데이터** — 환경 값은 "없으면 기본값"이 전제다. 반드시 있어야 하는 데이터는 프로퍼티로 강제하는 편이 안전하다. 객체 주입 시 크래시하는 것도 이 때문이다.
- **양방향이 필요할 때** — 읽기 전용이므로 `@Binding`이나 `@Observable` 객체를 쓴다.

### 정리

```text
@Environment(\.keyPath)   조상이 심어 둔 값을 읽는다 (읽기 전용)
        ↑
environment(\.keyPath, v) 조상이 값을 심는다 (자손 전체에 적용)

주요 범주: Actions / Display / Text / State / Global objects / Accessibility
가장 흔한 것: dismiss, colorScheme, horizontalSizeClass, openURL, isEnabled
함정: dismiss는 "선언한 위치"의 환경을 기준으로 동작한다
```

## 학습 체크리스트

- [ ] `\.openURL`에 완료 핸들러를 붙여 성공·실패를 콘솔에 찍는다.
- [ ] `.environment(\.openURL, OpenURLAction { ... })`로 동작을 가로채고 두 뷰가 모두 영향받는지 확인한다.
- [ ] `URL(string:)!`의 강제 언래핑을 `if let`으로 바꿔 안전하게 만든다.
- [ ] `@Environment(\.colorScheme)`을 읽어 다크 모드에서 색이 바뀌는 뷰를 만든다.
- [ ] 시스템 설정을 바꿔 값 변경만으로 뷰가 갱신되는 것을 확인한다.
- [ ] 시트를 띄우고 `\.dismiss`로 닫아 본다.
- [ ] `dismiss`를 부모 뷰에서 선언해 시트가 닫히지 않는 함정을 재현한다.
- [ ] `\.horizontalSizeClass`로 아이폰 세로·가로에서 레이아웃을 분기한다.
- [ ] 부모에 `.disabled(true)`를 걸고 자식이 `\.isEnabled`로 읽는지 확인한다.
- [ ] `.environment(\.lineLimit, 2)`와 `.lineLimit(2)`의 결과를 비교한다.
- [ ] 같은 값을 서로 다른 깊이에서 두 번 설정해 안쪽이 이기는 것을 확인한다.
- [ ] `@Entry`로 커스텀 환경 값을 만들고 전용 modifier까지 제공한다.
- [ ] `@Observable` 객체를 `.environment(...)`로 주입하고 자손에서 꺼내 쓴다.
- [ ] 주입하지 않은 상태에서 객체를 읽어 크래시를 확인한 뒤 옵셔널로 바꾼다.
- [ ] `\.accessibilityReduceMotion`을 읽어 애니메이션을 끄는 코드를 작성한다.
- [ ] environment(위→아래)와 preference(아래→위)의 방향 차이를 한 문장으로 정리한다.

## 공식 참고 자료

- [Apple: Environment](https://developer.apple.com/documentation/swiftui/environment)
- [Apple: EnvironmentValues](https://developer.apple.com/documentation/swiftui/environmentvalues)
- [Apple: EnvironmentValues.openURL](https://developer.apple.com/documentation/swiftui/environmentvalues/openurl)
- [Apple: OpenURLAction](https://developer.apple.com/documentation/swiftui/openurlaction)
- [Apple: EnvironmentValues.dismiss](https://developer.apple.com/documentation/swiftui/environmentvalues/dismiss)
- [Apple: EnvironmentValues.colorScheme](https://developer.apple.com/documentation/swiftui/environmentvalues/colorscheme)
- [Apple: EnvironmentValues.horizontalSizeClass](https://developer.apple.com/documentation/swiftui/environmentvalues/horizontalsizeclass)
- [Apple: EnvironmentValues.isEnabled](https://developer.apple.com/documentation/swiftui/environmentvalues/isenabled)
- [Apple: EnvironmentValues.scenePhase](https://developer.apple.com/documentation/swiftui/environmentvalues/scenephase)
- [Apple: view.environment(_:_:)](https://developer.apple.com/documentation/swiftui/view/environment(_:_:))
- [Apple: Entry() 매크로](https://developer.apple.com/documentation/swiftui/entry())
- [Apple: EnvironmentKey](https://developer.apple.com/documentation/swiftui/environmentkey)
- [Apple: EnvironmentObject (구형 API)](https://developer.apple.com/documentation/swiftui/environmentobject)
- [Apple: Link](https://developer.apple.com/documentation/swiftui/link)
