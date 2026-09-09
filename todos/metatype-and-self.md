# `SomeType.self`의 정체 — 메타타입과 `.self` 표현식

## 질문이 나온 코드

`chapter-47/chapter-47/ContentView.swift`

```swift
Color.clear
    .preference(
        key: SizePreferenceKey.self,
        value: proxy.size
    )
```

```swift
.onPreferenceChange(SizePreferenceKey.self, perform: action)
```

`SizePreferenceKey.self`는 인스턴스인가, 타입 자체인가?

## 공부할 내용

### 결론 먼저

- **타입 자체**다. 인스턴스가 아니다.
- `SizePreferenceKey.self`의 타입은 `SizePreferenceKey.Type`이고, 이것을 **메타타입(metatype)** 이라 부른다.
- 인스턴스를 만들려면 `SizePreferenceKey()`라고 써야 한다. `.self`는 괄호가 없다.
- SwiftUI가 타입을 요구하는 이유는 **이 키를 값이 아니라 식별자로 쓰기 때문**이다.

### 메타타입 — 타입의 타입

Swift 공식 문서의 정의가 정확하다.

> A *metatype type* refers to the type of any type, including class types, structure types, enumeration types, and protocol types.
>
> The metatype of a class, structure, or enumeration type is the name of that type followed by `.Type`. The metatype of a protocol type — not the concrete type that conforms to the protocol at runtime — is the name of that protocol followed by `.Protocol`. For example, the metatype of the class type `SomeClass` is `SomeClass.Type` and the metatype of the protocol `SomeProtocol` is `SomeProtocol.Protocol`.

정리하면 이렇다.

| 표기 | 의미 | 예 |
| --- | --- | --- |
| `SizePreferenceKey` | 타입 이름 (선언 문맥) | `let k: SizePreferenceKey` |
| `SizePreferenceKey()` | **인스턴스** | 값 하나 |
| `SizePreferenceKey.self` | **타입 값** (메타타입의 인스턴스) | 타입 자체를 값처럼 |
| `SizePreferenceKey.Type` | 메타타입 **타입** | `.self`가 갖는 타입 |

세 층으로 보면 이해가 쉽다.

```text
값 층      CGSize(width: 100, height: 50)      ← 인스턴스
타입 층    CGSize                              ← 그 값의 타입
메타 층    CGSize.self : CGSize.Type           ← 타입을 값으로 다룬 것
```

`Int`로 확인해 보면 더 분명하다.

```swift
let a = 5              // a: Int          — 인스턴스
let b = Int.self       // b: Int.Type     — 타입 값
let c = Int()          // c: Int          — 인스턴스 (0)

print(a)               // 5
print(b)               // Int
print(type(of: a))     // Int
print(type(of: b))     // Int.Type
```

### `.self`는 "타입을 값으로 꺼내는" 표현식이다

> You can use the postfix `self` expression to access a type as a value. For example, `SomeClass.self` returns `SomeClass` itself, not an instance of `SomeClass`. And `SomeProtocol.self` returns `SomeProtocol` itself, not an instance of a type that conforms to `SomeProtocol` at runtime.

`SizePreferenceKey.self`는 `SizePreferenceKey`라는 **타입 그 자체**를 값으로 만든 것이다. `SizePreferenceKey` 인스턴스는 애초에 만들어지지도 않는다.

실제로 예제의 `SizePreferenceKey`는 **인스턴스를 만들 이유가 전혀 없는 타입**이다. 멤버가 전부 `static`이기 때문이다.

```swift
struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: Value = .zero                              // static
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { } // static
}
```

저장 프로퍼티가 하나도 없으니 인스턴스를 만들어 봐야 담을 것이 없다. **타입 자체가 곧 하나의 설정 묶음**인 셈이다.

### 인스턴스의 `self`와는 다르다

같은 `self`라는 단어가 두 곳에서 다르게 쓰인다. 헷갈리기 쉬운 지점이다.

> In an initializer, subscript, or instance method, `self` refers to the current instance of the type in which it occurs. In a type method, `self` refers to the current type in which it occurs.

```swift
struct Counter {
    var count = 0

    mutating func increase() {
        self.count += 1        // ← 인스턴스 self: 현재 인스턴스
    }

    static func describe() {
        print(self)            // ← 타입 메서드 안의 self: 타입 자체 (Counter)
    }
}

let meta = Counter.self        // ← 후위 self 표현식: 타입을 값으로
```

- **`self.count`** — 인스턴스 내부에서 자기 자신을 가리킴
- **`Counter.self`** — 타입 이름 뒤에 붙여 타입을 값으로 꺼냄

이름만 같고 역할이 다르다. 예제의 `SizePreferenceKey.self`는 세 번째, 후위 표현식이다.

`\.self` 형태도 또 다른 것이다. `ForEach(0..<n, id: \.self)`의 `\.self`는 **key path**이며, 값 자신을 가리키는 경로다. 이 얘기는 [ForEach의 id와 key path](./foreach-id-and-identity-keypath.md)에 있다.

### 대문자 `Self`는 또 다른 것이다 — `chapter-80`의 사례

`chapter-80/chapter-80/Models/ExchangeRate.swift`에 이런 코드가 있다.

```swift
extension ExchangeRate {
    static var placeholder: ExchangeRate {
        // TODO, Self 는 뭐야? .init 과 다른건가?
        Self(date: nil, rates: nil)
    }
}
```

**대문자 `Self`는 "현재 타입"을 가리키는 타입 이름**이다. 소문자 `self`와 완전히 다르다.

| 표기 | 의미 | 위치 |
| --- | --- | --- |
| `self` | 현재 **인스턴스** (또는 타입 메서드에서는 타입) | 값 |
| `Self` | 현재 **타입** | **타입 자리** |
| `Type.self` | 타입을 값으로 꺼낸 것 (메타타입) | 값 |

> Inside a class, structure, or enumeration declaration, `Self` refers to the type introduced by the declaration.

즉 `ExchangeRate`의 `extension` 안에서 `Self`는 `ExchangeRate`와 같다.

```swift
Self(date: nil, rates: nil)          // = ExchangeRate(date: nil, rates: nil)
```

**질문의 "`.init`과 다른건가"에 답하면 — 세 표기가 모두 같은 것을 뜻한다.**

```swift
Self(date: nil, rates: nil)              // Self를 타입 이름으로
Self.init(date: nil, rates: nil)         // init을 명시
ExchangeRate(date: nil, rates: nil)      // 타입 이름을 직접
.init(date: nil, rates: nil)             // 타입이 추론되면 생략
```

마지막 형태가 [implicit member expression](./static-type-properties-and-implicit-init.md)이다. 반환 타입이 `ExchangeRate`로 적혀 있으므로 타입을 생략할 수 있다.

**`Self`를 쓰는 이점**

- **타입 이름이 바뀌어도 고쳐 쓸 필요가 없다.** `ExchangeRate`를 `Rate`로 리네임하면 `Self`는 그대로 동작한다
- 타입 이름이 길면 짧아진다
- 제네릭 타입에서 타입 파라미터를 다시 쓰지 않아도 된다

**프로토콜에서 특히 유용하다.**

```swift
protocol Duplicatable {
    func duplicate() -> Self      // 채택하는 타입 자신을 반환
}

struct Item: Duplicatable {
    func duplicate() -> Self { Self() }    // Item을 반환
}
```

`Self`가 없다면 프로토콜에서 "구현하는 타입 자신"을 표현할 방법이 없다. [`Hashable`의 `==`](./hash-into-and-java-comparison.md) 시그니처에도 `Self`가 등장한다.

```swift
static func == (lhs: Self, rhs: Self) -> Bool
```

**`class`에서는 의미가 조금 다르다.** 상속이 있으면 `Self`는 **런타임의 실제 타입**을 가리킨다.

```swift
class Base {
    func make() -> Self { Self() }    // 하위 클래스에서는 하위 타입을 반환
}
```

`struct`는 상속이 없으므로 항상 선언된 타입과 같다.

### 왜 SwiftUI는 인스턴스가 아니라 타입을 받는가

`preference`와 `onPreferenceChange`의 시그니처를 보면 명확하다.

```swift
nonisolated func preference<K>(key: K.Type = K.self, value: K.Value) -> some View
    where K : PreferenceKey
```

```swift
nonisolated func onPreferenceChange<K>(
    _ key: K.Type = K.self,
    perform action: @escaping (K.Value) -> Void
) -> some View where K : PreferenceKey, K.Value : Equatable
```

파라미터 타입이 `K.Type`이다. 이유는 세 가지다.

**① 키는 값이 아니라 식별자다**

preference 시스템은 "어떤 종류의 값인가"로 데이터를 구분한다. 서로 다른 두 `SizePreferenceKey` 인스턴스가 있으면 오히려 곤란하다. 타입은 프로그램 전체에서 유일하므로 **완벽한 식별자**가 된다.

**② 필요한 정보가 전부 `static`이다**

`defaultValue`와 `reduce`는 타입 멤버다. 인스턴스 없이 `K.defaultValue`, `K.reduce(...)`로 호출할 수 있다. 인스턴스를 받을 이유가 없다.

**③ 제네릭 파라미터를 결정한다**

`K`가 정해지면 `K.Value`도 따라 정해진다. `SizePreferenceKey.self`를 넘기는 순간 컴파일러는 `value:`가 `CGSize`여야 한다는 것을 안다. 다른 타입을 넣으면 컴파일 에러다.

두 시그니처 모두 기본값이 `K.Type = K.self`인 점도 흥미롭다. 문맥에서 `K`를 추론할 수 있으면 인자를 생략할 수 있다는 뜻이다.

### 메타타입으로 할 수 있는 일

**타입을 변수에 담고 전달한다**

```swift
let keyType: SizePreferenceKey.Type = SizePreferenceKey.self
```

**메타타입으로 인스턴스를 만든다**

> Use an initializer expression to construct an instance of a type from that type's metatype value. For class instances, the initializer that's called must be marked with the `required` keyword or the entire class marked with the `final` keyword.

```swift
class AnotherSubClass: SomeBaseClass {
    let string: String
    required init(string: String) {
        self.string = string
    }
}
let metatype: AnotherSubClass.Type = AnotherSubClass.self
let anotherInstance = metatype.init(string: "some string")
```

**런타임 타입을 얻는다 — `type(of:)`**

`.self`는 컴파일 시점에 아는 타입을, `type(of:)`는 실제 런타임 타입을 준다.

```swift
class SomeBaseClass {
    class func printClassName() { print("SomeBaseClass") }
}
class SomeSubClass: SomeBaseClass {
    override class func printClassName() { print("SomeSubClass") }
}
let someInstance: SomeBaseClass = SomeSubClass()
// The compile-time type of someInstance is SomeBaseClass,
// and the runtime type of someInstance is SomeSubClass
type(of: someInstance).printClassName()
// Prints "SomeSubClass".
```

`struct`는 상속이 없어 둘이 항상 같지만, `class`에서는 갈린다. [struct와 class](./struct-vs-class.md)의 차이가 여기서도 드러난다.

**`Any`에 담긴다**

> `Any` can be used as the concrete type for an instance of any of the following types: A class, structure, or enumeration / A metatype, such as `Int.self` / A tuple with any types of components / A closure or function type

```swift
let mixed: [Any] = ["one", 2, true, (4, 5.3), { () -> Int in return 6 }]
```

**메모리 레이아웃 조회 같은 제네릭 API**

```swift
MemoryLayout<CGSize>.size
```

### Swift에서 자주 만나는 `.self` 사례

| 코드 | 무엇을 넘기나 |
| --- | --- |
| `SizePreferenceKey.self` | preference 키 식별자 |
| `onGeometryChange(for: CGSize.self)` | 관찰할 값의 타입 |
| `try container.decode(User.self, forKey: .user)` | 디코딩할 목표 타입 |
| `UITableViewCell.self` | 셀 클래스 등록 |
| `String.self`, `Int.self` | 제네릭 함수에 타입 전달 |

공통점은 모두 **"어떤 타입인지"가 곧 정보**인 자리라는 것이다.

### 정리

```text
SizePreferenceKey        타입 이름
SizePreferenceKey()      인스턴스 — 이 예제에서는 만들 이유가 없다
SizePreferenceKey.self   타입을 값으로 꺼낸 것  ← 예제가 쓰는 것
SizePreferenceKey.Type   위 값이 갖는 타입 (메타타입)
```

## 학습 체크리스트

- [ ] `print(SizePreferenceKey.self)`와 `print(type(of: SizePreferenceKey.self))`를 찍어 차이를 본다.
- [ ] `key: SizePreferenceKey()`로 바꿔 어떤 컴파일 에러가 나는지 확인한다.
- [ ] `let t: SizePreferenceKey.Type = SizePreferenceKey.self`가 컴파일되는지 확인한다.
- [ ] `preference(key:)`에서 `key:` 인자를 생략해도 되는지 시험한다 (기본값 `K.self`).
- [ ] `value:`에 `CGSize`가 아닌 값을 넣어 `K.Value` 제약이 작동하는 것을 확인한다.
- [ ] `let a = 5; let b = Int.self`의 `type(of:)` 결과를 비교한다.
- [ ] 인스턴스 메서드의 `self.count`와 `Counter.self`가 서로 다른 것임을 코드로 구분해 본다.
- [ ] 클래스 상속을 만들고 `type(of:)`가 런타임 타입을 주는 것을 확인한다.
- [ ] `Codable`로 `decode(User.self, forKey:)`를 써 보고 왜 타입을 넘기는지 설명한다.
- [ ] `\.self` key path와 `.self` 메타타입이 왜 다른지 한 문장으로 정리한다.
- [ ] `[Any]` 배열에 `Int.self`를 담아 메타타입도 값임을 확인한다.
- [ ] `Self(date: nil, rates: nil)`을 `ExchangeRate(...)`로 바꿔도 같은지 확인한다.
- [ ] `.init(date: nil, rates: nil)`으로도 되는지 확인한다 (타입 추론).
- [ ] 타입 이름을 리네임하고 `Self`는 고칠 필요가 없는 것을 확인한다.
- [ ] `Self`를 타입이 아닌 값 자리에 써 보고 에러를 확인한다.
- [ ] 프로토콜에 `func duplicate() -> Self`를 선언해 구현해 본다.
- [ ] `class`에서 `Self`가 하위 타입을 가리키는지 실험한다.

## 공식 참고 자료

- [Swift 공식 문서: Types — Metatype Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Metatype-Type)
- [Swift 공식 문서: Types — Self Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Self-Type)
- [Swift 공식 문서: Types — Any Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Any-Type)
- [Swift 공식 문서: Expressions — Self Expression](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Self-Expression)
- [Swift 공식 문서: Methods — Type Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/methods/#Type-Methods)
- [Apple: type(of:)](https://developer.apple.com/documentation/swift/type(of:))
- [Apple: view.preference(key:value:)](https://developer.apple.com/documentation/swiftui/view/preference(key:value:))
- [Apple: view.onPreferenceChange(_:perform:)](https://developer.apple.com/documentation/swiftui/view/onpreferencechange(_:perform:))
- [Apple: MemoryLayout](https://developer.apple.com/documentation/swift/memorylayout)
