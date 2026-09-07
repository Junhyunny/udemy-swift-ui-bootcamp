# `makeBody`는 override가 아니다 — protocol 요구사항과 style 프로토콜

protocol과 상속의 관계는 [Swift의 타입 체계와 상속 구조](./swift-type-system-and-inheritance.md)에, `@ViewBuilder`는 [`@ViewBuilder` 함수 vs 별도 `View` 구조체](./viewbuilder-vs-view-struct.md)에 있다. 이 문서는 **`LabelStyle`을 구현할 때 무슨 일이 일어나는지**를 다룬다.

## 질문이 나온 코드

`chapter-37/chapter-37/ContentView.swift`의 `struct CustomLabelStyle: LabelStyle { func makeBody(configuration: Configuration) -> some View { ... } }`

## 공부할 내용

### 이건 override가 아니라 **요구사항 구현**이다

용어부터 정리하자. `override`는 **클래스 상속 전용**이다.

> "A subclass can provide its own custom implementation of an instance method, type method, instance property, type property, or subscript that it would otherwise inherit from a superclass. This is known as overriding."
>
> "To override a characteristic that would otherwise be inherited, you prefix your overriding definition with the `override` keyword... any overrides without the `override` keyword are diagnosed as an error when your code is compiled."

즉 override라면 **`override` 키워드가 반드시 붙어야 하고, 없으면 컴파일 오류**다. `makeBody` 앞에 `override`가 없는데도 컴파일된다는 사실 자체가 이것이 override가 아니라는 증거다.

`CustomLabelStyle`은 `struct`이고 상속받은 것이 없다. `: LabelStyle`은 상속이 아니라 **준수(conformance)** 다. protocol은 "이런 걸 갖춰라"는 목록이고, 준수하는 타입이 그 빈칸을 채운다.

> "Protocols can require specific instance methods and type methods to be implemented by conforming types. These methods are written as part of the protocol's definition in exactly the same way as for normal instance and type methods, but **without curly braces or a method body**."

주석에 붙여 둔 선언을 다시 보면 정확히 그 모양이다. 본문(`{ }`)이 없다.

```swift
func makeBody(configuration: Self.Configuration) -> Self.Body
```

**"오버라이드하라고 선언되어 있는건가"에 대한 답**: 오버라이드가 아니라 **"이 함수를 반드시 만들어 달라"는 요구**다. 안 만들면 `Type 'CustomLabelStyle' does not conform to protocol 'LabelStyle'` 오류가 난다.

### `body`를 만들면 되나 — 안 된다

여기가 두 번째 질문이다. **프로토콜마다 요구하는 것이 다르다.**

| 프로토콜 | 요구사항 |
| --- | --- |
| `View` | `var body: Self.Body` |
| `LabelStyle` | `func makeBody(configuration: Self.Configuration) -> Self.Body` |
| `ButtonStyle` | `func makeBody(configuration: Self.Configuration) -> Self.Body` |

`CustomLabelStyle`이 준수하는 것은 `LabelStyle`이지 `View`가 아니다. 그러니 `body` 프로퍼티를 아무리 잘 만들어도 `makeBody`가 없으면 준수가 성립하지 않는다. 컴파일러는 **이름과 시그니처가 정확히 일치하는 멤버**만 요구사항 충족으로 인정한다.

### 왜 `body`가 아니라 `makeBody(configuration:)`인가

이유는 단순하다. **`body`는 파라미터를 받을 수 없기 때문**이다.

`View`의 `body`는 자기 자신이 무엇을 그릴지 이미 알고 있다. 반면 style은 **자기가 무엇을 그릴지 모른다.** `CustomLabelStyle`은 "아이콘 왼쪽, 제목 오른쪽, 배경 둥글게" 같은 **모양의 규칙**일 뿐이고, 실제 내용은 각 `Label`마다 다르다. 그 내용을 받아 와야 하므로 파라미터가 필요하고, 그래서 프로퍼티가 아니라 함수다.

> "The system calls this method for each `Label` instance in a view hierarchy where this style is the current label style."

`.labelStyle(CustomLabelStyle(...))`를 한 번 붙이면, 그 아래 모든 `Label`에 대해 `makeBody`가 **각각 호출된다.** 하나의 스타일 인스턴스가 여러 라벨을 그리는 구조다.

넘어오는 `configuration`이 그 개별 내용이다.

> `LabelStyleConfiguration` — "The properties of a label."
>
> `LabelStyleConfiguration.Title` — "A type-erased title view of a label."
>
> `LabelStyleConfiguration.Icon` — "A type-erased icon view of a label."

**type-erased**라는 점이 중요하다. 스타일 쪽에서는 그것이 `Text`인지 `Image`인지 알 수 없고 알 필요도 없다. 그냥 뷰로 취급해 배치하고 modifier를 걸면 된다. 지금 코드의 `configuration.icon`을 두 번 쓴 것도 가능한 이유다.

### `Configuration`과 `Body`는 어디서 왔나

선언에 있는 `Self.Configuration`과 `Self.Body`는 protocol의 연관 타입이다.

> "An associated type gives a placeholder name to a type that's used as part of the protocol. The actual type to use for that associated type isn't specified until the protocol is adopted."

- **`Configuration`** — `LabelStyle`이 `typealias Configuration = LabelStyleConfiguration`으로 이미 고정해 두었다. 그래서 구현할 때 `configuration: Configuration`이라고 짧게 써도 되고 `LabelStyleConfiguration`이라 길게 써도 된다.
- **`Body`** — `associatedtype Body: View`로 열려 있다. 구현에서 `-> some View`라고 쓰면 컴파일러가 실제 반환 타입을 추론해 `Body`를 채운다. 그래서 `typealias Body = ...`를 직접 쓸 필요가 없다.

선언에 `@ViewBuilder`(현재 SDK에서는 `@ContentBuilder`)가 붙어 있는 것도 눈여겨볼 만하다. 덕분에 `makeBody` 본문에서 뷰를 여러 개 나열하거나 `if`로 분기할 수 있다.

### 같은 패턴이 반복된다

SwiftUI의 스타일 프로토콜은 전부 같은 모양이다.

```swift
struct MyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(configuration.isPressed ? .gray : .blue)
    }
}
```

`ButtonStyle`, `ToggleStyle`, `ProgressViewStyle`, `LabelStyle` 모두 `makeBody(configuration:)` + `Configuration`이다. 하나를 이해하면 나머지가 그대로 따라온다.

**별도 `View` 구조체를 만드는 것과의 차이**도 여기서 드러난다. 스타일은 `.labelStyle(...)`로 **환경에 심어져 하위 계층 전체에 적용**된다. 라벨을 쓰는 쪽 코드는 그대로 두고 모양만 갈아끼울 수 있다. 반면 커스텀 뷰 구조체는 쓰는 자리마다 그 타입으로 바꿔 써야 한다.

## 학습 체크리스트

- [ ] `makeBody` 앞에 `override`를 붙여 보고 어떤 오류가 나는지 읽는다.
- [ ] `makeBody`를 지우고 대신 `var body: some View`를 만들어 준수가 되지 않는 것을 확인한다.
- [ ] 함수 이름을 `makeBodyView`로 바꿔 보고 요구사항 충족이 이름 일치로 판정되는 것을 확인한다.
- [ ] `configuration: Configuration`을 `configuration: LabelStyleConfiguration`으로 바꿔도 동일한지 본다.
- [ ] 주석 처리된 `.labelStyle(CustomLabelStyle(...))`를 살려 두 `List`의 `Label`들이 모두 바뀌는지 확인한다.
- [ ] `List`를 감싸는 상위 뷰에 `.labelStyle`을 걸어 환경으로 전파되는 것을 확인한다.
- [ ] `makeBody` 안에 `print`를 넣어 `Label` 개수만큼 호출되는지 센다.
- [ ] `configuration.title`에 `.font(.largeTitle)`을 걸어 type-erased 뷰에도 modifier가 먹는지 본다.
- [ ] 같은 방식으로 `ButtonStyle`을 구현하고 `configuration.isPressed`를 써 본다.
- [ ] `makeBody`에서 `if`로 분기하는 코드를 작성해 `@ViewBuilder`가 걸려 있음을 확인한다.

## 참고 자료

- [Apple: LabelStyle](https://developer.apple.com/documentation/swiftui/labelstyle)
- [Apple: LabelStyle.makeBody(configuration:)](https://developer.apple.com/documentation/swiftui/labelstyle/makebody(configuration:))
- [Apple: LabelStyleConfiguration](https://developer.apple.com/documentation/swiftui/labelstyleconfiguration)
- [Apple: LabelStyleConfiguration.title](https://developer.apple.com/documentation/swiftui/labelstyleconfiguration/title-swift.property)
- [Apple: LabelStyleConfiguration.icon](https://developer.apple.com/documentation/swiftui/labelstyleconfiguration/icon-swift.property)
- [Apple: View.labelStyle(_:)](https://developer.apple.com/documentation/swiftui/view/labelstyle(_:))
- [Apple: Label](https://developer.apple.com/documentation/swiftui/label)
- [Apple: ButtonStyle](https://developer.apple.com/documentation/swiftui/buttonstyle)
- [Apple: ToggleStyle](https://developer.apple.com/documentation/swiftui/togglestyle)
- [The Swift Programming Language: Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [The Swift Programming Language: Generics — Associated Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [The Swift Programming Language: Inheritance — Overriding](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/inheritance/)
- [The Swift Programming Language: Opaque Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/)
