# 타입을 `&`로 묶기 — 프로토콜 합성과 타입을 모으는 문법 총정리

## 질문이 나온 코드

`chapter-156/chapter-156/ContentView.swift`

```swift
protocol SegmentItem: Hashable & CaseIterable & RawRepresentable
where RawValue == String {
    var icon: String { get }
    var color: Color { get }
}
```

```swift
struct ReusableSegmentedControl<T: SegmentItem>: View
where T.RawValue == String {
    // ...
}
```

`&`로 타입을 묶는 것이 무엇인지, 그리고 **타입을 확장하거나 모으는 문법들**을 한번에 정리하는 것이 질문이다.

## 공부할 내용

### 결론 먼저

`A & B`는 **프로토콜 합성(protocol composition)**이다. "A도 만족하고 B도 만족하는 타입"이라는 뜻의 **이름 없는 임시 타입**을 그 자리에서 만든다.

공식 문서의 설명이 정확하다.

> Protocol compositions behave as if you defined a temporary local protocol that has the combined requirements of all protocols in the composition.

핵심은 **"임시(temporary)"**다. `&`는 새 타입을 선언하는 게 아니라 **요구사항을 그 자리에서 합쳐 쓰는 표현**이다. 이름이 필요하면 `typealias`로 붙여 주거나 `protocol`로 따로 선언해야 한다.

### 큰 그림 — 타입을 "모으는" 문법은 여섯 가지

| 문법 | 하는 일 | 새 이름이 생기나 |
|---|---|---|
| `A & B` | 여러 요구사항을 **그 자리에서** 합침 | ✗ |
| `typealias X = A & B` | 합성에 **별명**을 붙임 | 별명만 |
| `protocol X: A, B` | 합성을 **새 프로토콜로 선언** | ✓ |
| `<T: A & B>` | 제네릭 파라미터에 **제약**을 검 | ✗ |
| `where` 절 | 연관 타입까지 **조건**을 검 | ✗ |
| `extension X: P` | 기존 타입에 **나중에 채택**을 추가 | ✗ |

아래에서 하나씩 예제로 본다.

---

### 1. `A & B` — 프로토콜 합성

가장 기본 형태다. 파라미터 타입 자리에서 "두 조건을 모두 만족하는 무언가"를 요구한다.

```swift
protocol Named {
    var name: String { get }
}
protocol Aged {
    var age: Int { get }
}

struct Person: Named, Aged {
    var name: String
    var age: Int
}

func wishHappyBirthday(to celebrator: Named & Aged) {
    print("Happy birthday, \(celebrator.name), you're \(celebrator.age)!")
}

wishHappyBirthday(to: Person(name: "Malcolm", age: 21))
// Happy birthday, Malcolm, you're 21!
```

개수 제한은 없다. `A & B & C & D`도 된다. 순서도 의미가 없어 `A & B`와 `B & A`는 같은 타입이다.

### 2. 클래스 하나를 섞을 수 있다

합성에는 **클래스 타입을 하나까지** 넣을 수 있다. "이 클래스를 상속받았으면서 이 프로토콜도 따르는 것"이 된다.

```swift
class Location {
    var latitude: Double
    var longitude: Double
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

class City: Location, Named {
    var name: String
    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        super.init(latitude: latitude, longitude: longitude)
    }
}

func beginConcert(in location: Location & Named) {
    print("Hello, \(location.name)!")
}

beginConcert(in: City(name: "Seattle", latitude: 47.6, longitude: -122.3))
// Hello, Seattle!
```

**클래스는 하나까지만**이다. 둘을 넣으면 컴파일러가 막는다.

```swift
class X {}
class Y {}
func a(_ v: X & Y) {}
// error: protocol-constrained type cannot contain class 'Y'
//        because it already contains class 'X'
```

`struct`나 `enum`은 아예 못 넣는다. 상속이라는 개념이 없어서 "여러 조건을 동시에 만족"이 성립하지 않기 때문이다.

```swift
struct Z {}
func b(_ v: Z & P) {}
// error: non-protocol, non-class type 'Z' cannot be used
//        within a protocol-constrained type
```

정리하면 **`&`에 들어갈 수 있는 것은 프로토콜 여러 개 + 클래스 최대 한 개**다.

### 3. `AnyObject &` — 클래스 전용 제약

`AnyObject`를 섞으면 "참조 타입만"이라는 뜻이 된다.

```swift
protocol SomeClassOnlyProtocol: AnyObject, SomeInheritedProtocol {
    // 클래스만 채택할 수 있다
}

func trackWeakly(_ target: AnyObject & Named) { /* ... */ }
```

`weak` 참조를 잡거나 identity 비교(`===`)를 해야 할 때 쓴다. [`struct`와 `class` 문서](./struct-vs-class.md), [`[weak self]` 문서](./weak-self-and-deinit.md)와 이어진다.

### 4. `typealias`로 이름 붙이기

합성을 자주 쓰면 별명을 붙인다. **표준 라이브러리의 `Codable`이 바로 이것**이다.

```swift
typealias Codable = Decodable & Encodable   // 표준 라이브러리 정의
```

우리 코드에서도 똑같이 할 수 있다.

```swift
typealias Model = Identifiable & Codable & Equatable

func save(_ item: Model) { /* ... */ }
func save<T: Model>(_ items: [T]) { /* ... */ }
```

`typealias`는 **새 타입을 만들지 않는다.** 그냥 긴 이름의 짧은 별칭이다. [`typealias`와 associated type 문서](./typealias-and-associated-type.md), [`Codable`과 `CodingKeys` 문서](./codable-and-codingkey.md)를 참고한다.

### 5. `protocol X: A, B` — 상속으로 진짜 새 타입 만들기

`typealias`와 달리 **새 프로토콜을 선언**하고, 요구사항을 **더 추가**할 수 있다.

```swift
protocol PrettyTextRepresentable: TextRepresentable {
    var prettyTextualDescription: String { get }
}
```

> Anything that adopts `PrettyTextRepresentable` must satisfy all of the requirements enforced by `TextRepresentable`, plus the additional requirements enforced by `PrettyTextRepresentable`.

**상속 목록에서는 `,`와 `&`가 같은 뜻이다.** 질문의 코드가 `&`를 쓴 형태다.

```swift
protocol SegmentItem: Hashable & CaseIterable & RawRepresentable { }   // 질문의 코드
protocol SegmentItem: Hashable, CaseIterable, RawRepresentable { }     // 완전히 같은 의미
```

둘 다 컴파일된다. 쉼표 쪽이 더 흔한 표기지만 취향 차이다.

### `typealias`와 `protocol` 중 무엇을 쓸까

| | `typealias X = A & B` | `protocol X: A, B` |
|---|---|---|
| 요구사항 추가 | ✗ | ✓ |
| 기본 구현(`extension X`) 제공 | ✗ | ✓ |
| 기존 타입이 자동으로 만족 | ✓ (A·B만 따르면 끝) | ✗ (`: X`를 명시해야 함) |
| 새 이름으로 채택 선언 | ✗ | ✓ |

질문의 코드가 `typealias`가 아니라 `protocol`을 쓴 이유가 여기 있다. **`icon`과 `color`라는 요구사항을 새로 추가**해야 했기 때문이다.

```swift
protocol SegmentItem: Hashable & CaseIterable & RawRepresentable
where RawValue == String {
    var icon: String { get }     // ← 추가 요구사항. typealias로는 불가능
    var color: Color { get }
}
```

### 6. 제네릭 제약 `<T: A & B>`

파라미터 타입 자리가 아니라 **제네릭 파라미터 선언**에도 같은 `&`를 쓴다.

```swift
struct ReusableSegmentedControl<T: SegmentItem>: View { }

func allEqual<T: Equatable & Hashable>(_ items: [T]) -> Bool { /* ... */ }
```

여기서도 `&` 대신 `where`로 쓸 수 있다. 셋 다 같은 뜻이다.

```swift
func f<T: A & B>(_ x: T) { }
func f<T>(_ x: T) where T: A & B { }
func f<T>(_ x: T) where T: A, T: B { }
```

[Swift 제네릭 문서](./swift-generics.md)와 이어진다.

### 7. `where` 절 — 연관 타입까지 조건 걸기

`&`로는 표현할 수 없는 것이 있다. **연관 타입의 조건**이다.

```swift
protocol SegmentItem: Hashable & CaseIterable & RawRepresentable
where RawValue == String { }
//    ^^^^^^^^^^^^^^^^^^^^^ 이건 & 로 못 쓴다
```

`RawRepresentable`은 `RawValue`라는 연관 타입을 갖는다. "raw value가 `String`인 `RawRepresentable`"은 `&` 문법으로 표현할 수 없고 `where` 절이 필요하다. 자세한 내용은 [`where` 키워드 문서](./where-clause-usages.md)에 정리되어 있다.

### 8. `some`과 `any`에도 붙는다

Swift 5.7부터 존재 타입에는 `any`를, 불투명 타입에는 `some`을 붙인다.

```swift
func g(_ x: any Named & Aged) { }      // 존재 타입: 실제 타입은 런타임에 결정
func h() -> some Named & Aged { ... }  // 불투명 타입: 하나의 구체 타입으로 고정
```

`View`를 반환할 때 쓰는 `some View`가 바로 이 `some`이다. [`some` 키워드 문서](./some-keyword-opaque-types.md)에 정리되어 있다.

차이를 한 줄로 요약하면 이렇다.

```text
any A & B   → "매번 다른 타입이 올 수 있다"  (박싱 비용 있음)
some A & B  → "항상 같은 하나의 타입인데 밝히지 않는다"  (비용 없음)
```

### 9. `extension`으로 나중에 채택 추가하기

이미 존재하는 타입에 **나중에** 프로토콜을 붙일 수 있다.

```swift
extension String: Named {
    var name: String { self }
}

extension Int: Named, Aged {     // 여러 개를 한 번에
    var name: String { "\(self)" }
    var age: Int { self }
}
```

남의 타입(표준 라이브러리, 서드파티)에도 붙일 수 있다는 것이 Swift 프로토콜의 강력한 점이다. [`extension` 키워드 문서](./extension-keyword.md)와 이어진다.

### 10. 조건부 적합성(conditional conformance)

"원소가 조건을 만족할 때만 이 배열도 조건을 만족한다"를 표현한다.

```swift
extension Array: Named where Element: Named {
    var name: String {
        map(\.name).joined(separator: ", ")
    }
}
```

`[Person]`에는 `name`이 생기고 `[Int]`에는 안 생긴다. 표준 라이브러리의 `Array: Equatable where Element: Equatable`이 같은 구조다.

### 11. 주 연관 타입(primary associated type)

Swift 5.7부터 연관 타입을 꺾쇠로 지정할 수 있다([SE-0346](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md)).

```swift
func f(_ items: any Collection<String>) { }

// 예전에는 where 절이 필요했다
func f<C: Collection>(_ items: C) where C.Element == String { }
```

`RawRepresentable`에는 주 연관 타입이 지정되어 있지 않아 질문의 코드는 여전히 `where`를 써야 한다.

### 12. `&`로 할 수 없는 것들

| 하려는 것 | 가능? | 대신 쓸 것 |
|---|---|---|
| 프로토콜 여러 개 합치기 | ✓ | — |
| 클래스 1개 + 프로토콜 | ✓ | — |
| 클래스 2개 합치기 | ✗ | 클래스 상속은 하나만 |
| struct·enum 합치기 | ✗ | 프로토콜로 추상화 |
| 연관 타입 조건 | ✗ | `where` 절 |
| "A **또는** B" | ✗ | `enum`으로 감싸기 |

마지막이 특히 중요하다. **`&`는 AND만 있고 OR은 없다.** "String이거나 Int"를 표현하려면 enum을 쓴다.

```swift
enum StringOrInt {
    case text(String)
    case number(Int)
}
```

---

### 이 코드에 적용하면

```swift
protocol SegmentItem: Hashable & CaseIterable & RawRepresentable
where RawValue == String {
    var icon: String { get }
    var color: Color { get }
}
```

각 조각이 왜 필요한지 하나씩 보면 이렇다.

| 조각 | 왜 필요한가 | 코드의 어디에서 쓰이나 |
|---|---|---|
| `Hashable` | `ForEach(items, id: \.self)`의 `id`가 되려면 해시 가능해야 함 | `ForEach(items, id: \.self)` |
| `CaseIterable` | `T.allCases`로 모든 항목을 얻기 위해 | `T.allCases as! [T]` |
| `RawRepresentable` | `rawValue`로 표시할 문자열을 얻기 위해 | `Text(item.rawValue)` |
| `where RawValue == String` | 그 `rawValue`가 **문자열**이어야 `Text`에 넣을 수 있음 | `Text(item.rawValue)` |
| `var icon: String` | SF Symbol 이름 | `Image(systemName: item.icon)` |
| `var color: Color` | 선택 시 배경색 | `item.color.gradient` |

`enum AppTab: String, SegmentItem`은 이 모두를 **거의 공짜로** 만족한다.

- `: String` → `RawRepresentable`의 `RawValue == String`을 컴파일러가 합성
- `enum`이므로 `Hashable`도 자동 합성
- `CaseIterable`은 연관값 없는 enum이면 `allCases`를 자동 합성
- 남은 `icon`과 `color`만 직접 구현

[`enum` raw value 문서](./enum-raw-values.md), [`enum`의 `Hashable` 문서](./enum-hashable-conformance.md), [`CaseIterable`과 `Sequence` 문서](./caseiterable-and-sequence.md)를 함께 보면 좋다.

### 한 가지 짚고 갈 점 — `T.allCases as! [T]`

```swift
private let items: [T] = T.allCases as! [T]
```

`CaseIterable`의 `allCases` 타입은 `[T]`가 아니라 **`T.AllCases`라는 연관 타입**이다.

```swift
protocol CaseIterable {
    associatedtype AllCases: Collection where AllCases.Element == Self
    static var allCases: AllCases { get }
}
```

`enum`에 대해서는 컴파일러가 `AllCases = [Self]`로 합성하므로 실제 타입이 `Array<AppTab>`이 맞고, 지금은 강제 캐스팅이 성공한다. 하지만 **커스텀 타입이 `AllCases`를 직접 다르게 정의하면 런타임에 크래시**한다.

```swift
// 이렇게 쓰면 강제 캐스팅 없이 항상 안전하다
private var items: [T] { Array(T.allCases) }
```

`Array(_:)`는 어떤 `Collection`이든 받으므로 `AllCases`가 무엇이든 동작한다. [Swift의 형변환 문서](./swift-type-casting.md)와 이어진다.

또 하나. `T.allCases`는 `static` 프로퍼티라 `let items: [T] = ...`처럼 **저장 프로퍼티 기본값**으로 쓰는 것보다 계산 프로퍼티가 더 어울린다. 뷰는 자주 재생성되므로 매번 배열을 새로 만드는 비용이 생긴다.

### `where T.RawValue == String`은 중복이다

```swift
struct ReusableSegmentedControl<T: SegmentItem>: View
where T.RawValue == String {
```

`SegmentItem` 프로토콜 선언에 이미 `where RawValue == String`이 있으므로, `T: SegmentItem`이면 `T.RawValue == String`은 **자동으로 따라온다.** 지워도 컴파일된다.

남겨 두면 읽는 사람에게 제약이 명시적으로 보이는 장점이 있고, 지우면 중복이 사라진다. 둘 다 맞는 선택이다.

## 체크리스트

- [ ] `A & B`가 "임시 프로토콜"이라는 표현의 의미를 설명한다.
- [ ] `A & B`와 `B & A`가 같은 타입인지 확인한다.
- [ ] 클래스 두 개를 `&`로 묶어 컴파일 오류 메시지를 직접 본다.
- [ ] `struct`를 `&`에 넣어 보고 오류 메시지를 읽는다.
- [ ] `typealias Codable = Decodable & Encodable`을 표준 라이브러리에서 확인한다.
- [ ] `typealias`로 만든 합성에 요구사항을 추가하려 시도해 보고 안 되는 것을 확인한다.
- [ ] `protocol X: A & B`와 `protocol X: A, B`가 같은지 컴파일로 확인한다.
- [ ] `<T: A & B>`, `where T: A & B`, `where T: A, T: B` 세 표기를 서로 바꿔 본다.
- [ ] `where RawValue == String`을 지우고 `Text(item.rawValue)`에서 어떤 오류가 나는지 본다.
- [ ] `any A & B`와 `some A & B`를 각각 써 보고 차이를 설명한다.
- [ ] `extension Array: P where Element: P`로 조건부 적합성을 만들어 본다.
- [ ] `T.allCases as! [T]`를 `Array(T.allCases)`로 바꾸고 동작이 같은지 확인한다.
- [ ] `where T.RawValue == String`을 지워도 컴파일되는지 확인한다.

## 공식 참고 자료

- [The Swift Programming Language: Protocols — Protocol Composition](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/#Protocol-Composition)
- [The Swift Programming Language: Protocols — Protocol Inheritance](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/#Protocol-Inheritance)
- [The Swift Programming Language: Protocols — Class-Only Protocols](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/#Class-Only-Protocols)
- [The Swift Programming Language: Types — Protocol Composition Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Protocol-Composition-Type)
- [The Swift Programming Language: Generics — Generic Where Clauses](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Generic-Where-Clauses)
- [The Swift Programming Language: Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/)
- [Swift Standard Library: RawRepresentable](https://developer.apple.com/documentation/swift/rawrepresentable)
- [Swift Standard Library: CaseIterable](https://developer.apple.com/documentation/swift/caseiterable)
- [Swift Standard Library: Codable](https://developer.apple.com/documentation/swift/codable)
- [SE-0335: Introduce existential `any`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0335-existential-any.md)
- [SE-0346: Lightweight same-type requirements for primary associated types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md)
- [SE-0143: Conditional conformances](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0143-conditional-conformances.md)
