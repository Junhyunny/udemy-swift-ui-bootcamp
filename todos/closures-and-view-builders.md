# `ComponentName { }`의 정체 — 클로저, trailing closure, result builder

argument label과 trailing closure의 기본 규칙은 [`at:` 문법의 정체와 `IndexSet`](./argument-labels-and-indexset.md)에도 짧게 나온다. 이 문서는 **SwiftUI의 `{ }`가 정확히 무엇인지**를 파고든다.

## 질문이 나온 코드

`chapter-33/chapter-33/ContentView.swift`의 `ScrollView { VStack(spacing: 15) { ... } }`와 `ForEach(0..<30) { idx in ... }`

`chapter-36/chapter-36/ContentView.swift`의 `Button(role: .confirm) { ... } label: { ... }` — 왜 `action`은 이름이 없고 `label`은 있는가

## 공부할 내용

### 결론 먼저

- `{ }`는 **클로저(closure)** 가 맞다. 이름 없는 함수 조각이다.
- 다만 **콜백은 아니다.** `VStack { }`의 클로저는 나중에 불리는 게 아니라 **즉시 실행되어 내용물을 만든다.**
- 괄호 밖에 나올 수 있는 건 **trailing closure 문법** 덕분이고, 이 문법을 쓰려면 그 인자가 **마지막**이어야 한다. 파라미터를 아무 데나 둘 수는 있지만, 그러면 괄호 밖으로 뺄 수 없다.
- 클로저를 인자로 받는 함수를 일반적으로 **고차 함수(higher-order function)** 라 부른다.
- SwiftUI의 `{ }` 안에 `if`와 `for`를 쓸 수 있는 건 **result builder** 라는 별도 기능 때문이다.

### 1. 클로저와 trailing closure

> "Closure expressions are a way to write inline closures in a brief, focused syntax."

클로저를 마지막 인자로 넘길 때는 괄호 밖으로 뺄 수 있다.

> "If you need to pass a closure expression to a function as the function's final argument and the closure expression is long, it can be useful to write it as a trailing closure instead. You write a trailing closure after the function call's parentheses, even though the trailing closure is still an argument to the function. When you use the trailing closure syntax, you don't write the argument label for the first closure as part of the function call."

인자가 클로저 하나뿐이면 괄호도 사라진다.

> "If a closure expression is provided as the function's or method's only argument and you provide that expression as a trailing closure, you don't need to write a pair of parentheses `()` after the function or method's name"

`ScrollView { ... }`에 괄호가 없는 이유가 이것이다. 아래 셋은 모두 같은 코드다.

```swift
ScrollView(content: { Text("hi") })   // 원래 모습
ScrollView() { Text("hi") }           // trailing closure
ScrollView { Text("hi") }             // 유일한 인자라 괄호 생략
```

`VStack(spacing: 15) { ... }`는 앞의 `spacing:`은 괄호 안에 남고 마지막 `content:`만 빠져나온 형태다.

### 2. "항상 마지막이어야 하나" — 문법을 쓰려면 그렇다

파라미터 순서 자체에 제약은 없다. 클로저를 첫 번째 파라미터로 두어도 컴파일된다. 다만 **trailing closure 문법은 뒤에서부터 적용**되므로, 괄호 밖으로 빼고 싶으면 마지막에 두어야 한다. 그래서 Swift API들은 관례적으로 클로저를 맨 뒤에 놓는다.

클로저가 여러 개면 뒤쪽 것들을 이어서 뺄 수 있다.

> "If a function takes multiple closures, you omit the argument label for the first trailing closure and you label the remaining trailing closures."

```swift
loadPicture(from: someServer) { picture in
    someView.currentPicture = picture
} onFailure: {
    print("Couldn't download the next picture.")
}
```

첫 trailing closure만 label이 없고 나머지는 label을 붙인다.

#### `Button(role:) { } label: { }`이 그 예다

이 형태가 헷갈리는 이유는 **인자 세 개가 서로 다른 방식으로 전달되기 때문**이다. 선언을 보면 한눈에 풀린다.

> `init(role: ButtonRole?, action: @escaping @MainActor () -> Void, @ContentBuilder label: () -> Label)`

인자는 `role`, `action`, `label` 세 개이고 뒤의 둘이 클로저다. 그래서 이렇게 전달된다.

```swift
Button(role: .confirm) {      // role: 은 괄호 안에 그대로
    increaseCount()           // action: — 첫 trailing closure라 이름 생략
} label: {                    // label: — 두 번째 trailing closure라 이름 필요
    Text("Up")
}
```

**"왜 `action`은 이름이 없고 `label`은 있나"의 답이 이것이다.** `action`이 특별해서가 아니라 **먼저 나온 trailing closure이기 때문**이다. 규칙은 위치가 정한다. 괄호 안에 다 넣으면 둘 다 이름이 붙는다.

```swift
Button(role: .confirm, action: { increaseCount() }, label: { Text("Up") })
```

같은 파일의 다른 형태들도 전부 같은 규칙에서 나온다.

```swift
Button("Click Me") { counter += 1 }              // title은 label 없는 인자, action은 trailing
Button("Click Me", action: { counter += 1 })     // 괄호 안에 넣으면 이름을 쓴다
Button("Click Me", action: increaseCount)        // 클로저 대신 함수를 지목
```

마지막 형태는 클로저를 새로 쓰지 않고 기존 함수를 그대로 넘긴 것이다. `Button(action: increaseCount)`와 `Button { increaseCount() }`는 결과가 같지만, 앞은 함수 자체를 넘기고 뒤는 그 함수를 호출하는 새 클로저를 만든다.

### 3. 함수는 이렇게 만든다

```swift
// 콜백을 받는 함수
func doWork(name: String, completion: () -> Void) {
    print(name)
    completion()
}

doWork(name: "hi") {
    print("done")
}
```

값을 받고 돌려주는 클로저라면 타입에 그대로 쓴다.

```swift
func transform(_ n: Int, using body: (Int) -> String) -> String {
    body(n)
}

transform(3) { "번호 \($0)" }
```

**함수가 끝난 뒤에 호출할 클로저라면 `@escaping`이 필요하다.**

> "A closure is said to escape a function when the closure is passed as an argument to the function, but is called after the function returns. When you declare a function that takes a closure as one of its parameters, you can write `@escaping` before the parameter's type to indicate that the closure is allowed to escape."

저장해 뒀다가 나중에 부르거나 비동기로 넘기려면 `@escaping`을 붙인다. 안 붙이면 컴파일 오류다.

### 4. 여기서 갈린다 — 콜백인 `{ }`와 내용물을 만드는 `{ }`

`Button`의 선언을 보면 두 종류가 한 줄에 같이 있다.

> `init(action: @escaping @MainActor () -> Void, @ContentBuilder label: () -> Label)`

- **`action`** — `@escaping`이다. 버튼을 **누를 때** 불린다. 이것이 진짜 콜백이다.
- **`label`** — `@escaping`이 아니다. 버튼을 만들 때 **즉시** 실행되어 보여줄 내용을 반환한다.

`VStack`도 같다.

> `init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ContentBuilder content: () -> Content)`

즉 **`VStack { }`, `ScrollView { }`의 `{ }`는 콜백이 아니라 "내용물을 만들어 돌려주는 클로저"** 다. 이름이 `content`, `label`인 것도 그래서다.

`ForEach(0..<30) { idx in ... }`는 또 조금 다르다. 각 항목마다 뷰를 만들기 위해 **여러 번** 호출되는 클로저다. 콜백처럼 나중에 불리는 게 아니라 목록을 그리는 동안 반복 호출된다.

#### 내 함수에서 콜백을 받아 넘길 때 — `chapter-47`의 사례

`chapter-47/chapter-47/ContentView.swift`는 직접 만든 API에서 `@escaping`이 왜 필요한지 보여 준다.

```swift
extension View {
    func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
        modifier(MeasuringSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}
```

호출하는 쪽은 이렇게 쓴다.

```swift
.measureSzie { size in
    viewSize = size          // ← 이 클로저가 action
}
```

**`action`이 무엇인가**를 정리하면 이렇다.

- 타입은 `(CGSize) -> Void`다. 측정된 크기를 받고 아무것도 돌려주지 않는다.
- 호출한 쪽이 "크기를 알게 되면 이걸 해 달라"고 건네는 **콜백**이다.
- `measureSzie`는 이 콜백을 **실행하지 않는다.** 그대로 `onPreferenceChange`에 넘기기만 한다.

**왜 `@escaping`이 필요한가**는 이 마지막 줄에서 나온다. `measureSzie`는 값을 반환하며 즉시 끝나지만, `action`은 그 뒤로도 살아남아 크기가 바뀔 때마다 불려야 한다. 앞서 인용한 정의가 그대로 적용된다 — 함수가 반환된 뒤에 호출되는 클로저이므로 escape한다.

받는 쪽 시그니처를 보면 확인된다.

> `nonisolated func onPreferenceChange<K>(_ key: K.Type = K.self, perform action: @escaping (K.Value) -> Void) -> some View where K : PreferenceKey, K.Value : Equatable`

`onPreferenceChange`가 `@escaping`을 요구하므로, 거기에 클로저를 전달하는 `measureSzie`도 **연쇄적으로** `@escaping`이어야 한다. 붙이지 않으면 `escaping closure` 관련 컴파일 오류가 난다.

`Button`의 `action`과 성격이 같다. 둘 다 "나중에 불릴 동작"이고, 둘 다 `@escaping`이다. 반면 `label`이나 `content`는 즉시 실행되므로 `@escaping`이 아니다. 이 구분이 SwiftUI API를 읽는 기준이 된다.

전체 데이터 흐름은 [PreferenceKey 문서](./preference-key-and-onpreferencechange.md)에, `extension View`로 감싸는 이유는 [ViewModifier 문서](./view-modifier-protocol.md)에 정리했다.

### 5. `{ }` 안에서 `if`와 `for`가 되는 이유 — result builder

일반 클로저라면 뷰를 여러 개 나열해 놓고 `return`도 없이 끝낼 수 없다. 그게 가능한 것은 `@ViewBuilder`(현재 SDK 선언에서는 `@ContentBuilder`) 덕분이다.

> "A custom parameter attribute that constructs views from closures."
>
> `@resultBuilder struct ViewBuilder`

`@resultBuilder`는 Swift 언어 기능이다.

> "A result builder is a type you define that adds syntax for creating nested data, like a list or tree, in a natural, declarative way. The code that uses the result builder can include ordinary Swift syntax, like `if` and `for`, to handle conditional or repeated pieces of data."

컴파일러가 `{ }` 안에 나열된 것들을 모아 하나의 값으로 조립해 준다. 그래서 이렇게 쓸 수 있다.

```swift
VStack {
    Text("A")
    if isOn { Text("B") }     // 조건문이 그대로 들어간다
    ForEach(0..<3) { Text("\($0)") }
}
```

**정리하면 SwiftUI의 `{ }`는 "클로저 + trailing closure 문법 + result builder"** 세 가지가 겹쳐 만들어진 모양이다. 셋 다 별개의 Swift 기능이고, SwiftUI가 그것들을 조합해 선언적으로 보이게 만든 것이다.

### 용어 정리

| 용어 | 뜻 |
| --- | --- |
| 클로저 (closure) | 이름 없는 함수 조각. `{ }` 자체 |
| trailing closure | 마지막 클로저 인자를 괄호 밖에 쓰는 **문법** |
| 콜백 (callback) | 나중에 불리라고 넘기는 클로저. `Button`의 `action` |
| `@escaping` | 함수가 끝난 뒤에도 호출될 수 있음을 표시 |
| 고차 함수 | 함수를 인자로 받거나 반환하는 함수 |
| result builder | `{ }` 안의 나열·`if`·`for`를 하나의 값으로 조립하는 기능 |
| `@ViewBuilder` / `@ContentBuilder` | SwiftUI가 뷰용으로 정의한 result builder |

## 학습 체크리스트

- [ ] `ScrollView { ... }`를 `ScrollView(content: { ... })`로 풀어 써서 같은 결과인지 확인한다.
- [ ] `VStack(spacing: 15) { }`를 `VStack(spacing: 15, content: { })`로 바꿔 본다.
- [ ] 클로저를 마지막이 아닌 파라미터로 받는 함수를 만들고, trailing closure로 호출해 보며 왜 안 되는지 확인한다.
- [ ] 클로저 두 개를 받는 함수를 만들어 multiple trailing closure 문법으로 호출한다.
- [ ] 클로저를 배열에 저장하는 함수를 만들고 `@escaping`을 뺐을 때의 오류 메시지를 읽는다.
- [ ] `Button`의 `action`과 `label`에 각각 `print`를 넣어 호출 시점이 다른 것을 확인한다.
- [ ] `VStack { }` 안에 `if`를 넣어 조건부 뷰를 만들고, 일반 클로저에서는 왜 안 되는지 설명한다.
- [ ] `@ViewBuilder`를 붙인 자체 함수를 만들어 여러 뷰를 반환받는다.
- [ ] `ForEach`의 클로저가 몇 번 호출되는지 `print`로 세어 본다.
- [ ] `Button(role:) { } label: { }`를 `Button(role:action:label:)` 한 줄 형태로 풀어 써 본다.
- [ ] 그 상태에서 `action:` 이름을 지우면 어떤 오류가 나는지 확인한다.
- [ ] `label:`을 첫 trailing closure로 만들 수 있는지 시도해 보고 왜 안 되는지 설명한다.
- [ ] `measureSzie(perform:)`에서 `@escaping`을 지우고 어떤 오류가 나는지 읽는다.
- [ ] `action`에 `print`를 넣어 `measureSzie` 호출이 끝난 뒤에 불리는 것을 확인한다.
- [ ] `action`을 `measureSzie` 안에서 즉시 호출하도록 바꿔 보고 의미가 어떻게 달라지는지 비교한다.
- [ ] `typealias SizeHandler = (CGSize) -> Void`로 시그니처를 정리해 본다.

## 참고 자료

- [The Swift Programming Language: Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/)
- [The Swift Programming Language: Functions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/)
- [The Swift Programming Language: Advanced Operators — Result Builders](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/)
- [The Swift Programming Language: Attributes — resultBuilder](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/)
- [Apple: ViewBuilder](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Apple: ContentBuilder](https://developer.apple.com/documentation/swiftui/contentbuilder)
- [Apple: VStack.init(alignment:spacing:content:)](https://developer.apple.com/documentation/swiftui/vstack/init(alignment:spacing:content:))
- [Apple: Button.init(action:label:)](https://developer.apple.com/documentation/swiftui/button/init(action:label:))
- [The Swift Programming Language: Closures — Escaping Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Escaping-Closures)
- [Apple: view.onPreferenceChange(_:perform:)](https://developer.apple.com/documentation/swiftui/view/onpreferencechange(_:perform:))
- [Apple: ScrollView](https://developer.apple.com/documentation/swiftui/scrollview)
- [Apple: ForEach.init(_:content:)](https://developer.apple.com/documentation/swiftui/foreach/init(_:content:))
- [Apple: Button.init(role:action:label:)](https://developer.apple.com/documentation/swiftui/button/init(role:action:label:))
- [Apple: ButtonRole](https://developer.apple.com/documentation/swiftui/buttonrole)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
