# `Identifiable` 프로토콜을 쓰는 이유와 쓰는 경우

`ForEach`에서 `id:`를 직접 넘기는 쪽 이야기는 [`ForEach`의 `id`와 `\.self` key path](./foreach-id-and-identity-keypath.md)에 정리돼 있다. 이 문서는 **타입 자체에 identity를 부여하는** `Identifiable` 쪽을 다룬다.

## 질문이 나온 코드

`chapter-29/chapter-29/ContentView.swift`의 `struct Courses: Identifiable { let id = UUID() ... }`와 `ForEach(courses)`

## 공부할 내용

### `Identifiable`은 "이 타입은 안정적인 신원을 가진다"는 선언이다

> "A class of types whose instances hold the value of an entity with stable identity."
>
> "Use the `Identifiable` protocol to provide a stable notion of identity to a class or value type. For example, you could define a `User` type with an `id` property that is stable across your app and your app's database storage. You could use the `id` property to identify a particular user even if other data fields change, such as the user's name."

핵심은 **"다른 필드가 바뀌어도 같은 대상임을 알아볼 수 있는가"**다. `Courses`의 `title`을 고쳐도 그것이 여전히 같은 강의라는 걸 알려면, 내용과 무관한 별도의 신원 값이 필요하다. 요구사항은 `id` 프로퍼티 하나뿐이고 `Hashable`이면 된다.

### 왜 SwiftUI가 이걸 요구하나

`List`와 `ForEach`는 목록이 갱신될 때 이전 항목과 새 항목을 대조해 무엇이 추가·삭제·이동됐는지 판단한다. 그 대조의 기준이 identity다. `ForEach` 문서가 두 가지 길만 제시한다.

> "Either the collection's elements must conform to `Identifiable` or you need to provide an `id` parameter to the `ForEach` initializer."

`Courses`가 `Identifiable`이므로 `ForEach(courses)`처럼 **`id:` 없이** 쓸 수 있다. 만약 준수하지 않았다면 `ForEach(courses, id: \.title)` 같은 식으로 매번 지정해야 하고, `title`이 바뀌면 identity가 깨진다.

### 왜 `UUID`인가

```swift
let id = UUID()
```

`UUID`는 "A universally unique value to identify types, interfaces, and other items."다. 여기서 중요한 건 두 가지다.

- **`let`이다** — 한 번 정해지면 안 바뀐다. identity는 변하면 안 되므로 `var`로 두면 안 된다.
- **`= UUID()`로 기본값을 준다** — 인스턴스를 만들 때마다 새로 발급되므로 중복되지 않는다. 덕분에 `Courses(title:numberOfLessons:)`처럼 `id`를 뺀 memberwise initializer를 쓸 수 있다.

내용에서 파생된 값(`title` 등)을 id로 쓰면 내용이 바뀔 때 다른 항목으로 취급된다. 서버에서 받은 고유 키가 있다면 그걸 쓰는 편이 낫고, 없으면 `UUID`가 무난한 선택이다.

### 언제 쓰나 / 언제 안 써도 되나

- 목록에 표시하고 **추가·삭제·순서 변경**이 일어난다 → 쓴다. 지금 코드처럼 `onDelete`가 있으면 특히 그렇다.
- 항목마다 `@State`나 애니메이션 등 **유지되어야 할 상태**가 있다 → 쓴다.
- 그냥 고정된 문자열 몇 개를 나열할 뿐이다 → `id: \.self`로 충분하다.

### 클래스의 경우

> "`Identifiable` provides a default implementation for class types (using `ObjectIdentifier`), which is only guaranteed to remain unique for the lifetime of an object. If an object has a stronger notion of identity, it may be appropriate to provide a custom implementation."

클래스는 `id`를 안 써도 준수가 되지만, 그 신원은 **객체가 살아 있는 동안만** 유효하다. 앱을 재시작하거나 서버에서 다시 받아오면 달라지므로, 저장·통신하는 데이터라면 직접 `id`를 정의하는 편이 안전하다.

## 학습 체크리스트

- [ ] `Courses`에서 `: Identifiable`을 지우고 `ForEach(courses)`가 어떤 컴파일 오류를 내는지 읽는다.
- [ ] `id`를 `let`에서 `var`로 바꾸고 값을 변경했을 때 목록이 어떻게 반응하는지 관찰한다.
- [ ] `id = UUID()`를 지우고 `var id: String { title }`로 바꾼 뒤, `title`을 수정하면 무슨 일이 생기는지 확인한다.
- [ ] 같은 `title`을 가진 `Courses`를 두 개 넣고 `UUID` 방식과 `\.title` 방식의 차이를 비교한다.
- [ ] `Courses`를 `class`로 바꿔 `id` 없이도 `Identifiable`이 되는지 확인하고, 그 신원의 유효 범위를 설명한다.
- [ ] `print(course.id)`로 앱을 두 번 실행해 `UUID` 값이 매번 달라지는 것을 확인한다.

## 참고 자료

- [Apple: Identifiable](https://developer.apple.com/documentation/swift/identifiable)
- [Apple: ForEach](https://developer.apple.com/documentation/swiftui/foreach)
- [Apple: List](https://developer.apple.com/documentation/swiftui/list)
- [Apple: UUID](https://developer.apple.com/documentation/foundation/uuid)
- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [Apple: View.id(_:)](https://developer.apple.com/documentation/swiftui/view/id(_:))
