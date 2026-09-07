# Swift의 타입 체계와 상속 구조

`struct`와 `class`의 값/참조 의미 차이는 [`struct`와 `class`](./struct-vs-class.md)에서 다룬다. 이 문서는 **무엇이 무엇을 상속·준수할 수 있는가**라는 체계 쪽에 집중한다.

## 질문이 나온 코드

`chapter-29/chapter-29/ContentView.swift`의 `struct Courses: Identifiable`과 `struct ContentView: View`

## 공부할 내용

### 결론부터 — Swift에 추상 클래스는 없다

다른 언어에서 오면 가장 헷갈리는 지점이다. Swift에는 **abstract class라는 문법이 없다.** "구현을 일부 제공하면서 나머지는 하위 타입이 채우게 하는" 역할은 **protocol + protocol extension**이 대신한다. 그래서 Swift의 타입 체계는 "클래스 상속 계층"이 아니라 **"protocol 준수(conformance)"**를 중심으로 짜인다.

### 상속(inheritance)이 가능한 것은 class뿐이다

> "Any class that doesn't inherit from another class is known as a base class."

클래스만 다른 클래스를 상속할 수 있고, **단일 상속**이다. 상속하면 저장 프로퍼티·메서드를 물려받고 `override`로 재정의할 수 있다.

`struct`와 `enum`은 **다른 타입을 상속할 수 없다.** `struct Courses: Identifiable`의 콜론은 상속이 아니라 **protocol 준수**를 뜻한다. 문법이 같아 보이지만 의미가 다르다.

| 타입 | 상속 | protocol 준수 | 값/참조 |
| --- | --- | --- | --- |
| `class` | 가능 (단일) | 가능 (다중) | 참조 |
| `struct` | 불가 | 가능 (다중) | 값 |
| `enum` | 불가 | 가능 (다중) | 값 |
| `protocol` | 다른 protocol 상속 가능 (다중) | — | — |

### protocol은 다중으로 붙일 수 있고, protocol끼리도 상속한다

준수는 개수 제한이 없다. `struct Foo: Identifiable, Hashable, Codable`처럼 여러 개를 붙일 수 있다. 클래스 상속이 하나로 제한되는 것과 대비된다.

protocol 자체도 다른 protocol을 상속한다.

> "A protocol can inherit one or more other protocols and can add further requirements on top of the requirements it inherits."

```swift
protocol PrettyTextRepresentable: TextRepresentable {
    var prettyTextualDescription: String { get }
}
```

### 기본 구현은 protocol extension이 준다 — 추상 클래스의 대체재

> "You can use protocol extensions to provide a default implementation to any method or computed property requirement of that protocol. If a conforming type provides its own implementation of a required method or property, that implementation will be used instead of the one provided by the extension."

```swift
extension PrettyTextRepresentable {
    var prettyTextualDescription: String { textualDescription }
}
```

protocol이 "무엇을 해야 하는가"를 정하고, extension이 "기본적으로는 이렇게 한다"를 제공하며, 준수 타입이 필요하면 덮어쓴다. 상속 계층 없이도 코드 재사용이 되는 구조다. 다만 **protocol extension은 저장 프로퍼티를 추가할 수 없다.** 상태를 물려주려면 클래스 상속이 필요하다.

### class 전용 protocol

값 타입은 못 붙이게 제한할 수도 있다.

> "You can limit protocol adoption to class types (and not structures or enumerations) by adding the `AnyObject` protocol to a protocol's inheritance list."

```swift
protocol SomeClassOnlyProtocol: AnyObject { }
```

### 무엇을 기본으로 고를까

Swift 공식 가이드의 권고는 명확하다.

> "As a general guideline, prefer structures because they're easier to reason about, and use classes when they're appropriate or necessary. In practice, this means most of the custom types you define will be structures and enumerations."

SwiftUI가 `View`를 protocol로 두고 `struct ContentView: View`를 쓰게 하는 것도 같은 맥락이다. 화면을 상속 계층으로 쌓지 않고, 값 타입 조각을 조립하고 protocol로 규약을 맞춘다. 상속이 필요한 순간(참조 의미, `deinit`, Objective-C 상호운용 등)에만 `class`를 쓴다.

## 학습 체크리스트

- [ ] `struct Courses: SomeOtherStruct`를 시도해 어떤 오류가 나는지 확인한다.
- [ ] `Courses`에 `Hashable`, `Codable`을 함께 붙여 protocol이 여러 개 붙는 것을 확인한다.
- [ ] protocol 하나와 그 extension으로 기본 구현을 만들고, 준수 타입에서 덮어쓰기 전후 동작을 비교한다.
- [ ] protocol extension에 저장 프로퍼티를 추가해 보고 왜 안 되는지 오류 메시지로 확인한다.
- [ ] 클래스 두 개로 상속 계층을 만들고 `override`와 `final`을 실험한다.
- [ ] `AnyObject`를 붙인 protocol에 `struct`를 준수시켜 컴파일 오류를 본다.
- [ ] `struct ContentView: View`의 `View`가 왜 클래스가 아니라 protocol인지 자신의 말로 설명한다.

## 참고 자료

- [The Swift Programming Language: Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
- [The Swift Programming Language: Inheritance](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/inheritance/)
- [The Swift Programming Language: Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [The Swift Programming Language: Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/)
- [The Swift Programming Language: Initialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/)
- [Apple: Choosing Between Structures and Classes](https://developer.apple.com/documentation/swift/choosing-between-structures-and-classes)
- [Apple: AnyObject](https://developer.apple.com/documentation/swift/anyobject)
- [Apple: View](https://developer.apple.com/documentation/swiftui/view)
