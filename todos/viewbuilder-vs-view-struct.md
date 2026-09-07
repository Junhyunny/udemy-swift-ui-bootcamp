# `@ViewBuilder` 함수 vs 별도 `View` 구조체

`@ViewBuilder`가 result builder라는 배경은 [`ComponentName { }`의 정체](./closures-and-view-builders.md)에 있다. 이 문서는 **화면 조각을 분리할 때 둘 중 무엇을 고를지**에 집중한다.

## 질문이 나온 코드

`chapter-36/chapter-36/ContentView.swift`의 `@ViewBuilder func buttonBody(isUp: Bool) -> some View`

## 공부할 내용

### `@ViewBuilder`를 함수에 붙이면 무엇이 달라지나

> "A custom parameter attribute that constructs views from closures."
>
> `@resultBuilder struct ViewBuilder`

붙이지 않으면 함수 본문은 **평범한 Swift 함수 본문**이다. `some View`를 반환해야 하므로 뷰를 하나만, `return`으로 돌려줘야 한다.

```swift
func buttonBody(isUp: Bool) -> some View {
    Image(systemName: "...")
    Text("Tap to count")     // 오류: 값을 두 개 반환할 수 없다
}
```

`@ViewBuilder`를 붙이면 본문이 **뷰를 조립하는 블록**으로 해석된다. 여러 개를 나열하면 암묵적으로 묶이고, `if`/`switch`로 분기해도 된다.

```swift
@ViewBuilder
func label(isUp: Bool) -> some View {
    if isUp { Text("Up") } else { Text("Down") }   // 타입이 달라도 된다
}
```

`@ViewBuilder` 없이 `if`/`else`로 서로 다른 타입을 반환하려면 `AnyView`로 지워야 하는데, 그건 성능과 타입 정보 모두 손해다.

지금 코드의 `buttonBody`는 사실 최상위가 `VStack` 하나라서 `@ViewBuilder`가 없어도 컴파일된다. 붙여 두면 나중에 분기를 추가할 때 자유롭다는 정도의 이점이다.

### `@ViewBuilder`의 두 가지 쓰임새

**1. 함수·계산 프로퍼티에 붙이기** — 지금 코드처럼 `body`가 길어질 때 조각을 잘라 두는 용도다.

**2. 파라미터에 붙이기** — 내가 만든 컨테이너가 `{ }` 문법을 받게 하는 용도다. 이게 원래 목적이다.

```swift
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack { content }
            .background(.gray.opacity(0.2), in: .rect(cornerRadius: 12))
    }
}

Card {
    Text("제목")
    Text("본문")
}
```

`VStack`, `Button`이 `{ }`를 받는 것과 똑같은 방식이다. 실제 `Button` 선언에도 `@ContentBuilder label: () -> Label`이 들어 있다.

### 별도 `View` 구조체와의 차이 — 여기가 핵심

`View`는 **타입**이다.

> "You create custom views by declaring types that conform to the `View` protocol. Implement the required `body` computed property to provide the content for your custom view."

`@ViewBuilder` 함수는 **부모 뷰에 딸린 메서드**일 뿐이다. 이 차이에서 나머지가 전부 따라 나온다.

| | `@ViewBuilder` 함수 | 별도 `View` 구조체 |
| --- | --- | --- |
| 자체 `@State` | **불가** | 가능 |
| 재사용 범위 | 그 타입 안 (`private`) | 어디서나 |
| `#Preview` 단독 | 어려움 | 쉬움 |
| modifier 부착 | 호출부에서 가능 | 가능 |
| 부모 상태 접근 | 그냥 됨 | 파라미터/바인딩으로 전달 |
| 코드량 | 적음 | 선언이 하나 늘어남 |

**가장 결정적인 것은 상태 소유 여부다.** `@State`는 `App`, `Scene`, `View`에 선언하는 것이지 함수 안에 둘 수 없다. 그러니 그 조각이 자기만의 상태(펼침 여부, 애니메이션 진행도 등)를 가져야 한다면 **선택지가 없다. 구조체로 만들어야 한다.**

두 번째로 중요한 것은 갱신 단위다.

> "SwiftUI reads the value of this property any time it needs to update the view, which can happen repeatedly during the life of the view, typically in response to user input or system events."

`@ViewBuilder` 함수의 내용은 **부모의 `body`가 실행될 때마다 함께 다시 평가된다.** 부모 `body`의 일부이기 때문이다. 반면 별도 구조체는 자기 `body`를 가진 독립된 뷰라 SwiftUI가 그 단위로 identity와 갱신을 관리한다. 화면이 커질수록 이 차이가 의미를 갖는다.

### 어떻게 고를까

**`@ViewBuilder` 함수가 맞는 경우**

- `body`가 길어져서 읽기 힘들 때 잘라내는 용도
- 그 조각이 부모 상태를 여러 개 읽고, 자기 상태는 없을 때
- 그 뷰 안에서만 쓰이고 밖으로 나갈 일이 없을 때

지금 코드의 `buttonBody(isUp:)`가 딱 이 경우다. `isUp` 하나로 모양만 바꾸고 자체 상태가 없다.

**별도 구조체가 맞는 경우**

- 자체 `@State`가 필요할 때
- 두 곳 이상에서 쓸 때
- 프리뷰나 테스트로 따로 확인하고 싶을 때
- 파라미터가 늘어나 함수 시그니처가 지저분해질 때

**`@ViewBuilder` 파라미터가 맞는 경우**

- 내용물을 호출자가 채우는 **컨테이너**를 만들 때

경험칙 하나 — **자체 상태가 생기는 순간 구조체로 옮긴다.** 그 전까지는 함수로 두어도 충분하고, 나중에 구조체로 승격하는 것도 어렵지 않다.

## 학습 체크리스트

- [ ] `buttonBody`에서 `@ViewBuilder`를 지우고 그대로 컴파일되는지 확인한다(최상위가 `VStack` 하나라 된다).
- [ ] 본문을 `Image`와 `Text` 두 개로 바꿔 `@ViewBuilder` 없이는 컴파일되지 않는 것을 확인한다.
- [ ] `if isUp { Text("Up") } else { Image(systemName: "x") }`처럼 타입이 다른 분기를 넣어 본다.
- [ ] `@ViewBuilder` 없이 같은 분기를 `AnyView`로 처리해 보고 코드가 어떻게 지저분해지는지 비교한다.
- [ ] `buttonBody` 안에 `@State`를 선언해 보고 왜 안 되는지 확인한다.
- [ ] `buttonBody`를 `struct ButtonBody: View`로 옮기고 `isUp`을 프로퍼티로 받게 바꾼다.
- [ ] 그 구조체에 `@State`를 추가해 자체 상태를 갖게 만든다.
- [ ] 구조체 버전에 `#Preview`를 따로 붙여 단독 미리보기가 되는지 확인한다.
- [ ] `@ViewBuilder` 파라미터를 받는 `Card` 컨테이너를 만들어 `Card { ... }`로 호출한다.
- [ ] 부모 `body`에 `print`를 넣고, 함수 버전과 구조체 버전에서 재평가 시점이 어떻게 다른지 관찰한다.

## 참고 자료

- [Apple: ViewBuilder](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Apple: ContentBuilder](https://developer.apple.com/documentation/swiftui/contentbuilder)
- [Apple: View](https://developer.apple.com/documentation/swiftui/view)
- [Apple: Declaring a custom view](https://developer.apple.com/documentation/swiftui/declaring-a-custom-view)
- [Apple: View fundamentals](https://developer.apple.com/documentation/swiftui/view-fundamentals)
- [Apple: State](https://developer.apple.com/documentation/swiftui/state)
- [Apple: ViewModifier](https://developer.apple.com/documentation/swiftui/viewmodifier)
- [Apple: AnyView](https://developer.apple.com/documentation/swiftui/anyview)
- [WWDC21: Demystify SwiftUI (identity와 lifetime)](https://developer.apple.com/videos/play/wwdc2021/10022/)
- [The Swift Programming Language: Opaque Types (`some View`)](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/)
- [The Swift Programming Language: Advanced Operators — Result Builders](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/)
