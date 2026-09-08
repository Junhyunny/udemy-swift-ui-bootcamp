# `some` 키워드 — opaque type과 함께 공부할 개념들

## 질문이 나온 코드

`chapter-60/chapter-60/ContentView.swift`

```swift
struct DestinationView: View {
    @Environment(\.dismiss) var dismiss
    var title: String

    var body: some View {
        Text(title)
            .navigationBarBackButtonHidden()
            .onTapGesture { dismiss() }
    }
}
```

SwiftUI 뷰를 만들 때마다 `some View`를 쓰는데, `some`은 무엇인가.

## 공부할 내용

### 결론 먼저

- `some View`는 **"`View`를 만족하는 어떤 하나의 구체 타입"** 을 뜻한다. 무엇인지는 **컴파일러만 알고 호출하는 쪽은 모른다.**
- 이것을 **opaque type(불투명 타입)** 이라 부른다.
- `View` 프로토콜을 그냥 쓸 수 없는 이유는 `associatedtype`을 갖기 때문이다.
- `any View`(boxed protocol type)와는 다르다. **`some`은 타입 신원을 유지하고 `any`는 유지하지 않는다.**

### 왜 `some`이 필요한가 — `View` 프로토콜을 그대로 못 쓴다

`View` 프로토콜의 선언을 보면 이유가 보인다.

```swift
protocol View {
    associatedtype Body : View
    @ViewBuilder var body: Self.Body { get }
}
```

`Body`가 `associatedtype`이다. 즉 **구현하는 타입마다 `body`의 타입이 다르다.** [typealias와 associatedtype 문서](./typealias-and-associated-type.md)에서 다룬 자리 표시자다.

그럼 `body`의 타입을 뭐라고 적어야 할까? 실제 타입은 이런 모양이다.

```swift
// chapter-60의 DestinationView.body의 실제 타입
ModifiedContent<ModifiedContent<Text, _NavigationBarBackButtonHiddenModifier>, _AddGestureModifier<TapGesture>>
```

modifier를 하나 붙일 때마다 `ModifiedContent`가 중첩되어 타입이 길어진다. [ViewModifier 문서](./view-modifier-protocol.md)에서 본 구조다.

이걸 직접 적으라면 이렇게 된다.

```swift
var body: ModifiedContent<ModifiedContent<Text, ...>, ...> {   // 현실적으로 불가능
```

modifier 하나만 추가해도 시그니처를 다시 써야 한다. `some View`가 이 문제를 없애 준다.

```swift
var body: some View {   // "View를 만족하는 어떤 타입" — 컴파일러가 알아서 채운다
```

### opaque type이 무엇인가

Swift 공식 문서의 정의다.

> A function or method that returns an opaque type **hides its return value's type information**. Instead of providing a concrete type as the function's return type, the return value is described in terms of the protocols it supports. **Opaque types preserve type identity** — the compiler has access to the type information, but clients of the module don't.

두 가지가 핵심이다.

- **타입 정보를 감춘다** — 호출하는 쪽은 구체 타입을 모른다
- **타입 신원은 유지된다** — 컴파일러는 정확히 알고 있다

두 번째가 `any`와 갈리는 지점이다.

### 제네릭과 반대 방향이다

이 비유가 이해에 가장 도움이 된다.

> You can think of an opaque type like being the reverse of a generic type. Generic types let **the code that calls a function** pick the type for that function's parameters and return value in a way that's abstracted away from the function implementation.
>
> Those roles are reversed for a function with an opaque return type. **An opaque type lets the function implementation** pick the type for the value it returns in a way that's abstracted away from the code that calls the function.

```text
제네릭     func max<T: Comparable>(_ x: T, _ y: T) -> T
           → 호출하는 쪽이 T를 정한다
           → 함수 구현은 T가 무엇인지 모른다

opaque     func makeShape() -> some Shape
           → 함수 구현이 타입을 정한다
           → 호출하는 쪽은 그 타입이 무엇인지 모른다
```

**"누가 타입을 정하는가"가 정반대**다. `body`의 경우 내가(구현이) `Text`인지 `VStack`인지 정하고, SwiftUI(호출자)는 그것이 `View`라는 사실만 안다.

### `some`과 `any`의 차이

Swift에는 타입을 감추는 방법이 둘 있다.

> Swift provides two ways to hide details about a value's type: **opaque types** and **boxed protocol types**.
>
> A boxed protocol type can store an instance of any type that conforms to the given protocol. **Boxed protocol types don't preserve type identity** — the value's specific type isn't known until runtime, and it can change over time as different values are stored.

정리하면 이렇다.

| | `some View` (opaque) | `any View` (boxed) |
| --- | --- | --- |
| 타입 신원 | **유지** — 하나의 구체 타입 | 유지 안 됨 — 무엇이든 가능 |
| 결정 시점 | **컴파일 타임** | 런타임 |
| 비용 | 없음 (정적 디스패치) | **박싱 오버헤드** |
| 반환 타입 | 모든 경로가 **같은 타입**이어야 함 | 경로마다 달라도 됨 |
| 배열에 담기 | 어려움 | 가능 (`[any View]`) |

문서의 설명이 트레이드오프를 요약한다.

> Generally speaking, **boxed protocol types give you more flexibility** about the underlying types of the values they store, and **opaque types let you make stronger guarantees** about those underlying types.

**`some`의 제약이 실제로 걸리는 경우**가 있다.

```swift
// ⚠️ 컴파일 에러 — 반환 타입이 두 가지
var body: some View {
    if isLoggedIn {
        Text("환영합니다")      // Text
    } else {
        Button("로그인") { }    // Button
    }
}
```

`some`은 **하나의 구체 타입**을 요구하는데 분기마다 타입이 다르다. `@ViewBuilder`가 이 문제를 해결한다 — 분기를 `_ConditionalContent<Text, Button>`이라는 **하나의 타입**으로 감싸 준다. 그래서 `body`에서는 `if`를 쓸 수 있다.

`@ViewBuilder`가 없는 일반 함수에서는 여전히 에러다.

```swift
func makeView() -> some View {       // ⚠️ 에러
    if flag { Text("A") } else { Button("B") { } }
}

@ViewBuilder                          // ✅ 이걸 붙이면 된다
func makeView() -> some View {
    if flag { Text("A") } else { Button("B") { } }
}
```

[클로저와 view builder 문서](./closures-and-view-builders.md)와 [ViewBuilder vs View 구조체](./viewbuilder-vs-view-struct.md)에서 다룬 내용이다.

### `some`을 쓸 수 있는 자리

**① 반환 타입 (opaque return type) — 원래 용도**

```swift
var body: some View { ... }
func makeShape() -> some Shape { ... }
```

**② 파라미터 타입 (opaque parameter type) — Swift 5.7부터**

```swift
func draw(_ shape: some Shape) { ... }
```

이건 제네릭의 축약 표기다. 다음과 완전히 같다.

```swift
func draw<T: Shape>(_ shape: T) { ... }
```

이미 본 예가 있다. `phaseAnimator`의 시그니처다.

```swift
nonisolated func phaseAnimator<Phase>(
    _ phases: some Sequence<Phase>,
    trigger: some Equatable,
    ...
)
```

`trigger: some Equatable`은 "`Equatable`을 만족하는 어떤 타입"이다. [phaseAnimator 문서](./phase-animator-parameters-and-phase-types.md) 참조.

`navigationDestination`에서도 나온다.

```swift
func coordinateSpace(_ name: NamedCoordinateSpace) -> some View
func frame(in coordinateSpace: some CoordinateSpaceProtocol) -> CGRect
```

### 함께 공부할 개념들

`some`을 제대로 이해하려면 주변 개념이 필요하다. 순서대로 정리하면 이렇다.

**1단계 — 프로토콜과 associatedtype**

`some`이 필요해진 근본 이유다. `associatedtype`이 있는 프로토콜은 타입으로 직접 쓸 수 없다.

- [typealias와 associatedtype](./typealias-and-associated-type.md)
- [protocol 요구사항과 style 프로토콜](./protocol-requirements-and-style-protocols.md)

**2단계 — 제네릭**

`some`이 제네릭의 "반대 방향"이라는 것을 이해해야 한다. 파라미터 자리의 `some`은 제네릭 축약이기도 하다.

**3단계 — result builder (`@ViewBuilder`)**

`some View`의 "하나의 타입" 제약을 우회하는 장치다. `body`에서 `if`와 `for`를 쓸 수 있는 이유.

- [클로저와 view builder](./closures-and-view-builders.md)
- [ViewBuilder 함수 vs View 구조체](./viewbuilder-vs-view-struct.md)

**4단계 — `any`와 existential type**

`some`과의 대비로 이해한다. 언제 유연성을 택하고 언제 성능을 택할지 판단하는 기준.

**5단계 — 타입 소거(type erasure)**

`any`의 사촌 개념이다. SwiftUI의 `AnyView`, `NavigationPath`가 이 기법을 쓴다.

- [NavigationPath와 타입 배열](./navigation-path-and-typed-array.md) — path가 타입 소거를 쓰는 이유

**6단계 — 정적/동적 디스패치**

`some`이 왜 빠른지, `any`가 왜 오버헤드가 있는지의 배경이다.

### `AnyView`는 최후의 수단이다

타입을 완전히 지워야 할 때 SwiftUI가 제공하는 것이다.

```swift
func makeView(flag: Bool) -> AnyView {
    flag ? AnyView(Text("A")) : AnyView(Button("B") { })
}
```

동작하지만 **SwiftUI의 최적화를 무력화한다.** 타입 정보가 사라지면 SwiftUI가 "이 뷰가 그대로인지 바뀌었는지" 판단하기 어려워져 불필요한 재렌더링이 늘어난다.

**우선순위는 이렇다.**

```text
① @ViewBuilder + some View          ← 기본
② 조건부 modifier, opacity 등으로 우회
③ 제네릭으로 타입을 파라미터화
④ AnyView                            ← 정말 어쩔 수 없을 때만
```

### 이 예제에서 확인할 것

`DestinationView`의 `body` 타입을 실제로 볼 수 있다.

```swift
var body: some View {
    Text(title)
        .navigationBarBackButtonHidden()
        .onTapGesture { dismiss() }
}
```

Xcode에서 `body`에 ⌥클릭하면 Quick Help가 `some View`라고만 보여 준다. 하지만 `print(type(of: body))`를 실행하면 실제 중첩 타입이 드러난다. [메타타입과 `.self`](./metatype-and-self.md)에서 다룬 `type(of:)`다.

modifier를 하나 더 붙이면 타입이 또 한 겹 늘어나는 것도 관찰할 수 있다. `some View`가 없다면 그때마다 시그니처를 고쳐야 했을 것이다.

### 정리

```text
some View = "View를 만족하는 어떤 하나의 구체 타입"
             컴파일러는 안다 / 호출자는 모른다 / 신원은 유지된다

왜 필요한가
  View의 Body가 associatedtype이고
  실제 타입이 ModifiedContent<...> 중첩으로 길어지기 때문

제네릭과의 관계
  제네릭: 호출자가 타입을 정한다
  opaque: 구현이 타입을 정한다   ← 반대 방향

some vs any
  some: 하나의 타입, 컴파일 타임, 비용 없음, 보장이 강하다
  any:  아무 타입, 런타임, 박싱 비용, 유연하다

제약: 모든 반환 경로가 같은 타입이어야 한다
      → @ViewBuilder가 _ConditionalContent로 감싸 해결
```

## 학습 체크리스트

- [ ] `print(type(of: body))`로 `DestinationView.body`의 실제 타입을 출력한다.
- [ ] modifier를 하나 더 붙이고 타입이 어떻게 늘어나는지 다시 출력한다.
- [ ] `var body: some View`를 `var body: Text`로 바꿔 보고 언제 컴파일되는지 확인한다.
- [ ] modifier를 붙인 상태에서 `var body: Text`가 실패하는 것을 확인한다.
- [ ] `some` 없이 `var body: View`로 써 보고 어떤 에러가 나는지 읽는다.
- [ ] `@ViewBuilder` 없는 함수에서 `if/else`로 다른 타입을 반환해 에러를 확인한다.
- [ ] 그 함수에 `@ViewBuilder`를 붙여 통과하는 것을 확인한다.
- [ ] `_ConditionalContent`가 실제로 등장하는지 `type(of:)`로 확인한다.
- [ ] `func draw(_ shape: some Shape)`와 `func draw<T: Shape>(_ shape: T)`가 같은지 비교한다.
- [ ] `[any View]` 배열을 만들어 보고 `[some View]`가 안 되는 이유를 설명한다.
- [ ] `AnyView`로 조건 분기를 만들고 `@ViewBuilder` 방식과 비교한다.
- [ ] `View` 프로토콜 정의로 점프해 `associatedtype Body`를 직접 확인한다.
- [ ] Swift 공식 문서의 `Shape`/`FlippedShape` 예제를 그대로 작성해 opaque return을 실습한다.

## 공식 참고 자료

- [Swift 공식 문서: Opaque and Boxed Protocol Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/)
- [Swift 공식 문서: Opaque Types — Returning an Opaque Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/#Returning-an-Opaque-Type)
- [Swift 공식 문서: Opaque Types — Differences Between Opaque Types and Boxed Protocol Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/#Differences-Between-Opaque-Types-and-Boxed-Protocol-Types)
- [Swift 공식 문서: Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [Swift 공식 문서: Generics — Associated Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Associated-Types)
- [Swift 공식 문서: Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [Swift 공식 문서: Types — Opaque Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Opaque-Type)
- [Apple: View](https://developer.apple.com/documentation/swiftui/view)
- [Apple: View.body](https://developer.apple.com/documentation/swiftui/view/body-swift.property)
- [Apple: ViewBuilder](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Apple: AnyView](https://developer.apple.com/documentation/swiftui/anyview)
- [Apple: ModifiedContent](https://developer.apple.com/documentation/swiftui/modifiedcontent)
- [Swift Evolution SE-0244: Opaque Result Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0244-opaque-result-types.md)
- [Swift Evolution SE-0341: Opaque Parameter Declarations](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0341-opaque-parameters.md)
