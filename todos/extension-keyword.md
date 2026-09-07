# `extension` 키워드는 무엇이고 언제 쓰는가

Swift의 타입·상속 체계 전반은 [Swift의 타입 체계와 상속 구조](./swift-type-system-and-inheritance.md)에 정리돼 있다. 이 문서는 `extension` 하나에 집중한다.

## 질문이 나온 코드

`chapter-34/chapter-34/ContentView.swift`의 `extension DTCourse { static var sample: [DTCourse] { ... } }`

## 공부할 내용

### 기존 타입에 기능을 덧붙이는 문법이다

> "Extensions add new functionality to an existing class, structure, enumeration, or protocol type. This includes the ability to extend types for which you don't have access to the original source code (known as retroactive modeling)."

원본 선언을 건드리지 않고 나중에 기능을 추가한다. **소스 코드가 없는 타입에도 쓸 수 있다는 것**이 핵심이다. `String`, `Int`, `Date` 같은 표준 라이브러리 타입에 내 메서드를 붙일 수 있는 이유가 이것이다.

```swift
extension SomeType {
    // 여기에 새 기능
}

extension SomeType: SomeProtocol {
    // 프로토콜 준수도 나중에 추가할 수 있다
}
```

Objective-C의 category와 비슷하지만 이름이 없다.

### 무엇을 추가할 수 있나

- computed instance property, computed **type** property
- 인스턴스 메서드, 타입 메서드
- 초기화 메서드
- subscript
- 중첩 타입
- 프로토콜 준수

### 무엇을 할 수 없나 — 여기가 중요하다

> "Extensions can add new computed properties, but they can't add stored properties, or add property observers to existing properties."

**저장 프로퍼티를 추가할 수 없다.** 그래서 `extension`에 쓰는 프로퍼티는 항상 계산 프로퍼티다. 지금 코드의 `static var sample`도 `{ ... }` 블록을 가진 계산 프로퍼티다.

> "Extensions can add new functionality to a type, but they can't override existing functionality."

**기존 기능을 재정의할 수도 없다.** 상속의 `override`와 다른 점이다.

클래스라면 제약이 하나 더 있다.

> "Extensions can add new convenience initializers to a class, but they can't add new designated initializers or deinitializers to a class."

### 언제 쓰나

**1. 코드를 성격별로 나눌 때** — 가장 흔한 용도다. 타입 본체에는 저장 프로퍼티만 두고, 프로토콜 준수나 헬퍼는 `extension`으로 분리하면 본체가 짧아진다.

```swift
struct DTCourse { /* 저장 프로퍼티만 */ }
extension DTCourse: Codable { }
extension DTCourse { static var sample: [DTCourse] { ... } }
```

지금 코드가 정확히 이 방식이다. `DTCourse`의 데이터 정의와 "미리보기용 샘플 데이터"를 분리해 두었다.

**2. 남의 타입에 기능을 붙일 때** — `extension Date { var koreanFormatted: String { ... } }` 처럼.

**3. 프로토콜에 기본 구현을 줄 때** — protocol extension. Swift에 추상 클래스가 없는 이유이기도 하다.

**4. 조건부로 기능을 줄 때** — `extension Array where Element: Numeric { ... }` 처럼 제약을 걸 수 있다.

### 알아 둘 성질

> "If you define an extension to add new functionality to an existing type, the new functionality will be available on all existing instances of that type, even if they were created before the extension was defined."

extension은 컴파일 시점에 타입에 합쳐지므로, 언제 정의했든 모든 인스턴스가 쓸 수 있다.

주의할 점은 **남용**이다. 표준 타입에 이름이 흔한 메서드를 붙이면 다른 라이브러리와 충돌할 수 있고, 아무 데나 흩어 두면 어디에 정의됐는지 찾기 어려워진다. 파일 단위로 묶고 이름을 구체적으로 짓는 편이 좋다.

## 학습 체크리스트

- [ ] `extension DTCourse`에 저장 프로퍼티를 추가해 보고 오류 메시지를 읽는다.
- [ ] `extension`에 계산 프로퍼티를 추가해 정상 동작하는지 확인한다.
- [ ] `DTCourse`의 `Identifiable` 준수를 본체에서 떼어 `extension DTCourse: Identifiable`로 옮겨 본다.
- [ ] `extension String { var isBlank: Bool { ... } }`처럼 표준 타입을 확장해 본다.
- [ ] `extension Array where Element == DTCourse { ... }`로 조건부 확장을 만든다.
- [ ] `extension`에 인스턴스 메서드를 추가하고 `mutating`이 필요한 경우를 확인한다.
- [ ] 프로토콜 하나를 만들고 `extension`으로 기본 구현을 제공해 본다.
- [ ] `extension`을 별도 파일(`DTCourse+Sample.swift`)로 분리해도 동작하는지 확인한다.

## 참고 자료

- [The Swift Programming Language: Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/)
- [The Swift Programming Language: Protocols — Protocol Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [The Swift Programming Language: Generics — Extending a Generic Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [The Swift Programming Language: Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
- [The Swift Programming Language: Declarations — Extension Declaration](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
