# Swift의 기본 타입과 비교 방법

## 질문이 나온 코드

`chapter-43/chapter-43/ContentView.swift`의 `Snowflake`는 위치, 크기, 속도를 `Double`로 저장한다.

```swift
struct Snowflake: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var scale: Double
    var speed: Double
}
```

## 공부할 내용

### Swift에는 Java 같은 별도의 원시 타입 계층이 없다

Swift에서 다른 언어가 기본 또는 primitive type이라고 부르는 숫자, 불리언, 문자열도 Swift 표준 라이브러리가 정의한 이름 있는 타입이며 구조체로 구현된다. 그래서 `Int`, `String` 같은 타입에도 프로퍼티와 메서드가 있고 extension을 추가할 수 있다.

Swift의 기초를 배울 때는 다음 세 묶음으로 보면 편하다.

- 자주 쓰는 단일 값 타입: `Int`, `UInt`, `Double`, `Float`, `Bool`, `String`, `Character`
- 값의 부재나 조합을 표현하는 타입: `Optional`, tuple
- 여러 값을 저장하는 컬렉션: `Array`, `Set`, `Dictionary`

이 목록이 모든 표준 라이브러리 타입이라는 뜻은 아니다. `UUID`, `Date`, `Data`처럼 특정 목적의 타입도 있으며, 필요에 따라 Foundation 같은 프레임워크가 제공한다.

### 자주 쓰는 단일 값 타입

| 타입 | 표현하는 값 | 주요 특성 | 비교 |
| --- | --- | --- | --- |
| `Int` | 부호 있는 정수 | 일반적인 정수 기본값, 현재 iOS의 64비트 환경에서는 64비트 크기 | `==`, `!=`, `<`, `<=`, `>`, `>=` |
| `UInt` | 0 이상의 정수 | 음수를 표현하지 못함. 특별한 이유가 없으면 개수에도 보통 `Int`가 편함 | `Int`와 같은 순서 비교 |
| `Int8`…`Int64` | 크기가 고정된 부호 정수 | 파일 형식·네트워크·C API처럼 비트 폭이 중요할 때 사용 | 같은 타입끼리 순서 비교 |
| `UInt8`…`UInt64` | 크기가 고정된 무부호 정수 | 바이트 데이터에는 `UInt8`이 자주 쓰임 | 같은 타입끼리 순서 비교 |
| `Double` | 64비트 부동소수점 | 소수 리터럴을 추론할 때의 기본 타입. 일반 계산에 우선 사용 | 순서 비교 가능하나 근삿값 주의 |
| `Float` | 32비트 부동소수점 | 정밀도보다 메모리·GPU API 호환이 중요한 경우 사용 | 순서 비교 가능하나 근삿값 주의 |
| `Bool` | `true` 또는 `false` | 조건식은 반드시 `Bool`이어야 하며 `0`을 거짓처럼 쓰지 못함 | `==`, `!=`; 크기 순서는 없음 |
| `String` | 문자열 | 확장 유니코드 문자소의 모음인 값 타입 | `==`, `!=` 및 사전식 순서 비교 |
| `Character` | 한 개의 확장 유니코드 문자소 | 사용자에게 보이는 문자 한 단위를 표현 | `==`, `!=` 및 순서 비교 |

정수 연산은 기본적으로 허용 범위를 넘으면 오류를 일으켜 조용히 값이 뒤집히는 것을 막는다. 의도적으로 overflow가 필요할 때만 `&+`, `&-`, `&*` 같은 연산자를 사용한다.

`Double`과 `Float`은 매우 넓은 범위를 표현하지만 모든 실수를 정확히 저장하지는 못한다. 예를 들어 `0.1 + 0.2`가 수학적으로 기대한 값과 비트 단위로 정확히 같지 않을 수 있다. 측정값처럼 오차가 있는 수는 허용 오차를 두고 비교한다.

```swift
let a = 0.1 + 0.2
let b = 0.3
let tolerance = 1e-12

let approximatelyEqual = abs(a - b) < tolerance
```

### 타입 추론과 명시적 변환

Swift는 초기값을 보고 타입을 추론한다.

```swift
let count = 10       // Int
let ratio = 0.5      // Double
let title = "Snow"  // String
let visible = true   // Bool
```

부동소수점 리터럴은 별도 문맥이 없으면 `Double`로 추론된다. `Float`가 필요하면 타입을 명시한다.

```swift
let gpuValue: Float = 0.5
```

Swift는 서로 다른 숫자 타입을 자동으로 섞지 않는다. 변환 의도를 직접 적어야 한다.

```swift
let count = 3
let distance = 12.5

let total = Double(count) + distance
let truncated = Int(distance) // 12: 소수 부분 제거
```

변환이 항상 성공하는 것은 아니다. 문자열을 숫자로 바꾸는 `Int("123")`의 결과가 `Int?`인 이유는 `"hello"`처럼 변환할 수 없는 입력이 있기 때문이다.

### `Equatable`과 `Comparable`로 이해하는 비교

비교 연산은 타입이 어떤 프로토콜을 채택했는지로 이해할 수 있다.

- `Equatable`: 두 값이 같은지 `==`, `!=`로 비교한다.
- `Comparable`: `Equatable`을 포함하며 `<`, `<=`, `>`, `>=`로 순서를 비교한다.
- 참조 타입의 `===`, `!==`: 값이 아니라 두 참조가 정확히 같은 클래스 인스턴스를 가리키는지 확인한다.

`Int`, `Double`, `String`은 `Comparable`이므로 순서 비교가 된다. `Bool`은 동등 비교만 가능하고 `false < true`처럼 쓰지 않는다.

```swift
3 < 10                 // true
"apple" < "banana"    // true
true == false          // false
```

대체로 비교하는 양쪽 타입은 같아야 한다. 다음 코드는 변환 없이 비교할 수 없다.

```swift
let integer = 3
let decimal = 3.0

Double(integer) == decimal // true
```

### `Optional`, tuple, collection

`Optional<Wrapped>` 또는 축약형 `Wrapped?`는 값이 있거나 `nil`인 상태를 표현한다. 참조 타입만이 아니라 어떤 타입이든 optional이 될 수 있다.

```swift
var nickname: String? = nil
nickname = "Snow"
```

tuple은 서로 다른 값들을 잠시 묶는 복합 타입이다. 의미와 동작이 계속 커진다면 이름 있는 `struct`로 옮기는 편이 좋다.

```swift
let point = (x: 10.0, y: 20.0)
```

세 가지 기본 컬렉션의 차이는 다음과 같다.

| 타입 | 용도 | 핵심 특성 |
| --- | --- | --- |
| `Array<Element>` / `[Element]` | 순서 있는 값 목록 | 같은 값 중복 가능, 정수 index 사용 |
| `Set<Element>` | 고유한 값의 집합 | 순서가 핵심이 아니며 원소가 `Hashable`이어야 함 |
| `Dictionary<Key, Value>` / `[Key: Value]` | key와 value의 대응 | key가 고유하고 `Hashable`이어야 함 |

이 타입들도 값 타입이다. 대입하거나 함수에 전달하면 논리적으로 복사되며, 표준 라이브러리는 실제 복사 비용을 줄이기 위해 변경 시 복사 최적화를 사용한다.

### `Snowflake`에서 왜 `Double`인가

`x`, `y`, `scale`, `speed`는 정수 단계가 아니라 연속적으로 변할 수 있다. Swift가 소수 리터럴의 기본 타입으로 `Double`을 선택하고 SwiftUI의 여러 기하 값도 `CGFloat` 또는 부동소수점 값을 사용하므로 학습 예제에서 `Double`은 자연스러운 선택이다.

다만 특정 API가 `CGFloat`나 `Float`를 요구하면 경계에서 명시적으로 변환한다. 저장 타입을 습관적으로 모두 바꾸기보다 데이터의 의미와 연결할 API를 기준으로 선택한다.

## 학습 체크리스트

- [ ] 정수, 소수, 문자열, 불리언 리터럴의 추론 타입을 `type(of:)`로 확인한다.
- [ ] `Float`와 `Double`의 `MemoryLayout.size` 및 정밀도를 비교한다.
- [ ] `Int8.max + 1`과 `Int8.max &+ 1`의 차이를 별도 실험 코드에서 확인한다.
- [ ] `0.1 + 0.2 == 0.3`과 허용 오차 비교의 결과를 확인한다.
- [ ] `Int`와 `Double`을 변환 없이 연산·비교할 때 발생하는 컴파일 오류를 읽는다.
- [ ] `Int("123")`과 `Int("snow")`의 결과가 왜 `Int?`인지 설명한다.
- [ ] `Equatable`, `Comparable`, 클래스 identity 비교의 차이를 설명한다.
- [ ] 같은 데이터를 `Array`, `Set`, `Dictionary`에 넣고 순서·중복·접근 방법을 비교한다.

## 공식 참고 자료

- [The Swift Programming Language: The Basics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/)
- [The Swift Programming Language: Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/)
- [The Swift Programming Language: Basic Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/basicoperators/)
- [The Swift Programming Language: Strings and Characters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/)
- [The Swift Programming Language: Collection Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/)
- [The Swift Programming Language: Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
- [Swift Standard Library: Equatable](https://developer.apple.com/documentation/swift/equatable)
- [Swift Standard Library: Comparable](https://developer.apple.com/documentation/swift/comparable)
