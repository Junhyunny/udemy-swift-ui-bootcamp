# `@State`를 붙이면 타입이 바뀌는가, `$`는 언제 쓸 수 있는가

어떤 API에 `value`를 주고 어떤 API에 `$value`를 주는지는 [프로퍼티 래퍼의 `$` 사용 기준](./property-wrapper-dollar-sign.md)에 정리돼 있다. 이 문서는 **`@State`가 프로퍼티를 어떤 모양으로 바꿔 놓는지**와 **`$`가 통하지 않는 상황**을 다룬다.

## 질문이 나온 코드

`chapter-29/chapter-29/ContentView.swift`의 `@State var courses = [...]`와 `List($courses, editActions: .delete) { $course in ... }`

## 공부할 내용

### 프로퍼티의 타입은 그대로다. 다만 접근 경로가 세 갈래가 된다

`@State var courses: [Courses]`에서 `courses`의 타입은 여전히 `[Courses]`다. 바뀌는 건 **저장 방식**이다. property wrapper는 저장을 담당하는 별도 타입을 끼워 넣는다.

> "A property wrapper adds a layer of separation between code that manages how a property is stored and the code that defines a property."
>
> "When you apply a wrapper to a property, the compiler synthesizes code that provides storage for the wrapper and code that provides access to the property through the wrapper."

그래서 이름 하나에 접근 경로가 세 개 생긴다.

| 표기 | 무엇 | 이 코드에서의 타입 |
| --- | --- | --- |
| `courses` | `wrappedValue` (실제 값) | `[Courses]` |
| `$courses` | `projectedValue` | `Binding<[Courses]>` |
| `_courses` | 래퍼 인스턴스 자체 | `State<[Courses]>` |

`$`는 property wrapper 전용 문법이다.

> "The name of the projected value is the same as the wrapped value, except it begins with a dollar sign (`$`). Because your code can't define properties that start with `$` the projected value never interferes with properties you define."

`@State`가 내놓는 projected value는 `Binding`이다.

> `var projectedValue: Binding<Value> { get }`
>
> "Use the projected value to get a `Binding` to the stored value. The binding provides a two-way connection to the stored value. To access the `projectedValue`, prefix the property variable with a dollar sign (`$`)."

정리하면 **타입이 바뀌는 게 아니라, `$`를 붙였을 때 나오는 것이 원래 값이 아니라 `Binding`이라는 다른 타입**이다.

### `$`가 통하지 않는 경우

`$courses`라고 썼는데 오류가 난다면 대개 아래 중 하나다.

1. **받는 쪽이 `Binding`을 요구하지 않는다.** 가장 흔한 경우다. `Binding<[Courses]>`를 `[Courses]` 자리에 넣으면 타입 불일치다. 지금 코드에서 `List($courses, editActions: .delete)`가 되는 건 그 초기화 메서드가 `Binding`을 받도록 만들어졌기 때문이고, `ForEach(courses)`에는 `$`를 붙이면 안 된다. 실제로 파일 안에 두 형태가 나란히 있다.
2. **property wrapper가 안 붙은 변수다.** 그냥 `var courses = [...]`나 함수 안의 지역 변수에는 `$`를 쓸 수 없다. projected value가 존재하지 않기 때문이다. `delete(at:)` 같은 메서드 안의 지역 변수도 마찬가지다.
3. **`@State`가 아니라 값을 그대로 받은 프로퍼티다.** 하위 뷰에서 `var courses: [Courses]`로 받았다면 읽기 전용 복사본이라 `$`가 없다. 쓰기까지 하려면 `@Binding var courses: [Courses]`로 선언하고 부모가 `$courses`를 넘겨야 한다.

`List($courses, editActions: .delete) { $course in ... }`에서 클로저 파라미터에 다시 `$course`가 붙는 것도 같은 원리다. 이 오버로드는 각 행에 원소의 `Binding`을 넘겨주고, `$course`로 받아 `course.title`처럼 쓰면 wrapped value에 접근한다.

### `@State`를 어디에 선언할지

> "Declare state as private to prevent setting it in a memberwise initializer, which can conflict with the storage management that SwiftUI provides"
>
> "Declare state as private in the highest view in the view hierarchy that needs access to the value. Then share the state with any subviews that also need access, either directly for read-only access, or as a binding for read-write access."

현재 코드의 `@State var courses`는 `private`이 빠져 있다. Apple은 `private`을 권한다. 밖에서 초기값을 주입할 수 있게 열려 있으면 SwiftUI의 저장소 관리와 충돌할 수 있기 때문이다. 또한 `State`는 **뷰와 그 하위 뷰에 국한된 저장소**로만 쓰라고 안내한다.

## 학습 체크리스트

- [ ] `print(type(of: courses))`와 `print(type(of: $courses))`를 찍어 두 타입이 다른 것을 확인한다.
- [ ] `_courses`로 래퍼 인스턴스에 직접 접근해 타입이 `State<[Courses]>`임을 확인한다.
- [ ] `ForEach($courses)`와 `ForEach(courses)`를 각각 시도해 오류 메시지를 비교한다.
- [ ] `@State`를 떼고 `var courses = [...]`로 바꾼 뒤 `$courses`가 왜 안 되는지 확인한다.
- [ ] 하위 뷰를 만들어 `var courses: [Courses]`로 받았을 때와 `@Binding var courses: [Courses]`로 받았을 때의 차이를 비교한다.
- [ ] `@State var`에 `private`을 붙여 보고, Apple이 왜 권하는지 설명한다.
- [ ] `List($courses, editActions: .delete)`의 클로저에서 `$course`를 `course`로 바꾸면 어떤 오류가 나는지 본다.

## 참고 자료

- [Apple: State](https://developer.apple.com/documentation/swiftui/state)
- [Apple: State.wrappedValue](https://developer.apple.com/documentation/swiftui/state/wrappedvalue)
- [Apple: State.projectedValue](https://developer.apple.com/documentation/swiftui/state/projectedvalue)
- [Apple: Binding](https://developer.apple.com/documentation/swiftui/binding)
- [Apple: DynamicProperty](https://developer.apple.com/documentation/swiftui/dynamicproperty)
- [Apple: Managing user interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)
- [Apple: EditActions](https://developer.apple.com/documentation/swiftui/editactions)
- [The Swift Programming Language: Properties — Property Wrappers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
