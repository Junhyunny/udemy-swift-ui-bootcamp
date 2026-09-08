# `enum`은 항상 `Hashable`이어야 하는가

`id`에 쓰이는 `Hashable`과 해시 충돌 이야기는 [별도 문서](./hashable-id-and-collisions.md)에 있다. 이 문서는 **`enum`에 `Hashable`을 명시적으로 붙이는 이유**에 집중한다.

## 질문이 나온 코드

`chapter-51/chapter-51/ContentView.swift`

```swift
enum Route: Hashable {
    case test
    case support
}
```

```swift
path.append(Route.test)
```

```swift
.navigationDestination(for: Route.self) { route in
    switch route {
    case .test: TestView()
    case .support: SupportView()
    }
}
```

## 공부할 내용

### 결론 먼저

- **아니다. `enum`이 항상 `Hashable`일 필요는 없다.**
- 다만 이 코드에서는 **필요하다.** `NavigationPath`와 `navigationDestination`이 요구하기 때문이다.
- 그리고 이 `enum`은 **연관값이 없어서 `Hashable` 구현이 자동 합성**된다. 그래서 선언 한 줄만 쓰면 끝이다.
- `Hashable`은 **상속이 아니라 프로토콜 준수(conformance)** 다. `enum`은 클래스를 상속할 수 없다.

### 용어부터 — 상속이 아니라 준수다

질문에 "상속 받았지?"라는 표현이 있는데, Swift에서는 구분이 필요하다.

```swift
enum Route: Hashable { }        // 프로토콜 준수 (conformance)
class Dog: Animal { }           // 클래스 상속 (inheritance)
```

문법이 둘 다 콜론이라 헷갈리기 쉽지만, `enum`과 `struct`는 **상속 자체가 불가능**하다. 콜론 뒤에 오는 것은 항상 프로토콜이다. 자세한 구분은 [Swift의 타입 체계와 상속 구조](./swift-type-system-and-inheritance.md)에 정리했다.

`enum`이 프로토콜을 채택할 수 있다는 것 자체가 Swift `enum`의 특징이다.

> Enumerations in Swift are first-class types in their own right. They adopt many features traditionally supported only by classes, such as computed properties (…) and instance methods (…). Enumerations can also define initializers (…); can be extended (…); and can conform to protocols to provide standard functionality.

### 왜 이 코드에는 필요한가 — API가 요구한다

두 곳에서 `Hashable`을 요구한다.

**① `NavigationPath.append`**

```swift
mutating func append<V>(_ value: V) where V : Decodable, V : Encodable, V : Hashable
```

**② `navigationDestination(for:destination:)`**

```swift
nonisolated func navigationDestination<D, C>(
    for data: D.Type,
    @ViewBuilder destination: @escaping (D) -> C
) -> some View where D : Hashable, C : View
```

`where D : Hashable`이 제약이다. `Hashable`이 아니면 컴파일되지 않는다.

**왜 요구하나?** `NavigationPath`가 타입 소거(type erasure)를 쓰기 때문이다.

> If you need to present different kinds of data in a single stack, use a navigation path instead. The path uses type erasure so you can manage a collection of heterogeneous elements.

서로 다른 타입의 값들을 한 배열에 담아 두고, 나중에 "이 값이 어느 `navigationDestination`에 해당하는가"를 판별해야 한다. 값을 비교하고 딕셔너리로 찾으려면 `Hashable`(과 그 상위인 `Equatable`)이 필요하다.

`append`가 `Codable`까지 요구하는 것도 이유가 있다. 네비게이션 상태를 저장했다가 복원할 수 있게 하기 위해서다.

> When the values you present on the navigation stack conform to the `Codable` protocol, you can use the path's `codable` property to get a serializable representation of the path.

`Route`는 연관값 없는 `enum`이라 `Codable`도 자동 합성된다. 그래서 명시하지 않아도 `append`가 통과한다.

### 자동 합성 — 그래서 한 줄이면 된다

Swift가 조건이 맞으면 구현을 만들어 준다.

> Swift can automatically provide the protocol conformance for `Equatable`, `Hashable`, and `Comparable` in many simple cases. Using this synthesized implementation means you don't have to write repetitive boilerplate code to implement the protocol requirements yourself.

`Hashable` 자동 합성 조건은 셋이다.

> Swift provides a synthesized implementation of `Hashable` for the following kinds of custom types:
> - Structures that have only stored properties that conform to the `Hashable` protocol
> - Enumerations that have only associated types that conform to the `Hashable` protocol
> - **Enumerations that have no associated types**

`Route`는 세 번째다. `case test`, `case support` 둘 다 연관값이 없으므로 `hash(into:)`와 `==`를 Swift가 만들어 준다.

**단, 선언은 해야 한다.**

> Note: Types don't automatically adopt a protocol just by satisfying its requirements. They must always explicitly declare their adoption of the protocol.

즉 `enum Route { }`라고만 쓰면 `Hashable`이 아니다. 조건을 만족해도 **선언이 있어야** 합성이 일어난다. 이것이 `: Hashable`을 쓴 이유다.

한 가지 예외가 있다. **연관값도 raw value도 없는 `enum`은 선언 없이도 `Equatable`·`Hashable`로 동작한다.** Swift가 그런 `enum`을 특별 취급하기 때문이다.

```swift
enum Direction { case up, down }
Direction.up == Direction.down     // 선언 없이도 컴파일된다
```

그래서 이론적으로는 `Route`에서 `: Hashable`을 빼도 될 수 있다. 하지만 **명시하는 편이 낫다.** 이유는 세 가지다.

- 나중에 연관값을 추가하면 그 순간 자동 준수가 깨진다.
- 제네릭 제약(`where D : Hashable`)을 만족시키려면 명시적 준수가 안전하다.
- 읽는 사람에게 "이 타입은 해시 키로 쓰인다"는 의도가 전달된다.

### 연관값이 있으면 어떻게 되나

`Route`를 이렇게 확장한다고 하자.

```swift
enum Route: Hashable {
    case test
    case support
    case detail(id: String)      // 연관값 추가
}
```

`String`이 `Hashable`이므로 여전히 자동 합성된다. 딥링크에 파라미터를 실을 때 자연스러운 확장이다.

```swift
case "detail":
    if let id = url.pathComponents.dropFirst().first {
        path.append(Route.detail(id: id))
    }
```

하지만 연관값이 `Hashable`이 아니면 합성이 안 된다.

```swift
class Payload { }                     // Hashable 아님

enum Route: Hashable {
    case detail(Payload)              // ⚠️ 자동 합성 불가
}
```

이 경우 직접 구현해야 한다.

```swift
enum Route: Hashable {
    case detail(Payload)

    static func == (lhs: Route, rhs: Route) -> Bool { /* ... */ }
    func hash(into hasher: inout Hasher) { /* ... */ }
}
```

### `enum`이 흔히 채택하는 프로토콜들

`Hashable`은 여러 선택지 중 하나다.

| 프로토콜 | 언제 | 자동 합성 |
| --- | --- | --- |
| `Hashable` | 딕셔너리 키, `Set`, `NavigationPath` | 조건부 O |
| `Equatable` | `==` 비교 (`Hashable`이 포함) | 조건부 O |
| `CaseIterable` | `allCases`로 전체 순회 | 연관값 없으면 O |
| `Codable` | JSON 인코딩·디코딩 | 조건부 O |
| `Identifiable` | `ForEach`, `List` | X (직접 `id` 제공) |
| `RawRepresentable` | `String`/`Int` raw value | raw value 지정 시 O |
| `Comparable` | 순서 비교 | 조건부 O |
| `Error` | `throw` 대상 | O (요구사항 없음) |

`Route`에 `CaseIterable`을 붙이면 딥링크 테스트용으로 전체 라우트를 순회할 수 있다.

```swift
enum Route: Hashable, CaseIterable {
    case test
    case support
}

Route.allCases.count   // 2
```

### 언제 `Hashable`이 필요 없나

- 단순히 `switch`로 분기만 하는 `enum`
- 연관값을 담아 전달만 하는 `enum`
- `Error`로만 쓰는 `enum`

```swift
enum LoadState {          // Hashable 불필요
    case idle
    case loading
    case loaded([Item])
    case failed(Error)
}
```

`Error`는 `Hashable`이 아니므로 이 `enum`은 자동 합성도 안 된다. 그래도 `switch` 분기에는 아무 문제가 없다.

**필요할 때만 붙인다**는 것이 원칙이다. 불필요한 프로토콜은 나중에 타입을 확장할 때 족쇄가 된다.

### 이 예제에서 확인할 것

`Route`는 딥링크 목적지를 타입으로 표현한 것이다. 문자열을 직접 넘기는 방식과 비교하면 장점이 분명하다.

```swift
// 문자열 방식 — 오타를 컴파일러가 못 잡는다
path.append("tset")

// enum 방식 — 오타는 컴파일 에러
path.append(Route.test)
```

`navigationDestination`의 `switch`에서도 `default` 없이 모든 case를 처리하게 강제된다. case를 추가하면 컴파일러가 빠뜨린 곳을 알려 준다.

## 학습 체크리스트

- [ ] `enum Route: Hashable`에서 `: Hashable`을 지우고 컴파일되는지 확인한다.
- [ ] 지운 상태에서 `case detail(Payload)`처럼 `Hashable`이 아닌 연관값을 추가해 에러를 본다.
- [ ] `path.append`의 시그니처를 확인해 `Codable` 제약도 있음을 확인한다.
- [ ] `Route`에 `case detail(id: String)`을 추가하고 딥링크 파라미터를 실어 본다.
- [ ] `Route`에 `CaseIterable`을 붙이고 `allCases`를 출력한다.
- [ ] `Route`를 `Set<Route>`에 담아 `Hashable`이 실제로 쓰이는지 확인한다.
- [ ] `hash(into:)`를 직접 구현해 자동 합성을 덮어써 본다.
- [ ] 연관값 없는 `enum`이 선언 없이도 `==` 비교되는 것을 확인한다.
- [ ] `struct`에 `Hashable`을 붙이고 저장 프로퍼티 하나를 비-`Hashable` 타입으로 바꿔 에러를 본다.
- [ ] `navigationDestination`의 `switch`에서 case 하나를 지우고 컴파일 에러를 확인한다.
- [ ] `Route` 대신 `String`을 `path.append`에 넘겨 보고 어떤 차이가 있는지 비교한다.

## 공식 참고 자료

- [Swift 공식 문서: Protocols — Adopting a Protocol Using a Synthesized Implementation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/#Adopting-a-Protocol-Using-a-Synthesized-Implementation)
- [Swift 공식 문서: Enumerations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/)
- [Swift 공식 문서: Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [Apple: Equatable](https://developer.apple.com/documentation/swift/equatable)
- [Apple: CaseIterable](https://developer.apple.com/documentation/swift/caseiterable)
- [Apple: NavigationPath](https://developer.apple.com/documentation/swiftui/navigationpath)
- [Apple: NavigationPath.append(_:)](https://developer.apple.com/documentation/swiftui/navigationpath/append(_:))
- [Apple: view.navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
