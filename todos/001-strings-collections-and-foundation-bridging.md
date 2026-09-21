# Swift 문자열 심화와 컬렉션 — Unicode 비교, `Substring` 저장 공간, Foundation bridge

이 문서에서 다루던 **기본 타입, 정수 overflow, 부동소수점 오차, `String`/`Character` 기초, `String.Index`, `Substring`의 저장 공간 공유, 타입 추론, `Equatable`·`Comparable`** 은 블로그 글로 정리를 마쳤다. 여기에는 **아직 정리하지 않은 주제만** 남긴다.

- 블로그: 스위프트 원시 타입(Swift Primitive Types)
- 숫자 타입 중 `CG` 접두사 타입군은 [CoreGraphics 타입과 `CGFloat`](./061-coregraphics-types-and-cgfloat.md)에 있다.
- 컬렉션 초기화 표기는 [컬렉션 초기화](./006-array-literal-and-initialization.md)에 있다.

## 공부할 내용

### `String`과 `Character` 심화

#### `String`과 `Character` 사이를 안전하게 변환한다

`String(character)`는 언제나 가능하지만, 임의의 `String`은 여러 `Character`를 포함할 수 있으므로 하나의 `Character`로 바꾸기 전에 조건을 확인한다.

```swift
func onlyCharacter(in text: String) -> Character? {
    guard text.count == 1 else { return nil }
    return text.first
}

onlyCharacter(in: "한")    // Optional("한")
onlyCharacter(in: "🇰🇷")   // Optional("🇰🇷")
onlyCharacter(in: "Swift") // nil
```

`Character(text)`는 문자열이 정확히 하나의 확장 grapheme cluster라는 전제에 맞지 않으면 런타임 오류가 날 수 있으므로, 외부 입력에는 위처럼 검증 가능한 API가 안전하다. 빈 문자열의 `first`도 `nil`이다.

> 참고 근거: [Swift 표준 라이브러리 — Character 생성](https://developer.apple.com/documentation/swift/character), [Swift 표준 라이브러리 — String의 `first`](https://developer.apple.com/documentation/swift/string)

#### 동등 비교는 Unicode 정규 표현의 차이를 흡수한다

`String`과 `Character`의 `==`는 단순히 저장 byte가 같은지 비교하지 않고 Unicode canonical equivalence를 따른다. 그래서 미리 조합된 `é`와 `e` + combining acute accent는 UTF-8 표현이 달라도 같은 문자열로 비교된다.

```swift
let lhs = "Caf\u{E9}"
let rhs = "Cafe\u{301}"

lhs == rhs // true
lhs.utf8.elementsEqual(rhs.utf8) // false: 실제 UTF-8 code unit은 다름
```

`String`과 `Character`는 `Equatable`, `Comparable`, `Hashable`을 지원한다. 따라서 문자열을 Dictionary key로 쓰거나 문자를 Set에 저장할 수 있다. 기본 문자열 비교는 locale에 영향받지 않는 안정적인 Unicode 비교다. 사람에게 보여 줄 이름이나 파일명처럼 언어·지역별 정렬이 필요하면 `String.StandardComparator.localized` 또는 Foundation의 locale-aware 비교 API를 검토한다.

> 참고 근거: [Swift 표준 라이브러리 — String의 canonical-equivalent 비교](https://developer.apple.com/documentation/swift/string), [Swift 언어 가이드 — String and Character Equality](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#String-and-Character-Equality), [Swift 표준 라이브러리 — String.StandardComparator](https://developer.apple.com/documentation/swift/string/standardcomparator)

#### `NSString.length`와 `String.count`는 기준이 다르다

`String`은 Foundation의 `NSString`과 bridge할 수 있지만 길이의 단위가 다르다. `String.count`는 `Character` 수이고 `NSString.length`는 UTF-16 code unit 수다.

```swift
let emoji = "👨‍👩‍👧‍👦"

emoji.count                  // 1 Character
(emoji as NSString).length   // 11 UTF-16 code unit
```

따라서 `NSRange`의 `location`과 `length`를 그대로 `String.Index`처럼 사용하면 안 된다. Foundation API의 UTF-16 범위와 Swift 문자열 범위 사이를 변환하는 전용 이니셜라이저를 사용한다.

```swift
let nsRange = NSRange(emoji.startIndex..<emoji.endIndex, in: emoji)
let swiftRange = Range(nsRange, in: emoji) // Range<String.Index>?
```

> 참고 근거: [Swift 언어 가이드 — Counting Characters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Counting-Characters), [Foundation — NSString](https://developer.apple.com/documentation/foundation/nsstring), [Foundation — NSRange와 String range 변환](https://developer.apple.com/documentation/foundation/nsrange)

### `Substring`의 저장 공간을 직접 관찰한다

`Substring`이 원본 buffer를 공유한다는 것과 index를 공유한다는 것은 블로그 글에서 공개 API로 확인했다. 여기서는 **그 아래 계층을 실제로 관찰하는 실험**만 남긴다.

#### 실험용 코드로 buffer 주소를 관찰한다

연속 UTF-8 저장 공간이 제공되는 경우에 한해 다음 실험으로 원본과 slice의 buffer 위치를 관찰할 수 있다. 짧은 문자열은 small-string 최적화의 영향을 받을 수 있으므로 충분히 큰 문자열을 사용한다.

```swift
let original = "HEADER:" + String(repeating: "A", count: 10_000) + ":TAIL"
let slice = original.dropFirst(7).prefix(20)

original.utf8.withContiguousStorageIfAvailable { originalBuffer in
    slice.utf8.withContiguousStorageIfAvailable { sliceBuffer in
        guard
            let originalAddress = originalBuffer.baseAddress,
            let sliceAddress = sliceBuffer.baseAddress
        else { return }

        let byteOffset = originalAddress.distance(to: sliceAddress)

        print(originalAddress)
        print(sliceAddress)
        print(byteOffset) // 일반적으로 7
    }
}
```

이 예제에서 slice의 첫 byte 주소가 원본 첫 byte 주소보다 7만큼 뒤라면 같은 연속 buffer의 일부를 보고 있음을 관찰한 것이다.

하지만 이 pointer 비교를 애플리케이션 로직이나 테스트 성공 조건으로 사용하면 안 된다.

- `withContiguousStorageIfAvailable`은 연속 저장 공간이 없으면 closure를 실행하지 않을 수 있다.
- pointer는 해당 closure가 실행되는 동안에만 유효하므로 밖에 저장하면 안 된다.
- small-string, `NSString` bridge, 최적화 수준과 Swift 구현 변경에 따라 저장 방식이 달라질 수 있다.
- Swift가 보장하는 것은 `Substring`의 동작과 값 의미이지 특정 메모리 주소가 아니다.

#### 큰 원본이 유지되는 현상을 Instruments로 비교한다

메모리 유지 효과는 큰 원본에서 아주 작은 suffix만 장기 보관하면 더 쉽게 관찰할 수 있다.

```swift
var retainedSlice: Substring?
var retainedString: String?

func keepAsSubstring() {
    let huge = String(repeating: "A", count: 50_000_000) + "END"
    retainedSlice = huge.suffix(3)
    // 함수가 끝나도 retainedSlice 때문에 huge의 큰 buffer를 재사용할 수 있다.
}

func keepAsIndependentString() {
    let huge = String(repeating: "A", count: 50_000_000) + "END"
    retainedString = String(huge.suffix(3))
    // "END"를 위한 독립 저장 공간을 만들므로 huge의 buffer는 해제 가능해진다.
}
```

Xcode Instruments의 Allocations에서 두 함수를 각각 실행한 뒤 살아 있는 allocation을 비교한다. `keepAsSubstring()`에서는 3글자만 보관해도 큰 원본 buffer가 남을 수 있고, `keepAsIndependentString()`에서는 작은 `String`만 장기 보관된다. 메모리 allocator가 해제된 공간을 프로세스에 잠시 보관할 수 있으므로 Activity Monitor의 전체 메모리 숫자보다 Instruments의 live allocation을 보는 편이 정확하다.

> 참고 근거: [Swift 언어 가이드 — Substrings](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Substrings), [Swift 표준 라이브러리 — String의 Substring 설명](https://developer.apple.com/documentation/swift/string), [Swift 표준 라이브러리 — String.SubSequence](https://developer.apple.com/documentation/swift/string/subsequence), [Swift 표준 라이브러리 — StringProtocol](https://developer.apple.com/documentation/swift/stringprotocol)

### `Optional`과 tuple

`Optional<Wrapped>` 또는 축약형 `Wrapped?`는 값이 있거나 `nil`인 상태를 표현한다. 참조 타입만이 아니라 어떤 타입이든 optional이 될 수 있다.

```swift
var nickname: String? = nil
nickname = "Snow"
```

`Optional`은 감싼 타입이 `Equatable`일 때 조건부로 `Equatable`이 된다. `nil == nil`은 참이고, 두 값이 모두 존재하면 감싼 값의 `==`를 사용한다.

tuple은 서로 다른 타입의 값을 고정된 개수만큼 잠시 묶는 복합 타입이다. 각 위치의 타입은 tuple 타입의 일부지만 원소 이름은 타입을 구별하는 핵심 기준이 아니다.

```swift
let point = (x: 10.0, y: 20.0)
let (x, y) = point
```

tuple은 `Array` 같은 컬렉션이 아니다. 원소를 반복문으로 순회하거나 `append`, `map`할 수 없고, 원소 수를 런타임에 바꿀 수도 없다. 의미와 동작이 계속 커지거나 프로토콜 채택이 필요하면 이름 있는 `struct`로 옮기는 편이 좋다.

> 참고 근거: [Swift 언어 가이드 — Tuples](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Tuples), [Swift 언어 레퍼런스 — Tuple Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Tuple-Type), [Swift.org — Conditional Conformance in the Standard Library](https://www.swift.org/blog/conditional-conformance/)

### 기본 컬렉션 선택 기준

Swift의 기본 컬렉션은 generic 값 타입이며 한 컬렉션 안에는 선언된 타입의 값만 담는다.


| 타입                                        | 선택하는 경우           | 순서와 중복            | 타입 제약               |
| ----------------------------------------- | ----------------- | ----------------- | ------------------- |
| `Array<Element>` / `[Element]`            | 위치와 나열 순서가 중요할 때  | 순서 보장, 중복 허용      | 특별한 원소 제약 없음        |
| `Set<Element>`                            | 포함 여부와 고유성이 중요할 때 | 순서 미보장, 중복 제거     | `Element: Hashable` |
| `Dictionary<Key, Value>` / `[Key: Value]` | 고유한 key로 값을 찾을 때  | 순서 미보장, key 중복 불가 | `Key: Hashable`     |


이 타입들도 값 타입이다. 대입하거나 함수에 전달하면 논리적으로 복사되며, 표준 라이브러리는 실제 복사 비용을 줄이기 위해 변경 시 복사 최적화를 사용한다.

> 참고 근거: [Swift 언어 가이드 — Collection Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/), [Swift 언어 가이드 — Structures and Classes의 값 타입](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)

#### Array

`Array`는 0부터 시작하는 연속된 정수 index로 접근하는 순서 있는 컬렉션이다. 유효하지 않은 index로 subscript하면 런타임 오류가 발생하므로, 값이 없을 수 있는 경우 `first`, `last`, `firstIndex(of:)` 같은 Optional 반환 API를 활용한다.

```swift
var names = ["Amy", "Ben", "Amy"]
names.append("Chris")
names.insert("Dana", at: 1)

let first = names.first                  // String?
let amyIndex = names.firstIndex(of: "Amy") // Int?
let longNames = names.filter { $0.count >= 4 }
let lengths = names.map(\.count)
```

- `append`, `insert`, `remove`는 원본을 변경하므로 배열이 `var`여야 한다.
- `map`은 각 원소를 변환하고, `compactMap`은 변환 결과의 `nil`을 제거하며, `filter`는 조건을 만족하는 원소만 남긴다.
- `sorted()`는 정렬된 새 배열을 반환하고 `sort()`는 원본을 변경한다.
- `ArraySlice`는 원본 배열의 일부를 표현하며 index가 반드시 0부터 다시 시작하지 않는다. 새 독립 배열과 0 기반 index가 필요하면 `Array(slice)`로 변환한다.
- 많은 원소를 추가할 개수를 미리 안다면 `reserveCapacity(_:)`로 반복적인 저장 공간 재할당을 줄일 수 있다.

두 배열은 `Element: Equatable`일 때 **개수, 순서, 각 위치의 값**이 모두 같아야 `==`다.

```swift
[1, 2, 3] == [1, 2, 3] // true
[1, 2, 3] == [3, 2, 1] // false
```

`Array` 자체를 `<`로 비교하는 대신, 사전식 순서가 필요하면 `lexicographicallyPrecedes(_:)`를 사용할 수 있다.

> 참고 근거: [Swift 표준 라이브러리 — Array](https://developer.apple.com/documentation/swift/array), [Swift 표준 라이브러리 — `lexicographicallyPrecedes(_:)`](https://developer.apple.com/documentation/swift/array/lexicographicallyprecedes%28_%3A%29)

#### Set

`Set`은 `Hashable` 원소를 한 번씩만 저장한다. 배열 리터럴 문법을 사용하지만 타입 문맥에 `Set`을 밝혀야 하며, 반복 순서에 의존하면 안 된다.

```swift
var tags: Set<String> = ["swift", "ios", "swift"]
// 중복된 "swift"는 하나만 저장된다.

tags.contains("ios")
let result = tags.insert("swift")
result.inserted       // false
result.memberAfterInsert // 기존 "swift"
```

`insert(_:)`는 `(inserted: Bool, memberAfterInsert: Element)` tuple을 돌려주므로 실제 삽입 여부와 최종 원소를 함께 확인할 수 있다. `union`, `intersection`, `subtracting`, `symmetricDifference`로 합집합·교집합·차집합·대칭차집합을 계산하고, `isSubset`, `isSuperset`, `isDisjoint`로 집합 관계를 확인한다.

두 Set의 `==`는 반복 순서가 아니라 **같은 원소를 포함하는지**를 비교한다.

```swift
Set([1, 2, 3]) == Set([3, 2, 1]) // true
```

원소의 `==`와 hash 기준은 일치해야 한다. 또한 Set에 들어 있는 동안 동등성이나 hash에 사용되는 값을 바꾸면 원소를 다시 찾지 못할 수 있으므로, 제거한 뒤 변경하고 다시 삽입하거나 안정적인 식별자를 사용한다.

> 참고 근거: [Swift 표준 라이브러리 — Set](https://developer.apple.com/documentation/swift/set), [Swift 표준 라이브러리 — Hashable](https://developer.apple.com/documentation/swift/hashable)

#### Dictionary

`Dictionary`는 고유한 `Hashable` key와 value의 쌍을 저장한다. key가 없을 수 있으므로 일반 subscript 조회 결과는 Optional이다.

```swift
var scores = ["Amy": 90, "Ben": 80]

let amy = scores["Amy"]                 // Int?
let nobody = scores["Nobody", default: 0] // Int
scores["Chris", default: 0] += 10

let oldValue = scores.updateValue(95, forKey: "Amy") // 이전 값 Int?
scores["Ben"] = nil                     // key-value 쌍 삭제
```

- `dictionary[key] = nil`은 Optional 값을 저장하는 것이 아니라 해당 key를 제거한다. Value 자체가 Optional이면 중첩 Optional의 의미를 주의해야 한다.
- `updateValue(_:forKey:)`는 교체되기 전 값을 반환하므로 기존 값 존재 여부를 함께 처리할 수 있다.
- `default:` subscript는 key가 없을 때 기본값을 제공하며, `+=`나 `append` 같은 변경도 자연스럽게 작성할 수 있다.
- `merge(_:uniquingKeysWith:)`는 중복 key가 생길 때 어느 값을 선택할지 클로저로 정한다.
- `keys`와 `values`는 view다. 배열이 필요한 API에는 `Array(dictionary.keys)`처럼 명시적으로 변환한다.
- Dictionary 반복은 `(key, value)` tuple을 돌려주지만 순서를 보장하지 않는다. 출력 순서가 중요하면 key를 정렬한 뒤 접근한다.

두 Dictionary는 `Value: Equatable`일 때 **같은 key가 같은 value와 연결되어 있는지**를 비교한다. 삽입 순서나 반복 순서는 동등성에 영향을 주지 않는다.

```swift
["a": 1, "b": 2] == ["b": 2, "a": 1] // true
```

> 참고 근거: [Swift 표준 라이브러리 — Dictionary](https://developer.apple.com/documentation/swift/dictionary), [Swift 언어 가이드 — Dictionaries](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/#Dictionaries)

### 컬렉션 API와 프로토콜 제약 읽기

같은 메서드라도 원소 타입의 프로토콜 채택 여부에 따라 사용할 수 있는지가 달라진다.

- `array.contains(value)`, `firstIndex(of:)`, 배열의 `==`는 원소의 `Equatable` 동작을 이용한다.
- `array.sorted()`, `min()`, `max()`는 원소가 `Comparable`이면 비교 클로저 없이 쓸 수 있다.
- `Set<Element>`의 `Element`와 `Dictionary<Key, Value>`의 `Key`는 검색을 위해 `Hashable`이어야 한다.
- 비교 기준이 기본 동작과 다르면 `contains(where:)`, `firstIndex(where:)`, `sorted(by:)`, `elementsEqual(_:by:)`처럼 조건 클로저를 받는 API를 사용한다.

```swift
struct Person {
    let name: String
    let age: Int
}

let people = [Person(name: "Amy", age: 30), Person(name: "Ben", age: 20)]
let byAge = people.sorted { $0.age < $1.age }
let hasAmy = people.contains { $0.name == "Amy" }
```

> 참고 근거: [Swift 표준 라이브러리 — Collection](https://developer.apple.com/documentation/swift/collection), [Swift 표준 라이브러리 — Sequence](https://developer.apple.com/documentation/swift/sequence), [Swift 언어 가이드 — Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)

### Swift 컬렉션과 Foundation 컬렉션의 연결

`Array`, `Set`, `Dictionary`는 Swift 표준 라이브러리의 generic **구조체**다. `NSArray`, `NSSet`, `NSDictionary`는 Foundation에 남아 있는 Objective-C 계열의 **클래스**다. 역할은 비슷하고 서로 bridge할 수 있지만 같은 타입은 아니다.


| Swift 표준 라이브러리           | Foundation 참조 타입                       | 핵심 차이                                                                               |
| ------------------------ | -------------------------------------- | ----------------------------------------------------------------------------------- |
| `Array<Element>`         | `NSArray` / `NSMutableArray`           | Swift는 원소 타입이 명시된 값 타입, Foundation은 객체를 담는 참조 타입                                    |
| `Set<Element>`           | `NSSet` / `NSMutableSet`               | Swift는 `Element: Hashable`, Foundation은 객체의 `hash`와 `isEqual(_:)` 사용                |
| `Dictionary<Key, Value>` | `NSDictionary` / `NSMutableDictionary` | Swift는 `Key: Hashable`인 generic 값 타입, Foundation은 Objective-C 객체 기반 key-value 참조 타입 |


Swift 컬렉션은 `let`과 `var`로 가변성을 결정한다. 반면 Foundation은 불변 클래스와 mutable subclass가 분리되어 있다.

```swift
let fixedSwift = ["A", "B"]       // Array<String>, 변경 불가
var mutableSwift = ["A", "B"]     // Array<String>, 변경 가능

let fixedFoundation: NSArray = ["A", "B"]
let mutableFoundation: NSMutableArray = ["A", "B"]
mutableFoundation.add("C")
```

`Array<String>`에는 `String`만 넣을 수 있어 컴파일 시점에 타입이 보장된다. `NSArray`의 원소는 Objective-C 객체 관점에서는 이질적인 타입을 함께 담을 수 있고, Swift에서 꺼낸 값은 구체 타입으로 변환해야 할 수 있다.

```swift
let legacy: NSArray = ["A", 1, NSDate()]

for value in legacy {
    if let text = value as? String {
        print(text)
    }
}
```

> 참고 근거: [Swift — Working with Foundation Types](https://developer.apple.com/documentation/swift/working-with-foundation-types), [Foundation — NSArray](https://developer.apple.com/documentation/foundation/nsarray), [Foundation — NSSet](https://developer.apple.com/documentation/foundation/nsset), [Foundation — NSDictionary](https://developer.apple.com/documentation/foundation/nsdictionary)

#### bridge는 언제 일어나는가

Foundation을 import하면 Swift overlay가 많은 Objective-C API의 `NSArray`, `NSSet`, `NSDictionary`를 각각 `[Element]`, `Set<Element>`, `[Key: Value]`처럼 자연스러운 Swift 타입으로 가져온다. 그래서 순수 Swift 코드에서는 대개 `NS` 타입을 직접 사용할 필요가 없다.

기존 Objective-C API가 실제 `NSArray`를 요구하거나 참조 의미가 필요한 경계에서는 `as`로 bridge할 수 있다.

```swift
let swiftColors = ["red", "green"]
let foundationColors = swiftColors as NSArray

let legacyNames: NSArray = ["Amy", "Ben"]
let swiftNames = legacyNames as? [String] // [String]?
```

bridge가 가능한지는 원소 타입에 달려 있다.

- 클래스 인스턴스와 `@objc` 프로토콜 값은 Objective-C 객체로 직접 다룰 수 있다.
- `String` ↔ `NSString`, 숫자 타입 ↔ `NSNumber`, `Array` ↔ `NSArray`처럼 Foundation 대응 타입이 있는 값은 bridge할 수 있다.
- 임의의 Swift struct나 `Optional<String>` 배열처럼 Objective-C 표현이 없는 값은 그대로 `NSArray`로 bridge할 수 없다.
- `Dictionary`는 key와 value가, `Set`은 원소가 각각 Objective-C로 표현 가능해야 Foundation 컬렉션으로 bridge할 수 있다.

```swift
let colors: [String] = ["red", "green"]
let bridged = colors as NSArray // 가능: String이 NSString으로 bridge됨

let optionalColors: [String?] = ["red", nil]
// let invalid = optionalColors as NSArray // 컴파일 오류
```

bridge가 항상 단순한 타입 이름 변경인 것은 아니다. `Array`에서 `NSArray`로 갈 때 원소가 이미 클래스 또는 `@objc` 프로토콜 값이면 저장 공간을 공유하며 O(1)에 처리될 수 있지만, `Int`처럼 Foundation 객체로 바꿔야 하는 값은 각 원소를 `NSNumber` 등으로 변환하므로 O(n) 시간과 추가 공간이 들 수 있다. 반대 방향도 목적지 원소가 값 타입이면 원소별 변환이 필요할 수 있다.

Swift 컬렉션은 bridge 뒤에도 값 의미를 유지한다. `Array`를 변경하면 copy-on-write에 따라 자신의 값이 바뀌며, 이를 Foundation 참조 타입처럼 “같은 객체가 함께 변경된다”고 가정하면 안 된다. 공유 변경 자체가 요구되는 오래된 API가 아니라면 Swift 컬렉션을 기본 선택으로 삼는 편이 안전하다.

> 참고 근거: [Swift 표준 라이브러리 — Array의 NSArray bridging과 비용](https://developer.apple.com/documentation/swift/array), [Swift — Working with Foundation Types](https://developer.apple.com/documentation/swift/working-with-foundation-types)

#### 이름이 비슷한 세 가지 연결을 구분한다

- **Swift–Objective-C bridging**: `Array`와 `NSArray`, `String`과 `NSString`처럼 Swift 값과 Objective-C 객체 표현 사이를 연결한다.
- **Objective-C mutable subclass**: `NSArray`와 `NSMutableArray`처럼 참조 타입 계층 안에서 읽기 전용 인터페이스와 변경 가능한 인터페이스를 나눈다.
- **toll-free bridging**: `NSArray`와 Core Foundation의 `CFArray`처럼 Objective-C와 C 기반 Core Foundation 타입을 연결한다. Swift `Array`와 `NSArray`의 bridge와는 구분되는 개념이다.

`NSArray` 같은 타입을 직접 선택할 만한 경우는 Objective-C API가 그 타입을 명시적으로 요구할 때, Foundation에만 있는 동작이 필요할 때, 또는 의도적으로 참조 의미를 공유해야 할 때다. 일반적인 앱 모델과 SwiftUI 상태에는 타입 안전성과 값 의미를 제공하는 `Array`, `Set`, `Dictionary`를 우선한다.

> 참고 근거: [Swift — Prefer Swift Value Types to Bridged Objective-C Reference Types](https://developer.apple.com/documentation/swift/working-with-foundation-types), [Foundation — Classes Bridged to Swift Standard Library Value Types](https://developer.apple.com/documentation/foundation/classes-bridged-to-swift-standard-library-value-types)

## 학습 체크리스트

- [ ] `onlyCharacter(in:)`처럼 검증하는 변환과 `Character(text)` 직접 변환의 차이를 설명한다.
- [ ] 조합형과 분해형 `é`가 `==`이지만 UTF-8 code unit은 다른 이유를 설명한다.
- [ ] locale에 따라 정렬이 달라져야 하는 상황과 기본 Unicode 비교로 충분한 상황을 하나씩 든다.
- [ ] 같은 emoji에 대한 `String.count`와 `NSString.length` 결과가 다른 이유를 설명한다.
- [ ] `NSRange`와 `Range<String.Index>`를 전용 이니셜라이저로 상호 변환한다.
- [ ] `withContiguousStorageIfAvailable`로 원본과 slice의 byte offset을 관찰하고, 이 값을 로직에 쓰면 안 되는 이유를 설명한다.
- [ ] 큰 문자열의 suffix를 `Substring`으로 보관할 때와 `String`으로 변환해 보관할 때의 live allocation을 Instruments로 비교한다.
- [ ] `Optional`이 조건부로 `Equatable`이 된다는 말의 의미를 설명한다.
- [ ] tuple을 `struct`로 옮겨야 하는 신호 세 가지를 든다.
- [ ] Array, Set, Dictionary가 같은 원소를 서로 다른 순서로 가질 때 `==` 결과를 비교한다.
- [ ] `ArraySlice`의 `startIndex`를 확인하고 `Array(slice)` 변환 전후를 비교한다.
- [ ] Dictionary의 일반 subscript, `default:` subscript, `updateValue`의 반환 타입을 비교한다.
- [ ] 원소 타입이 `Equatable`/`Comparable`/`Hashable`인지에 따라 쓸 수 있는 컬렉션 API가 어떻게 달라지는지 정리한다.
- [ ] `[String]` ↔ `NSArray` bridge와 `[String?]` → `NSArray` bridge 실패를 확인한다.
- [ ] `Int` 배열을 `NSArray`로 bridge할 때 O(n) 비용이 드는 이유를 설명한다.
- [ ] `Array`/`NSArray`, `Set`/`NSSet`, `Dictionary`/`NSDictionary`의 값·참조 의미 차이를 설명한다.
- [ ] Swift–Objective-C bridging, mutable subclass, toll-free bridging 셋을 구분해 설명한다.

## 공식 참고 자료 색인

- [The Swift Programming Language: Strings and Characters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/)
- [The Swift Programming Language: Strings and Characters — Substrings](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Substrings)
- [The Swift Programming Language: Collection Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/)
- [The Swift Programming Language: Tuples](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Tuples)
- [The Swift Programming Language: Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [Swift Standard Library: String](https://developer.apple.com/documentation/swift/string)
- [Swift Standard Library: Character](https://developer.apple.com/documentation/swift/character)
- [Swift Standard Library: StringProtocol](https://developer.apple.com/documentation/swift/stringprotocol)
- [Swift Standard Library: String.StandardComparator](https://developer.apple.com/documentation/swift/string/standardcomparator)
- [Swift Standard Library: Collection](https://developer.apple.com/documentation/swift/collection)
- [Swift Standard Library: Sequence](https://developer.apple.com/documentation/swift/sequence)
- [Swift Standard Library: Array](https://developer.apple.com/documentation/swift/array)
- [Swift Standard Library: Set](https://developer.apple.com/documentation/swift/set)
- [Swift Standard Library: Dictionary](https://developer.apple.com/documentation/swift/dictionary)
- [Swift: Working with Foundation Types](https://developer.apple.com/documentation/swift/working-with-foundation-types)
- [Swift.org: Conditional Conformance in the Standard Library](https://www.swift.org/blog/conditional-conformance/)
- [Foundation: NSString](https://developer.apple.com/documentation/foundation/nsstring)
- [Foundation: NSRange](https://developer.apple.com/documentation/foundation/nsrange)
- [Foundation: NSArray](https://developer.apple.com/documentation/foundation/nsarray)
- [Foundation: NSSet](https://developer.apple.com/documentation/foundation/nsset)
- [Foundation: NSDictionary](https://developer.apple.com/documentation/foundation/nsdictionary)
- [Foundation: Classes Bridged to Swift Standard Library Value Types](https://developer.apple.com/documentation/foundation/classes-bridged-to-swift-standard-library-value-types)
