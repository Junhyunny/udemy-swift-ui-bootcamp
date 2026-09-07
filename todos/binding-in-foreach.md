# `ForEach`에서 무엇이 `Binding`이고 무엇이 값인가

`@State`에 `$`를 붙이면 무엇이 나오는지는 [`@State`를 붙이면 타입이 바뀌는가](./state-wrapper-type-and-binding.md)에 정리돼 있다. 이 문서는 **`ForEach` 클로저 안에서 헷갈리는 세 가지 경우**를 구분한다.

## 질문이 나온 코드

`chapter-32/chapter-32/ContentView.swift`의 `ForEach($todos, id: \.self) { $todo in ... CheckBox(isChecked: $todo.completed); Text(todo.title) }`

## 공부할 내용

### 먼저 두 가지 규칙만 잡으면 된다

**규칙 1 — `$`는 선언에 property wrapper가 붙어 있을 때만 쓸 수 있다.**
`@State var todos`가 있으니 `$todos`가 가능하다. 클로저 파라미터에도 `$todo in`처럼 쓰면 같은 효과가 생긴다.

**규칙 2 — `Binding`은 `@dynamicMemberLookup`이다.**

> `@frozen @propertyWrapper @dynamicMemberLookup struct Binding<Value>`
>
> `subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> { get }`
>
> "Use dynamic member lookup to project a property of the binding's wrapped value from a key path into a new binding."

즉 **`Binding<Todo>`에 `.title`을 붙이면 `String`이 아니라 `Binding<String>`이 나온다.** 이 한 줄이 혼란의 대부분을 설명한다.

### 세 가지 경우 비교

#### 1. `ForEach($todos) { $todo in ... }` — 지금 코드

`$todos`는 `Binding<[Todo]>`이고, 이 오버로드는 각 행에 `Binding<Todo>`를 넘긴다. 파라미터를 **`$todo`로 받으면** property wrapper처럼 풀려서 이름 두 개가 생긴다.

| 표기 | 타입 |
| --- | --- |
| `todo` | `Todo` (값) |
| `$todo` | `Binding<Todo>` |
| `todo.title` | `String` |
| `$todo.completed` | `Binding<Bool>` |

그래서 `Text(todo.title)`(값이 필요)와 `CheckBox(isChecked: $todo.completed)`(양방향 연결이 필요)가 **한 클로저 안에 나란히** 올 수 있다. 이게 이 형태를 쓰는 이유다.

#### 2. `ForEach($todos) { todo in ... }` — `$` 없이 받은 경우

넘어오는 값은 똑같이 `Binding<Todo>`인데, 이름을 그냥 `todo`로 받았으므로 **`todo` 자체가 `Binding<Todo>`**다.

| 표기 | 결과 |
| --- | --- |
| `todo` | `Binding<Todo>` |
| `$todo` | **없음** (선언에 wrapper가 없으니 컴파일 오류) |
| `todo.title` | `Binding<String>` — dynamic member lookup |
| `todo.wrappedValue.title` | `String` |

여기서 `Text(todo.title)`은 **컴파일되지 않는다.** `Text`는 `String`을 원하는데 `Binding<String>`이 오기 때문이다. 값이 필요하면 `todo.wrappedValue.title`이라고 써야 한다. "예상과 다르게 동작한다"고 느낀 지점이 대개 여기다.

#### 3. `ForEach(todos) { todo in ... }` — 배열을 그대로 넘긴 경우

`$`가 없으니 그냥 `[Todo]`이고, 각 행에는 `Todo` **값 복사본**이 온다.

| 표기 | 결과 |
| --- | --- |
| `todo` | `Todo` |
| `$todo` | **없음** |
| `todo.title` | `String` |
| `$todo.completed` | **없음** (컴파일 오류) |

읽기만 하는 목록이면 이 형태가 가장 단순하다. 대신 **체크박스로 값을 바꿀 수 없다.** `Binding`이 없으므로 `CheckBox(isChecked:)`에 넘길 것이 없다.

### 한 장으로 정리

| 형태 | 클로저가 받는 것 | `todo.title` | `$todo` |
| --- | --- | --- | --- |
| `ForEach($todos) { $todo in }` | `Binding<Todo>` (풀림) | `String` | `Binding<Todo>` |
| `ForEach($todos) { todo in }` | `Binding<Todo>` | `Binding<String>` | 없음 |
| `ForEach(todos) { todo in }` | `Todo` | `String` | 없음 |

기억할 것은 하나다. **`$`를 붙여 받으면 값과 바인딩 둘 다 쓸 수 있고, 안 붙여 받으면 넘어온 것 하나만 쓸 수 있다.**

### 왜 `Binding`이 필요한가

값 복사본으로는 원본을 바꿀 수 없기 때문이다. `Binding`은 값을 들고 있지 않고 원본을 가리킨다.

> "Use a binding to create a two-way connection between a property that stores data, and a view that displays and changes the data. A binding connects a property to a source of truth stored elsewhere, instead of storing data directly."

`CheckBox`가 `@Binding var isChecked: Bool`로 선언된 것도 같은 이유다. 이 뷰는 값을 저장하지 않고 `todos` 배열 안의 그 원소를 직접 고친다. 그래서 체크하면 배열이 실제로 바뀌고 `onChange(of: todos)`가 반응한다.

## 학습 체크리스트

- [ ] `$todo in`을 `todo in`으로 바꾸고 `Text(todo.title)`에서 나는 오류 메시지를 정확히 읽는다.
- [ ] 그 상태에서 `todo.wrappedValue.title`로 고치면 컴파일되는지 확인한다.
- [ ] `ForEach(todos) { todo in }`로 바꾸고 `CheckBox(isChecked: $todo.completed)`에서 나는 오류를 확인한다.
- [ ] 세 형태 각각에 `print(type(of: todo))`를 넣어 실제 타입을 눈으로 확인한다.
- [ ] `$todo.completed`와 `todo.completed`의 타입을 `type(of:)`로 비교한다.
- [ ] `CheckBox`의 `@Binding`을 `let isChecked: Bool`로 바꾸면 어디서 무너지는지 따라가 본다.
- [ ] 체크박스를 눌렀을 때 `onChange(of: todos)`가 호출되는지 확인하고, 값 복사본이었다면 왜 호출되지 않을지 설명한다.
- [ ] `Binding`이 `@dynamicMemberLookup`이라는 선언을 Quick Help로 직접 확인한다.

## 참고 자료

- [Apple: Binding](https://developer.apple.com/documentation/swiftui/binding)
- [Apple: Binding.subscript(dynamicMember:)](https://developer.apple.com/documentation/swiftui/binding/subscript(dynamicmember:))
- [Apple: Binding.wrappedValue](https://developer.apple.com/documentation/swiftui/binding/wrappedvalue)
- [Apple: State](https://developer.apple.com/documentation/swiftui/state)
- [Apple: State.projectedValue](https://developer.apple.com/documentation/swiftui/state/projectedvalue)
- [Apple: ForEach](https://developer.apple.com/documentation/swiftui/foreach)
- [Apple: ForEach.init(_:id:content:)](https://developer.apple.com/documentation/swiftui/foreach/init(_:id:content:))
- [Apple: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [The Swift Programming Language: Properties — Property Wrappers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
