# `ViewModifier` 프로토콜과 `modifier(_:)` — 재사용 가능한 수식어 만들기

## 질문이 나온 코드

`chapter-47/chapter-47/ContentView.swift`

```swift
struct MeasuringSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: SizePreferenceKey.self,
                        value: proxy.size
                    )
            }
        )
    }
}
```

```swift
extension View {
    func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
        modifier(MeasuringSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}
```

`modifier(...)`가 갑자기 등장하는데, 이건 어디서 온 함수인가?

## 공부할 내용

### 용도 — 여러 modifier의 묶음에 이름을 붙인다

`.font`, `.padding`, `.background` 같은 modifier를 매번 같은 조합으로 반복해 쓰게 될 때, 그 조합 자체를 하나의 재사용 단위로 만드는 것이 `ViewModifier`다.

Apple 문서의 설명과 예제가 그대로다.

> Adopt the `ViewModifier` protocol when you want to create a reusable modifier that you can apply to any view. The example below combines several modifiers to create a new modifier that you can use to create blue caption text surrounded by a rounded rectangle:

```swift
struct BorderedCaption: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .padding(10)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(lineWidth: 1)
            )
            .foregroundColor(Color.blue)
    }
}
```

핵심 단어가 **`any view`** 다. 특정 뷰가 아니라 **어떤 뷰에든 적용 가능한** 변형을 정의한다.

### 프로토콜의 구조

```swift
@MainActor @preconcurrency protocol ViewModifier {
    associatedtype Body : View
    typealias Content
    @ViewBuilder func body(content: Self.Content) -> Self.Body
}
```

구현해야 할 것은 `body(content:)` 하나다.

```swift
@ContentBuilder @MainActor @preconcurrency
func body(content: Self.Content) -> Self.Body
```

`content` 파라미터의 정체가 중요하다.

> `content` is a proxy for the view that will have the modifier represented by `Self` applied to it.

즉 `content`는 **이 modifier가 적용될 원래 뷰의 대역**이다. 실제 뷰 타입이 무엇인지는 알 필요가 없다. `Content`가 `typealias`로 선언된 불투명한 자리 표시자인 이유다. 덕분에 `Text`에 붙이든 `Image`에 붙이든 같은 코드가 동작한다.

`body`에 `@ViewBuilder`가 붙어 있어서 `if`/`switch`로 분기하는 것도 가능하다. `@ViewBuilder`의 원리는 [클로저와 view builder](./closures-and-view-builders.md)에 있다.

`View` 프로토콜과 나란히 놓고 보면 형태가 닮았다.

| | `View` | `ViewModifier` |
| --- | --- | --- |
| 요구사항 | `var body: Body` | `func body(content: Content) -> Body` |
| 입력 | 없음 (자기 프로퍼티만) | 원래 뷰 (`content`) |
| 의미 | 뷰를 **만든다** | 뷰를 **감싼다** |

`ViewModifier`는 함수처럼 "뷰를 받아 뷰를 돌려주는" 변환이다.

### `modifier(_:)`는 어디서 왔는가

질문에 대한 답은 명확하다. **`View` 프로토콜의 메서드다.**

```swift
nonisolated func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T>
```

`extension View { ... }` 안에서는 `self`가 곧 `View`이므로, `self.modifier(...)`의 `self.`를 생략한 것이 예제의 `modifier(MeasuringSizeModifier())`다.

```swift
extension View {
    func measureSzie(...) -> some View {
        modifier(MeasuringSizeModifier())        // == self.modifier(...)
    }
}
```

`extension`으로 `View`에 메서드를 붙이는 것이 왜 되는지는 [extension 문서](./extension-keyword.md)에서 다룬다.

Apple 문서는 이 메서드의 용도를 이렇게 설명한다.

> Use this modifier to combine a `View` and a `ViewModifier`, to create a new view.

반환 타입 `ModifiedContent<Self, T>`도 눈여겨볼 만하다. **원래 뷰 타입과 modifier 타입을 둘 다 품은 새 타입**이 만들어진다. SwiftUI가 modifier를 붙일 때마다 타입이 중첩되어 커지는 구조가 여기서 드러난다. `some View`로 감싸는 이유이기도 하다.

```text
Text("Hi")
  .modifier(A())        →  ModifiedContent<Text, A>
  .modifier(B())        →  ModifiedContent<ModifiedContent<Text, A>, B>
```

### 왜 `extension View`로 감싸는가

`ViewModifier`를 만든 다음에는 보통 `View` extension을 하나 더 만든다. Apple도 이 방식을 권한다.

> You can apply `ViewModifier` directly to a view, but a more common and idiomatic approach uses `ViewModifier` to define an extension to `View` itself that incorporates the view modifier:

```swift
extension View {
    func borderedCaption() -> some View {
        modifier(BorderedCaption())
    }
}
```

```swift
Text("Downtown Bus")
    .borderedCaption()
```

이유는 **호출부 가독성**이다.

```swift
// extension 없이
Text("...").modifier(MeasuringSizeModifier())

// extension으로
Text("...").measureSzie { size in viewSize = size }
```

내장 modifier와 똑같은 모양이 되어 자연스럽게 체이닝된다.

예제의 extension이 한 걸음 더 나가는 부분도 있다. **modifier 적용과 콜백 연결을 한 번에 묶는다.**

```swift
func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
    modifier(MeasuringSizeModifier())
        .onPreferenceChange(SizePreferenceKey.self, perform: action)
}
```

`MeasuringSizeModifier`는 값을 **올려 보내는** 일만 하고, extension이 그것을 **받는** 쪽까지 배선한다. 사용하는 사람은 내부에 preference 시스템이 있다는 사실을 몰라도 된다. 이 흐름은 [PreferenceKey 문서](./preference-key-and-onpreferencechange.md)에 정리했다.

`@escaping`이 필요한 이유도 여기에 있다. `action`은 `onPreferenceChange`에 저장되어 값이 바뀔 때마다 나중에 불린다.

### 언제 쓰는가

**써야 할 때**

- 같은 modifier 조합이 **세 곳 이상** 반복될 때
- 스타일을 한곳에서 관리하고 싶을 때 (카드 스타일, 캡션 스타일)
- `content`를 감싸는 **동작**을 재사용할 때 — 이 예제의 크기 측정처럼
- 상태를 가진 변형이 필요할 때 (아래 참조)

**`ViewModifier`가 상태를 가질 수 있다는 점이 강점이다.**

```swift
struct Shake: ViewModifier {
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onAppear { /* 애니메이션 */ }
    }
}
```

`@State`, `@Environment`를 그대로 쓸 수 있다. 단순 함수로는 못 하는 일이다.

**안 써도 될 때**

- 단순히 modifier 두세 개를 잇는 정도이고 상태가 없다면, `View` extension만으로 충분하다.

  ```swift
  extension View {
      func cardStyle() -> some View {
          self.padding()
              .background(.white)
              .clipShape(.rect(cornerRadius: 12))
      }
  }
  ```

  `ViewModifier` 타입을 따로 만들 필요가 없다.

- **내용을 새로 구성**하는 것이 목적이라면 별도 `View` 구조체가 맞다. `ViewModifier`는 받은 뷰를 감싸는 용도다. 이 판단 기준은 [ViewBuilder 함수 vs View 구조체](./viewbuilder-vs-view-struct.md)와 같은 결이다.

### 주의점

**1. `content`를 반드시 사용한다**

`content`를 쓰지 않으면 원래 뷰가 사라진다. modifier가 아니라 대체가 되어 버린다.

```swift
func body(content: Content) -> some View {
    Text("고정")     // ⚠️ content가 버려진다
}
```

**2. modifier 순서가 결과를 바꾼다**

```swift
Text("Hi").padding().background(.red)   // 패딩까지 빨강
Text("Hi").background(.red).padding()   // 글자만 빨강
```

`ModifiedContent`가 중첩되는 구조를 생각하면 당연한 결과다. 커스텀 modifier 안에서도 순서를 신중히 정한다.

**3. 레이아웃에 영향을 주는지 확인한다**

이 예제가 `background` 안에서 측정하는 이유가 그것이다. `body`에서 `content`를 감싸는 방식에 따라 크기와 위치가 달라질 수 있다. 측정·관찰 목적의 modifier는 **레이아웃을 바꾸지 않는 자리**에 붙인다.

**4. `@MainActor` 격리**

> A type conforming to this protocol inherits `@preconcurrency @MainActor` isolation from the protocol if the conformance is included in the type's base declaration.

기본 선언에서 채택하면 자동으로 main actor에 격리된다. 벗어나려면 extension으로 채택을 분리해야 한다.

> Isolation to the main actor is the default, but it's not required. Declare the conformance in an extension to opt out of main actor isolation.

**5. 무거운 작업을 넣지 않는다**

`body`는 렌더링마다 호출된다. `GeometryReader`처럼 비용이 있는 것을 넣을 때는 주의한다. [GeometryReader와 성능](./geometry-reader-performance.md)에 정리했다.

**6. 이름 오타는 그대로 API가 된다**

예제의 `measureSzie`는 `measureSize`의 오타다. `View`의 모든 뷰에 노출되는 공개 이름이므로, extension으로 API를 만들 때는 이름을 신중히 정한다.

### 정리

```text
ViewModifier          "어떤 뷰든 이렇게 감싼다"는 변형의 정의
   ↓ modifier(_:)     View 프로토콜의 메서드. 뷰 + modifier → ModifiedContent
   ↓ extension View   호출부를 .measureSzie { } 처럼 자연스럽게
```

## 학습 체크리스트

- [ ] `MeasuringSizeModifier`를 `Text`가 아닌 `Image`에도 적용해 `Content`가 뷰 종류를 안 가리는 것을 확인한다.
- [ ] `body`에서 `content`를 쓰지 않고 다른 뷰를 반환해 원래 뷰가 사라지는 것을 확인한다.
- [ ] `modifier(MeasuringSizeModifier())`를 `self.modifier(...)`로 바꿔 같은 코드임을 확인한다.
- [ ] `.modifier(A()).modifier(B())`의 타입을 `print(type(of:))`로 찍어 `ModifiedContent` 중첩을 본다.
- [ ] `measureSzie` extension 없이 `.modifier(...)` + `.onPreferenceChange(...)`를 직접 써 보고 가독성을 비교한다.
- [ ] Apple의 `BorderedCaption` 예제를 그대로 만들어 `.borderedCaption()`으로 적용해 본다.
- [ ] `@State`를 가진 `ViewModifier`를 만들어 상태를 가질 수 있음을 확인한다.
- [ ] 같은 스타일을 `ViewModifier`와 `View` extension 두 방식으로 만들고 어느 쪽이 적절한지 판단한다.
- [ ] `padding().background()`와 `background().padding()`의 결과 차이를 눈으로 확인한다.
- [ ] `measureSzie`의 오타를 `measureSize`로 고치고 호출부가 함께 바뀌는 범위를 확인한다.

## 공식 참고 자료

- [Apple: ViewModifier](https://developer.apple.com/documentation/swiftui/viewmodifier)
- [Apple: ViewModifier.body(content:)](https://developer.apple.com/documentation/swiftui/viewmodifier/body(content:))
- [Apple: ViewModifier.Content](https://developer.apple.com/documentation/swiftui/viewmodifier/content)
- [Apple: view.modifier(_:)](https://developer.apple.com/documentation/swiftui/view/modifier(_:))
- [Apple: ModifiedContent](https://developer.apple.com/documentation/swiftui/modifiedcontent)
- [Apple: View](https://developer.apple.com/documentation/swiftui/view)
- [Apple: ViewBuilder](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Swift 공식 문서: Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
