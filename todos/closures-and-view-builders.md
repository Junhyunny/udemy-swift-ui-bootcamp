# `ComponentName { }`의 정체 — 클로저, trailing closure, result builder

argument label과 trailing closure의 기본 규칙은 [`at:` 문법의 정체와 `IndexSet`](./argument-labels-and-indexset.md)에도 짧게 나온다. 이 문서는 **SwiftUI의 `{ }`가 정확히 무엇인지**를 파고든다.

## 질문이 나온 코드

`chapter-33/chapter-33/ContentView.swift`의 `ScrollView { VStack(spacing: 15) { ... } }`와 `ForEach(0..<30) { idx in ... }`

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

## 참고 자료

- [The Swift Programming Language: Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/)
- [The Swift Programming Language: Functions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/)
- [The Swift Programming Language: Advanced Operators — Result Builders](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/)
- [The Swift Programming Language: Attributes — resultBuilder](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/)
- [Apple: ViewBuilder](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Apple: ContentBuilder](https://developer.apple.com/documentation/swiftui/contentbuilder)
- [Apple: VStack.init(alignment:spacing:content:)](https://developer.apple.com/documentation/swiftui/vstack/init(alignment:spacing:content:))
- [Apple: Button.init(action:label:)](https://developer.apple.com/documentation/swiftui/button/init(action:label:))
- [Apple: ScrollView](https://developer.apple.com/documentation/swiftui/scrollview)
- [Apple: ForEach.init(_:content:)](https://developer.apple.com/documentation/swiftui/foreach/init(_:content:))
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
