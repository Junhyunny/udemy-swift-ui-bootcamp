# `typealias`는 왜 쓰는가 — 그리고 이 코드에서는 왜 없어도 되는가

## 질문이 나온 코드

`chapter-47/chapter-47/ContentView.swift`

```swift
struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize

    static let defaultValue: Value = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
```

질문이 정확하다. `Value`라는 별칭을 만들어 놓고 `reduce`에서는 `CGSize`를 그대로 쓴다. 그러면 이 줄에 의미가 있는가?

## 공부할 내용

### 결론 먼저

- **이 코드에서 `typealias Value = CGSize`는 지워도 컴파일된다.** Swift가 타입 추론으로 알아낸다.
- 그럼에도 남겨 두는 것은 **문서화 목적**이다. 이 키가 무엇을 나르는지 한 줄로 선언한다.
- `reduce`에서 `Value` 대신 `CGSize`를 쓴 것은 **일관성이 없는 쪽**이다. 둘 중 하나로 통일하는 편이 낫다.
- 여기서의 `typealias`는 단순 별칭이 아니라 **프로토콜의 `associatedtype`을 확정**하는 특수한 역할을 겸한다. 이 점이 핵심이다.

### `typealias`의 기본 — 새 타입이 아니라 새 이름

> A *type alias declaration* introduces a named alias of an existing type into your program. (…) Type aliases don't create new types; they simply allow a name to refer to an existing type.

```swift
typealias Name = ExistingType
```

**새 타입을 만들지 않는다**는 점이 중요하다. 완전히 같은 타입의 다른 이름일 뿐이라 서로 자유롭게 대입된다.

```swift
typealias UserID = String

let a: UserID = "abc"
let b: String = a        // OK — 같은 타입이다
```

그래서 타입 안전성을 얻고 싶다면 `typealias`가 아니라 `struct`로 감싸야 한다.

```swift
struct UserID { let raw: String }   // 이건 진짜 다른 타입
```

이미 봐 온 예로는 `CGFloat.NativeType`이 있다.

```swift
typealias NativeType = Double
```

[Core Graphics 타입 문서](./coregraphics-types-and-cgfloat.md)에서 정리한 대로, 아키텍처에 따라 `Float`이나 `Double`을 가리키는 별칭이다.

### 일반적으로 `typealias`를 쓰는 이유

**1. 긴 제네릭 타입을 짧게**

```swift
typealias StringDictionary<Value> = Dictionary<String, Value>

// 아래 두 딕셔너리는 같은 타입이다
var dictionary1: StringDictionary<Int> = [:]
var dictionary2: Dictionary<String, Int> = [:]
```

**2. 복잡한 클로저 타입에 이름 붙이기**

이 예제와 직접 관련이 있다.

```swift
typealias SizeHandler = (CGSize) -> Void

func measureSize(perform action: @escaping SizeHandler) -> some View { ... }
```

`(CGSize) -> Void`가 여러 곳에 반복된다면 이름을 붙일 가치가 있다.

**3. 의미를 드러내기**

```swift
typealias Seconds = Double
typealias Percentage = Double

func fadeOut(duration: Seconds) { }
```

타입 체크는 못 해 주지만 시그니처를 읽기 쉽게 만든다.

**4. 여러 프로토콜 묶기**

```swift
typealias Model = Identifiable & Codable & Equatable
```

**5. 제네릭 파라미터 제약은 그대로 물려받는다**

> Because the type alias and the existing type can be used interchangeably, the type alias can't introduce additional generic constraints.

```swift
typealias DictionaryOfInts<Key: Hashable> = Dictionary<Key, Int>
```

원본의 제약과 정확히 같아야 하고, 별칭이 제약을 새로 추가할 수는 없다.

### 그런데 이 코드의 `typealias`는 성격이 다르다

`PreferenceKey`의 선언을 보면 이유가 보인다.

```swift
protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
    static func reduce(value: inout Self.Value, nextValue: () -> Self.Value)
}
```

`Value`는 프로토콜이 선언한 **`associatedtype`**, 즉 "구현하는 쪽이 정할 자리 표시자"다.

> An *associated type* gives a placeholder name to a type that's used as part of the protocol. The actual type to use for that associated type isn't specified until the protocol is adopted. Associated types are specified with the `associatedtype` keyword.

프로토콜을 채택하는 타입은 이 자리를 **채워야** 한다. 채우는 방법이 두 가지다.

- 명시적으로 `typealias Value = CGSize`라고 쓴다.
- 요구사항 구현부의 시그니처를 보고 **컴파일러가 추론하게** 둔다.

즉 여기서의 `typealias`는 "긴 이름을 줄이는 별칭"이 아니라 **associated type을 구체 타입으로 확정하는 선언**이다.

### 그래서 지워도 되는가 — 공식 문서의 답

Swift 공식 문서가 `Container` 프로토콜 예제로 정확히 이 질문에 답한다.

```swift
protocol Container {
    associatedtype Item
    mutating func append(_ item: Item)
    var count: Int { get }
    subscript(i: Int) -> Item { get }
}
```

```swift
struct IntStack: Container {
    // ...
    typealias Item = Int
    mutating func append(_ item: Int) { self.push(item) }
    var count: Int { return items.count }
    subscript(i: Int) -> Int { return items[i] }
}
```

> The definition of `typealias Item = Int` turns the abstract type of `Item` into a concrete type of `Int` for this implementation of the `Container` protocol.
>
> Thanks to Swift's type inference, you don't actually need to declare a concrete `Item` of `Int` as part of the definition of `IntStack`. Because `IntStack` conforms to all of the requirements of the `Container` protocol, Swift can infer the appropriate `Item` to use, simply by looking at the type of the `append(_:)` method's `item` parameter and the return type of the subscript. Indeed, **if you delete the `typealias Item = Int` line from the code above, everything still works**, because it's clear what type should be used for `Item`.

이 예제에 그대로 적용된다. `reduce(value: inout CGSize, ...)`에서 `CGSize`를 썼기 때문에 컴파일러는 `Value == CGSize`임을 추론할 수 있다. **그래서 `typealias Value = CGSize`를 지워도 그대로 동작한다.**

```swift
// 이렇게 써도 컴파일된다
struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
```

### 그럼 굳이 쓸 이유가 있나 — 세 가지 관점

**① 문서화 — 이건 실질적 가치가 있다**

`typealias Value = CGSize` 한 줄이 파일 위쪽에 있으면 "이 preference key는 `CGSize`를 나른다"가 즉시 보인다. 없으면 `reduce`의 시그니처까지 읽어야 안다. 키가 여러 개인 파일에서는 차이가 크다.

**② 추론이 안 되는 경우가 있다**

요구사항 구현만으로 associated type을 결정할 수 없을 때는 **필수**가 된다.

```swift
protocol Transformer {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) -> Output
}

// 이 경우는 시그니처에서 추론된다
struct A: Transformer {
    func transform(_ input: Int) -> String { "\(input)" }
}
```

하지만 associated type이 제네릭 파라미터에 얽혀 있거나 기본 구현이 끼어들면 추론이 실패한다. 그때는 명시가 답이다. 에러 메시지가 `type 'X' does not conform to protocol 'Y'`처럼 뭉뚱그려 나오기 때문에, 명시해 두면 디버깅도 쉬워진다.

**③ 본문에서 `Value`를 실제로 쓸 때 의미가 산다**

지금 코드는 여기서 어긋나 있다.

```swift
static let defaultValue: Value = .zero                                  // Value 사용
static func reduce(value: inout CGSize, nextValue: () -> CGSize) { }    // CGSize 사용
```

같은 타입을 두 이름으로 부르고 있다. 둘 중 하나로 통일하는 게 낫다.

```swift
// 안 ① — Value로 통일. 나중에 타입을 바꿀 때 typealias 한 줄만 고치면 된다
struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static let defaultValue: Value = .zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

// 안 ② — 구체 타입으로 통일. 짧고 직관적이다
struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
```

안 ①이 리팩터링에 유리하다. `CGSize`를 `[CGSize]`로 바꾸고 싶어지면 `typealias` 줄 하나만 고치면 된다.

### `typealias` vs `associatedtype` 정리

| | `typealias` | `associatedtype` |
| --- | --- | --- |
| 어디에 쓰나 | 어디서나 (전역, 타입 내부, 프로토콜 내부) | 프로토콜 선언 안에서만 |
| 의미 | 이미 정해진 타입의 다른 이름 | 아직 안 정해진 타입의 자리 표시자 |
| 누가 정하나 | 선언하는 쪽에서 즉시 확정 | 채택하는 타입이 나중에 확정 |
| 이 코드에서 | `SizePreferenceKey`가 `Value = CGSize`로 확정 | `PreferenceKey`가 `Value`를 선언 |

이미 본 다른 사례로는 `ViewModifier.Content`가 있다. 이것도 `typealias Content`로 선언된 자리이고, [ViewModifier 문서](./view-modifier-protocol.md)에서 다룬다. 프로토콜 요구사항 일반에 대한 이야기는 [protocol 요구사항과 style 프로토콜](./protocol-requirements-and-style-protocols.md)에 있다.

## 학습 체크리스트

- [ ] `typealias Value = CGSize` 줄을 지우고 여전히 컴파일되는지 확인한다.
- [ ] 지운 상태에서 `SizePreferenceKey.Value`를 참조해 타입이 `CGSize`로 잡히는지 확인한다.
- [ ] `reduce`의 `CGSize`를 `Value`로 바꿔 통일한 뒤 동작이 같은지 확인한다.
- [ ] `typealias`만 `[CGSize]`로 바꾸고 어떤 컴파일 에러가 어디서 나는지 관찰한다.
- [ ] `typealias UserID = String`을 만들어 `String` 변수에 대입되는 것을 확인한다 (새 타입이 아님).
- [ ] 같은 것을 `struct UserID { let raw: String }`으로 만들어 대입이 막히는 것과 비교한다.
- [ ] `typealias SizeHandler = (CGSize) -> Void`로 `measureSzie`의 시그니처를 정리해 본다.
- [ ] `typealias StringDictionary<Value> = Dictionary<String, Value>`를 선언해 제네릭 별칭을 써 본다.
- [ ] 별칭에 원본보다 강한 제약을 추가하려 시도해 실패하는 것을 확인한다.
- [ ] `associatedtype`을 가진 프로토콜을 직접 만들고, 추론되는 경우와 명시가 필요한 경우를 각각 만들어 본다.

## 공식 참고 자료

- [Swift 공식 문서: Declarations — Type Alias Declaration](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Type-Alias-Declaration)
- [Swift 공식 문서: Generics — Associated Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Associated-Types)
- [Swift 공식 문서: Generics — Associated Types with a Generic Where Clause](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Associated-Types-with-a-Generic-Where-Clause)
- [Swift 공식 문서: Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [Apple: PreferenceKey.Value](https://developer.apple.com/documentation/swiftui/preferencekey/value)
- [Apple: CGFloat.NativeType](https://developer.apple.com/documentation/corefoundation/cgfloat-swift.struct/nativetype)
- [Apple: ViewModifier.Content](https://developer.apple.com/documentation/swiftui/viewmodifier/content)
