# `mutating`은 무엇이고, `@State`는 왜 없어도 되는가

## 질문이 나온 코드

`chapter-29/chapter-29/ContentView.swift`의 `func delete(at offsets: IndexSet)` 안에서 호출하는 `courses.remove(atOffsets: offsets)`

## 공부할 내용

### 값 타입의 메서드는 기본적으로 자기 프로퍼티를 못 바꾼다

> "Structures and enumerations are value types. By default, the properties of a value type can't be modified from within its instance methods."
>
> "However, if you need to modify the properties of your structure or enumeration within a particular method, you can opt in to mutating behavior for that method. ... You can opt in to this behavior by placing the `mutating` keyword before the `func` keyword for that method"

```swift
struct Point {
    var x = 0.0, y = 0.0
    mutating func moveBy(x deltaX: Double, y deltaY: Double) {
        x += deltaX
        y += deltaY
    }
}
```

`class`에는 이 키워드가 없다. 참조 타입은 인스턴스가 힙에 있고 그 내용을 고치는 것이라, 값을 통째로 교체한다는 개념이 없기 때문이다. `mutating`은 **`struct`와 `enum`에만 있는 문법**이다.

왜 이런 구분이 필요한가 하면, 값 타입은 상수에 담길 수 있기 때문이다.

> "Note that you can't call a mutating method on a constant of structure type, because its properties can't be changed, even if they're variable properties"

`let point = Point()`에 `moveBy`를 호출하면 컴파일 오류다. `mutating` 표시가 있어야 컴파일러가 "이 메서드는 값을 바꾼다"를 알고 상수에 대한 호출을 막을 수 있다.

### `ContentView`도 struct다 — 그런데 왜 오류가 안 나나

여기가 질문의 핵심이다. `struct ContentView: View`이고 `delete(at:)`에 `mutating`이 없는데, 그 안에서 `courses`를 바꾸는 `remove(atOffsets:)`를 호출한다. `remove(atOffsets:)` 자체는 분명 mutating이다.

> `mutating func remove(atOffsets offsets: IndexSet)`

일반 `var`였다면 "`self`가 immutable이니 `mutating`을 붙이라"는 오류가 난다. 통과하는 이유는 `courses`가 `@State`이고, **`State.wrappedValue`의 setter가 `nonmutating`으로 선언돼 있기** 때문이다.

> `var wrappedValue: Value { get nonmutating set }`

`nonmutating set`은 "이 프로퍼티에 값을 써도 `self`는 변경되지 않는다"는 뜻이다. 그러니 컴파일러 입장에서 `courses.remove(...)`는 `ContentView`를 바꾸는 동작이 아니고, `mutating`이 필요 없다.

### 왜 `self`를 안 바꿔도 값이 바뀌나

값이 `ContentView` 안에 저장돼 있지 않기 때문이다.

> "SwiftUI manages the property's storage. When the value changes, SwiftUI updates the parts of the view hierarchy that depend on the value."

`@State`가 붙으면 실제 데이터는 뷰 바깥, SwiftUI가 관리하는 저장소에 있다. `ContentView` 구조체는 그 저장소를 가리키는 손잡이만 들고 있다. 그래서 값을 바꿔도 구조체 자신은 그대로이고, `nonmutating set`이 성립한다.

이 설계가 필요한 이유는 SwiftUI가 뷰 구조체를 **수시로 새로 만들어 버리기** 때문이다. 화면이 갱신될 때마다 `ContentView` 값이 새로 생성되는데, 데이터가 구조체 안에 들어 있었다면 그때마다 초기화되어 사라진다. 저장소를 밖에 두었기에 뷰가 다시 만들어져도 값이 유지된다.

`Binding`도 같은 구조라서 하위 뷰에서 `@Binding var`를 수정할 때 `mutating`이 필요 없다.

> `var wrappedValue: Value { get nonmutating set }`

### 세 가지 경우 비교

| 선언 | 메서드에서 수정할 때 | 이유 |
| --- | --- | --- |
| `var courses: [Courses]` (struct 안) | `mutating` 필요 | 값이 struct 안에 저장됨 |
| `@State var courses` | 불필요 | `wrappedValue`가 `nonmutating set`, 저장소는 SwiftUI가 관리 |
| `class` 안의 `var courses` | 불필요 | 참조 타입이라 `mutating` 개념 자체가 없음 |

## 학습 체크리스트

- [ ] `@State`를 떼고 `var courses = [...]`로 바꾼 뒤 `delete(at:)`에서 어떤 오류가 나는지 정확히 읽는다.
- [ ] 그 상태에서 `mutating func delete(...)`로 고치면 이번엔 `body` 쪽에서 왜 문제가 생기는지 확인한다.
- [ ] 간단한 `struct Counter`를 만들어 `mutating func increment()`를 작성하고, `let`으로 선언한 인스턴스에 호출해 오류를 본다.
- [ ] Quick Help로 `State.wrappedValue` 선언에서 `nonmutating set`을 직접 확인한다.
- [ ] `Binding.wrappedValue`도 `nonmutating set`인지 확인하고, 하위 뷰에서 `@Binding` 값을 수정해 본다.
- [ ] `mutating func`에서 `self = Point(...)`처럼 `self` 전체를 교체하는 예제를 작성한다.
- [ ] `Courses`를 `class`로 바꿨을 때 `mutating`이 왜 불필요해지는지 설명한다.
- [ ] `ContentView`가 언제 새로 만들어지는지 `init`에 `print`를 넣어 관찰하고, `@State` 값이 왜 살아남는지 설명한다.

## 참고 자료

- [The Swift Programming Language: Methods — Modifying Value Types from Within Instance Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/methods/)
- [The Swift Programming Language: Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
- [The Swift Programming Language: Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
- [Apple: State](https://developer.apple.com/documentation/swiftui/state)
- [Apple: State.wrappedValue](https://developer.apple.com/documentation/swiftui/state/wrappedvalue)
- [Apple: Binding.wrappedValue](https://developer.apple.com/documentation/swiftui/binding/wrappedvalue)
- [Apple: DynamicProperty](https://developer.apple.com/documentation/swiftui/dynamicproperty)
- [Apple: RangeReplaceableCollection.remove(atOffsets:)](https://developer.apple.com/documentation/swift/rangereplaceablecollection/remove(atoffsets:))
