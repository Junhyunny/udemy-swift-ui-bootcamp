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

### Swift에는 Java 같은 별도의 원시 타입 계층이 없다 (정리 완료)

Swift에서 다른 언어가 기본 또는 primitive type이라고 부르는 숫자, 불리언, 문자열도 Swift 표준 라이브러리가 정의한 이름 있는 타입이며 구조체로 구현된다. 그래서 `Int`, `String` 같은 타입에도 프로퍼티와 메서드가 있고 extension을 추가할 수 있다.

Swift의 기초를 배울 때는 다음 세 묶음으로 보면 편하다.

- 자주 쓰는 단일 값 타입: `Int`, `UInt`, `Double`, `Float`, `Bool`, `String`, `Character`
- 값의 부재나 조합을 표현하는 타입: `Optional`, tuple
- 여러 값을 저장하는 컬렉션: `Array`, `Set`, `Dictionary`

이 목록이 모든 표준 라이브러리 타입이라는 뜻은 아니다. `UUID`, `Date`, `Data`처럼 특정 목적의 타입도 있으며, 필요에 따라 Foundation 같은 프레임워크가 제공한다.

> 참고 근거: [Swift 언어 가이드 — Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/), [Swift 언어 가이드 — The Basics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/)

### 자주 쓰는 단일 값 타입 (정리 완료)


| 타입               | 표현하는 값            | 주요 특성                                      | 비교                               |
| ---------------- | ----------------- | ------------------------------------------ | -------------------------------- |
| `Int`            | 부호 있는 정수          | 일반적인 정수 기본값, 현재 iOS의 64비트 환경에서는 64비트 크기    | `==`, `!=`, `<`, `<=`, `>`, `>=` |
| `UInt`           | 0 이상의 정수          | 음수를 표현하지 못함. 특별한 이유가 없으면 개수에도 보통 `Int`가 편함 | `Int`와 같은 순서 비교                  |
| `Int8`…`Int64`   | 크기가 고정된 부호 정수     | 파일 형식·네트워크·C API처럼 비트 폭이 중요할 때 사용          | 같은 타입끼리 순서 비교                    |
| `UInt8`…`UInt64` | 크기가 고정된 무부호 정수    | 바이트 데이터에는 `UInt8`이 자주 쓰임                   | 같은 타입끼리 순서 비교                    |
| `Double`         | 64비트 부동소수점        | 소수 리터럴을 추론할 때의 기본 타입. 일반 계산에 우선 사용         | 순서 비교 가능하나 근삿값 주의                |
| `Float`          | 32비트 부동소수점        | 정밀도보다 메모리·GPU API 호환이 중요한 경우 사용            | 순서 비교 가능하나 근삿값 주의                |
| `Bool`           | `true` 또는 `false` | 조건식은 반드시 `Bool`이어야 하며 `0`을 거짓처럼 쓰지 못함      | `==`, `!=`; 크기 순서는 없음            |
| `String`         | 문자열               | 확장 유니코드 문자소의 모음인 값 타입                      | `==`, `!=` 및 사전식 순서 비교           |
| `Character`      | 한 개의 확장 유니코드 문자소  | 사용자에게 보이는 문자 한 단위를 표현                      | `==`, `!=` 및 순서 비교               |


> 참고 근거: [Swift 언어 가이드 — The Basics의 기본 타입과 정수 범위](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/), [Swift 표준 라이브러리 — String](https://developer.apple.com/documentation/swift/string), [Swift 표준 라이브러리 — Character](https://developer.apple.com/documentation/swift/character)

### 정수 범위와 overflow (정리 완료)

`Int8`, `UInt8`, `Int`, `UInt` 같은 고정 폭 정수는 사용할 수 있는 bit 수가 정해져 있어 표현 범위에도 한계가 있다.

```swift
Int8.min  // -128
Int8.max  //  127
UInt8.min //    0
UInt8.max //  255
```

- 최댓값보다 큰 결과가 생기는 것을 **overflow**라고 한다.
- 최솟값보다 작은 결과가 생기는 것을 흔히 **underflow**라고 한다.
- 두 경우 모두 결과를 해당 정수 타입의 bit 수로 표현할 수 없다는 같은 종류의 범위 초과다.

> 참고 근거: [Swift 언어 가이드 — Integer Bounds](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Integer-Bounds), [Swift 표준 라이브러리 — FixedWidthInteger](https://developer.apple.com/documentation/swift/fixedwidthinteger)

#### 일반 산술 연산은 범위 초과를 허용하지 않는다 (정리 완료)

Swift의 일반 정수 연산자인 `+`, `-`, `*`, `/`, `%`는 결과가 타입의 범위를 벗어나는지 검사한다. 컴파일러가 상수식의 범위 초과를 미리 알 수 있으면 컴파일 오류가 발생하고, 실행 중 계산에서 발생하면 프로그램이 trap되어 실행을 멈춘다.

```swift
// let impossible: UInt8 = 256
// 컴파일 오류: UInt8이 표현할 수 없는 정수 리터럴

var runtimeValue = UInt8.max // 255
runtimeValue += 1            // 런타임 오류: arithmetic overflow
```

여기서 trap은 `throw`로 전달되는 Swift `Error`가 아니므로 `do-catch`로 복구할 수 없다. 계산 전에 범위를 검사하거나 아래의 overflow 보고 API를 사용해야 한다.

양수 방향만 문제가 되는 것도 아니다.

```swift
var unsigned = UInt8.min // 0
unsigned -= 1            // 0보다 작아질 수 없으므로 trap

var signed = Int8.min    // -128
signed -= 1              // -129를 표현할 수 없으므로 trap
```

곱셈도 같은 규칙을 적용한다. 나눗셈에서는 0으로 나누는 경우뿐 아니라 `Int.min / -1`도 주의해야 한다. 예를 들어 `Int8.min`은 `-128`이지만 결과 `128`은 `Int8`에 들어가지 않으므로 범위 초과다. `-Int.min` 역시 같은 이유로 표현할 수 없다.

이 검사는 C 계열 언어에서 범위 초과 결과가 예측하기 어렵거나 조용히 다른 값으로 바뀌는 문제를 막는다. 단, `Double`과 `Float`은 정수와 다르게 매우 큰 계산 결과를 `infinity`로 표현할 수 있으므로 이 절의 규칙을 그대로 적용하지 않는다.

> 참고 근거: [Swift 언어 가이드 — Basic Operators의 산술 연산](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/basicoperators/#Arithmetic-Operators), [Swift 언어 가이드 — Overflow Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/#Overflow-Operators), [Swift 표준 라이브러리 — FloatingPoint의 Infinity](https://developer.apple.com/documentation/swift/floatingpoint)

#### `&+`, `&-`, `&*`는 남는 bit만 보존한다 (정리 완료)

알고리즘이 의도적으로 고정된 bit 폭의 순환을 요구한다면 `&+`, `&-`, `&*`를 사용할 수 있다. `&`는 bitwise AND가 아니라 이 문맥에서 **overflow 허용 연산자**의 일부다.

```swift
let wrappedUp = UInt8.max &+ 1 // 255 &+ 1 == 0
let wrappedDown = UInt8.min &- 1 // 0 &- 1 == 255
let signedUp = Int8.max &+ 1   // 127 &+ 1 == -128
let signedDown = Int8.min &- 1 // -128 &- 1 == 127
let wrappedProduct: UInt8 = 20 &* 20 // 400에서 하위 8bit만 남아 144
```

고정 폭이 `n` bit라면 wrapping 연산은 개념적으로 `2ⁿ`을 법으로 하는 modular arithmetic처럼 동작한다. 범위를 넘어간 상위 bit를 버리므로 최댓값 다음은 최솟값으로, 최솟값 이전은 최댓값으로 이어진다.


| 타입과 연산           | 수학적 결과 | 실제 결과 | 남는 bit의 의미                            |
| ---------------- | ------: | -----: | ------------------------------------- |
| `UInt8.max &+ 1` | 256    | 0     | `1_00000000`에서 하위 8bit `00000000`만 보존 |
| `UInt8.min &- 1` | -1     | 255   | 하위 8bit가 `11111111`                   |
| `Int8.max &+ 1`  | 128    | -128  | `10000000`을 2의 보수 signed 값으로 해석       |
| `Int8.min &- 1`  | -129   | 127   | `01111111`이 남음                        |


대입과 결합한 `&+=`, `&-=`, `&*=`도 있다. 반면 `&/` 연산자는 없다. 나눗셈의 범위 초과 여부까지 복구 가능하게 처리해야 한다면 `dividedReportingOverflow(by:)`를 사용한다.

wrapping은 오류를 해결하는 연산자가 아니라 **범위 초과 후의 bit 결과가 요구사항일 때 선택하는 연산자**다. 일반적인 금액, 재고, 사용자 입력, 페이지 번호 등에 습관적으로 사용하면 실제 버그를 숨기게 된다. 해시·암호·체크섬·저수준 binary protocol·순환 counter처럼 modular arithmetic이 설계에 포함된 경우에 주로 적합하다.

> 참고 근거: [Swift 언어 가이드 — Value Overflow](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/#Value-Overflow), [Swift 표준 라이브러리 — overflow addition operator `&+`](https://developer.apple.com/documentation/swift/uint/%26%2B%28_%3A_%3A%29)

#### 크래시 없이 overflow를 감지하려면 reporting API를 사용한다 (정리 완료)

`FixedWidthInteger`는 계산 결과와 범위 초과 여부를 tuple로 돌려주는 메서드를 제공한다.

```swift
let addition = UInt8.max.addingReportingOverflow(1)
addition.partialValue // 0
addition.overflow     // true

let multiplication = UInt8(20).multipliedReportingOverflow(by: 20)
multiplication.partialValue // 144
multiplication.overflow     // true
```

사용할 수 있는 주요 메서드는 다음과 같다.

- `addingReportingOverflow(_:)`
- `subtractingReportingOverflow(_:)`
- `multipliedReportingOverflow(by:)`
- `dividedReportingOverflow(by:)`
- `remainderReportingOverflow(dividingBy:)`

`overflow`가 `false`이면 `partialValue`가 완전한 계산 결과다. `true`이면 `partialValue`에는 wrapping된 일부 결과가 들어 있으므로, 그대로 사용할지 오류로 바꿀지 호출자가 결정해야 한다.

나눗셈·나머지 reporting 메서드는 **실행 중 전달된 값**이 0일 때 trap하지 않고 `overflow == true`를 반환한다. 이때 연산 결과가 정의되지 않으므로 `partialValue`는 피연산자 값이며, 유효한 몫이나 나머지로 사용하면 안 된다. 다만 `dividedReportingOverflow(by: 0)`처럼 0 리터럴을 직접 쓰면 컴파일러가 명백한 0 나눗셈을 컴파일 오류로 먼저 진단할 수 있다.

```swift
enum CounterError: Error {
    case overflow
}

func addingSafely(_ lhs: UInt8, _ rhs: UInt8) throws -> UInt8 {
    let result = lhs.addingReportingOverflow(rhs)
    guard !result.overflow else {
        throw CounterError.overflow
    }
    return result.partialValue
}
```

범위 초과를 다루는 선택 기준은 다음처럼 정리할 수 있다.


| 의도                          | 선택                                                 |
| --------------------------- | -------------------------------------------------- |
| 범위 초과는 프로그래밍 오류이며 즉시 발견해야 함 | 일반 `+`, `-`, `*` 사용                                |
| 범위 초과를 호출자에게 오류로 전달해야 함     | `reportingOverflow` 결과를 확인해 `throw` 또는 별도 상태 반환    |
| 최대·최소 범위에 고정해야 함            | 변환에는 `init(clamping:)`; 계산에는 사전 범위 검사 등 명시적 정책 적용  |
| bit가 순환하는 결과 자체가 알고리즘의 일부임  | 의도를 주석과 테스트로 남기고 `&+`, `&-`, `&*` 사용               |
| 더 큰 정확한 값을 계속 표현해야 함        | `Int64` 등 더 넓은 타입 또는 별도의 arbitrary-precision 구현 검토 |


> 참고 근거: [Swift 표준 라이브러리 — FixedWidthInteger](https://developer.apple.com/documentation/swift/fixedwidthinteger), [`multipliedReportingOverflow(by:)`](https://developer.apple.com/documentation/swift/fixedwidthinteger/multipliedreportingoverflow%28by%3A%29), [`dividedReportingOverflow(by:)`](https://developer.apple.com/documentation/swift/fixedwidthinteger/dividedreportingoverflow%28by%3A%29)

### 부동소수점의 오차와 범위 초과 (정리 완료)

`Double`과 `Float`은 매우 넓은 범위를 표현하지만 모든 실수를 정확히 저장하지는 못한다. 예를 들어 `0.1 + 0.2`가 수학적으로 기대한 값과 비트 단위로 정확히 같지 않을 수 있다. 측정값처럼 오차가 있는 수는 허용 오차를 두고 비교한다.

```swift
let a = 0.1 + 0.2
let b = 0.3
let tolerance = 1e-12

let approximatelyEqual = abs(a - b) < tolerance
```

> 참고 근거: [Swift 표준 라이브러리 — FloatingPoint](https://developer.apple.com/documentation/swift/floatingpoint), [Swift 표준 라이브러리 — Double](https://developer.apple.com/documentation/swift/double)

### `String`과 `Character`의 관계 (정리 완료)

`String`은 Unicode 문자열을 나타내는 값 타입이고, 컬렉션으로 순회할 때의 원소 타입인 `String.Element`는 `Character`다. 즉 문자열을 `for-in`으로 순회하면 byte나 UTF-16 code unit이 아니라 사람이 하나의 글자로 인식하는 단위에 가까운 `Character`를 얻는다.

```swift
let greeting = "Hi 👋"

for character in greeting {
    // character의 타입은 Character
    print(character)
}
```

문자열 리터럴은 문맥이 없으면 `String`으로 추론된다. 하나의 문자만 적었더라도 `Character`가 필요하면 타입 문맥을 줘야 한다.

```swift
let inferred = "A"          // String
let explicit: Character = "A"

let stringFromCharacter = String(explicit) // "A"
var word = "Swift"
word.append(explicit)                    // "SwiftA"
```

> 참고 근거: [Swift 표준 라이브러리 — String](https://developer.apple.com/documentation/swift/string), [Swift 표준 라이브러리 — Character](https://developer.apple.com/documentation/swift/character), [Swift 언어 가이드 — Working with Characters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Working-with-Characters)

#### `Character`는 하나의 byte나 Unicode scalar가 아니다 (정리 완료)

Swift의 `Character` 하나는 **확장 grapheme cluster(extended grapheme cluster)** 하나다. 이는 Unicode 경계 규칙에 따라 사용자에게 한 글자로 보이는 하나 이상의 Unicode scalar 묶음이다.

```swift
let precomposed: Character = "\u{E9}"        // é: scalar 1개
let decomposed: Character = "\u{65}\u{301}" // e + ◌́: scalar 2개

precomposed == decomposed // true
```

국기, 피부색 modifier가 결합된 emoji, 가족 emoji도 여러 scalar나 code unit으로 구성되지만 `Character` 하나일 수 있다.

```swift
let koreanFlag: Character = "🇰🇷"       // regional indicator scalar 2개
let family: Character = "👨‍👩‍👧‍👦"        // 여러 emoji와 ZWJ의 결합
```

따라서 다음 단위들은 서로 같다고 가정하면 안 된다.

- `Character`: 사용자가 인식하는 글자에 가까운 확장 grapheme cluster
- Unicode scalar: `U+0065`, `U+0301`처럼 Unicode가 부여한 21bit 값
- UTF-8 code unit: 문자열을 UTF-8로 인코딩한 `UInt8` 단위
- UTF-16 code unit: 문자열을 UTF-16으로 인코딩한 `UInt16` 단위

`String`은 각 표현을 별도의 collection view로 제공한다.

```swift
let text = "A🇰🇷e\u{301}"

text.count                // 3개의 Character: A, 🇰🇷, é
text.unicodeScalars.count // 5개의 Unicode scalar
text.utf8.count           // 12개의 UTF-8 code unit
text.utf16.count          // 7개의 UTF-16 code unit
```

어떤 길이가 필요한지는 작업의 경계에 따라 정한다. UI에 표시되는 글자 단위라면 `Character`, 네트워크 payload 크기라면 UTF-8 byte, `NSRange`나 일부 Objective-C API와 연결한다면 UTF-16 code unit이 중요할 수 있다.

> 참고 근거: [Swift 언어 가이드 — Extended Grapheme Clusters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Extended-Grapheme-Clusters), [Swift 언어 가이드 — Unicode Representations of Strings](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#Unicode-Representations-of-Strings), [Swift 표준 라이브러리 — Character](https://developer.apple.com/documentation/swift/character)

#### String은 정수 index로 접근하지 않는다 (정리 완료)

각 `Character`가 차지하는 scalar와 byte 수가 다르므로 `string[0]`처럼 정수로 즉시 접근할 수 없다. Swift는 grapheme cluster 경계를 가리키는 `String.Index`를 사용한다.

```swift
let language = "Swift 🐦"

let firstIndex = language.startIndex
let firstCharacter = language[firstIndex] // "S"

let secondIndex = language.index(after: firstIndex)
let secondCharacter = language[secondIndex] // "w"

let offset = language.index(language.startIndex, offsetBy: 6)
language[offset] // "🐦"
```

`endIndex`는 마지막 문자의 위치가 아니라 마지막 문자 **다음 위치**이므로 subscript에 직접 넣을 수 없다. 마지막 문자는 `last`를 사용하거나 `index(before: endIndex)`로 찾는다.

```swift
language.last // Optional("🐦")
let lastIndex = language.index(before: language.endIndex)
language[lastIndex] // "🐦"
```

`count`와 멀리 떨어진 `index(_:offsetBy:)`는 grapheme cluster 경계를 따라가야 하므로 일반적으로 문자열 길이에 비례하는 작업이다. 배열처럼 임의 위치 접근이 항상 O(1)이라고 가정하면 안 된다. 반복문에서 매번 처음부터 index offset을 계산하기보다 `for-in`, `indices`, `zip(string.indices, string)` 등을 사용한다.

한 문자열에서 얻은 index를 관계없는 다른 문자열에 사용하면 안 된다. 문자열을 변경하면 저장해 둔 index도 무효가 될 수 있다.

```swift
for index in language.indices {
    print(language[index])
}
```

> 참고 근거: [Swift 언어 가이드 — String Indices](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/#String-Indices), [Swift 표준 라이브러리 — String.Index](https://developer.apple.com/documentation/swift/string/index), [Swift 표준 라이브러리 — Collection의 index 유효성](https://developer.apple.com/documentation/swift/collection)

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

#### 일부 문자열을 자르면 `Substring`이 된다

String subscript로 범위를 잘라 얻는 값은 보통 `String`이 아니라 `Substring`이다. `Substring`도 `StringProtocol`을 통해 문자열과 비슷하게 사용할 수 있지만 원본 문자열의 저장 공간을 공유할 수 있다.

여기서 “저장 공간을 공유한다”는 것은 `Substring`이 자신의 문자 buffer 전체를 새로 복사하는 대신, 개념적으로 다음 두 정보만 가지고 원본 buffer의 일부를 바라볼 수 있다는 뜻이다.

```text
원본 String의 buffer
┌────────────────────────────────────┐
│ Marie Curie                        │
└────────────────────────────────────┘
  ▲         ▲
  │         └─ Substring의 끝 경계
  └─ Substring의 시작 경계

Substring "Marie"
= 원본 buffer에 대한 참조 + 시작/끝 범위
```

그래서 slice를 만드는 작업은 문자 데이터를 즉시 복사하지 않고 빠르게 수행될 수 있다. 원본 `String` 변수가 scope에서 사라져도 살아 있는 `Substring`이 같은 buffer를 참조하고 있다면 그 buffer 전체를 해제할 수 없다.

공유는 두 값이 함께 변경된다는 뜻은 아니다. `String`과 `Substring`은 값 의미를 유지하며, 어느 한쪽을 변경해야 할 때는 copy-on-write에 따라 필요한 저장 공간을 분리한다.

```swift
let fullName = "Marie Curie"
let space = fullName.firstIndex(of: " ") ?? fullName.endIndex
let firstNameSlice = fullName[..<space] // Substring
let firstName = String(firstNameSlice)  // 독립적인 String
```

짧게 계산하고 버릴 때는 `Substring` 그대로 사용하고, 프로퍼티에 오래 저장하거나 API가 `String`을 요구하면 `String(substring)`으로 변환한다. 아주 작은 substring 하나 때문에 큰 원본 문자열의 저장 공간이 오래 유지되는 것도 피할 수 있다.

#### 공개 API로 확인할 수 있는 특성: index를 공유한다

원본 collection과 slice가 같은 index를 사용한다는 것은 Swift가 공개적으로 보장하는 동작이다.

```swift
let original = "HEADER:Hello, Swift!:FOOTER"
let start = original.index(original.startIndex, offsetBy: 7)
let end = original.index(start, offsetBy: 5)
let slice = original[start..<end] // "Hello", Substring

slice.startIndex == start   // true
slice.endIndex == end       // true
original[slice.startIndex]  // "H"
```

`slice.startIndex`가 새 문자열의 0번째 위치로 초기화되지 않고 원본의 `start`와 같다. 이는 slice가 원본 범위의 view라는 사실을 API 수준에서 확인하는 가장 안정적인 예다. 다만 **index 공유는 storage 주소 공유와 같은 개념은 아니다.** index 동작은 공개 계약이지만 실제 buffer 배치는 구현 세부 사항이다.

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

### 타입 추론과 명시적 변환 (정리 완료)

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

Swift는 서로 다른 숫자 타입을 자동으로 섞지 않는다. 변환 의도를 직접 적어야 한다. 이때 `Double(count)`처럼 새 값을 만드는 것은 \*\*값 변환(conversion)\*\*이다. 클래스 계층이나 프로토콜 타입에서 사용하는 `as`, `as?`, `as!`는 런타임 타입 관계를 확인하는 \*\*타입 캐스팅(casting)\*\*이므로 구분해야 한다. 타입 캐스팅은 [Swift의 형변환](./021-swift-type-casting.md)에서 별도로 다룬다.

```swift
let count = 3
let distance = 12.5

let total = Double(count) + distance
let truncated = Int(distance) // 12: 0 방향으로 반올림
```

숫자 변환은 손실 가능성을 의식해서 이니셜라이저를 고른다.

```swift
let towardZero = Int(-12.9)            // -12
let exact = Int(exactly: 12.0)         // Optional(12)
let notExact = Int(exactly: 12.9)      // nil
let clamped = UInt8(clamping: 300)     // 255
let lowByte = UInt8(truncatingIfNeeded: 300) // 44
```

- `Int(someDouble)`은 소수 부분을 버리는 것이 아니라 정확히는 **0 방향으로 반올림**한다. 유한하고 결과 타입이 표현할 수 있는 범위여야 한다.
- `init?(exactly:)`는 값의 범위나 정밀도를 잃지 않을 때만 값을 반환한다. 손실을 허용하면 안 되는 데이터에 적합하다.
- 정수의 `init(clamping:)`은 범위를 벗어난 값을 `min...max` 안으로 제한한다.
- 정수의 `init(truncatingIfNeeded:)`는 필요한 하위 비트만 남긴다. 일반적인 숫자 변환보다 비트 패턴을 다루는 코드에 가깝다.

문자열을 숫자로 바꾸는 `Int("123")`의 결과가 `Int?`인 이유는 `"hello"`처럼 변환할 수 없는 입력이 있기 때문이다. 반대로 숫자를 문자열로 표현할 때는 `String(123)` 또는 문자열 보간 `"\(123)"`을 쓸 수 있다.

Optional을 `if let`, `guard let`, `??`로 처리하는 것은 값 변환이나 타입 캐스팅이 아니라, 값이 있는지를 확인한 뒤 `Wrapped`를 꺼내는 **언래핑**이다.

> 참고 근거: [Swift 언어 가이드 — Type Safety and Type Inference](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Type-Safety-and-Type-Inference), [Swift 표준 라이브러리 — Int 변환 이니셜라이저](https://developer.apple.com/documentation/swift/int), [Swift 언어 가이드 — Type Casting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/typecasting/), [Swift 언어 가이드 — Optionals](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals)

### `Equatable`은 무엇을 같다고 볼지 정한다 (정리 완료)

“`Equatable`을 상속한다”라고 말하기 쉽지만, 정확히는 `struct`, `enum`, `class`가 `Equatable` 프로토콜을 \*\*채택(conform)\*\*한다. `Comparable`처럼 프로토콜이 다른 프로토콜을 이어받아 요구사항을 추가할 때는 프로토콜 상속이라고 한다.

`Equatable`의 핵심 요구사항은 다음 `==` 연산자 하나다.

```swift
static func == (lhs: Self, rhs: Self) -> Bool
```

`!=`는 표준 라이브러리가 `==`의 반대로 제공하므로 따로 구현할 필요가 없다. 무엇을 같다고 볼지는 타입 작성자가 정한다. 모든 저장 프로퍼티가 `Equatable`인 `struct`와 모든 associated value가 `Equatable`인 `enum`은 대개 컴파일러가 `==`를 합성한다.

```swift
struct Coordinate: Equatable {
    let x: Int
    let y: Int
}

Coordinate(x: 1, y: 2) == Coordinate(x: 1, y: 2) // true
```

합성된 구현은 저장된 값 전체를 비교한다. 일부 프로퍼티만 객체의 논리적 동일성을 결정한다면 직접 구현한다.

```swift
struct User: Equatable {
    let id: UUID
    var displayName: String
    var lastLoginAt: Date

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
```

이 구현에서는 표시 이름이나 로그인 시간이 달라도 `id`가 같으면 같은 사용자다. 정답이 하나 있는 것이 아니라 **도메인에서 동일한 값의 기준이 무엇인지**가 기준이다. 단, 다음 동등 관계 법칙은 지켜야 컬렉션과 알고리즘이 예측 가능하게 동작한다.

- 반사성: `a == a`는 참이다.
- 대칭성: `a == b`이면 `b == a`다.
- 추이성: `a == b`이고 `b == c`이면 `a == c`다.

`class`는 저장 프로퍼티를 이용한 `Equatable` 구현을 자동 합성하지 않으므로 일반적으로 `==`를 직접 구현한다. 이때 `==`는 개발자가 정한 **값 동등성**, `===`는 두 변수가 메모리의 **같은 인스턴스**를 가리키는지를 비교한다.

```swift
final class Account: Equatable {
    let id: Int

    init(id: Int) { self.id = id }

    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }
}

let first = Account(id: 1)
let second = Account(id: 1)

first == second   // true: id 값이 같다
first === second  // false: 서로 다른 인스턴스다
```

`Hashable`을 함께 채택한다면 `a == b`인 두 값은 반드시 같은 hash를 만들어야 한다. 따라서 `==`는 `id`만 보는데 `hash(into:)`는 `displayName`까지 포함하는 식으로 서로 다른 기준을 사용하면 안 된다. 자세한 내용은 [`Hashable`과 해시 충돌](./026-hashable-id-and-collisions.md), [`hash(into:)`](./027-hash-into-and-java-comparison.md)에서 이어서 학습한다.

> 참고 근거: [Swift 표준 라이브러리 — Equatable](https://developer.apple.com/documentation/swift/equatable), [Swift — Adopting Common Protocols](https://developer.apple.com/documentation/swift/adopting-common-protocols), [Swift 표준 라이브러리 — Hashable](https://developer.apple.com/documentation/swift/hashable)

### `Comparable`은 일관된 전체 순서를 정한다 (정리 완료)

`Comparable`은 `Equatable`을 상속하며 값의 앞뒤를 결정한다. 직접 채택할 때 추가로 구현할 핵심 요구사항은 `<`다. `==`는 `Equatable` 규칙대로 직접 구현하거나 조건을 만족하면 합성할 수 있고, `!=`, `>`, `<=`, `>=`는 표준 라이브러리가 제공한다.

```swift
struct Version: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.major, lhs.minor, lhs.patch)
            < (rhs.major, rhs.minor, rhs.patch)
    }
}

Version(major: 1, minor: 9, patch: 0)
    < Version(major: 2, minor: 0, patch: 0) // true
```

위 타입은 모든 저장 프로퍼티가 `Equatable`이므로 `==`가 합성된다. `<`는 major → minor → patch 순서로 처음 달라지는 값을 비교한다. 비교 기준은 정렬 결과와 범위 연산의 의미가 되므로 다음 조건을 만족해야 한다.

- 임의의 두 값 `a`, `b`에는 `a == b`, `a < b`, `b < a` 중 정확히 하나만 참이어야 한다.
- `a < a`는 항상 거짓이어야 한다.
- `a < b`이면 `b < a`는 거짓이어야 한다.
- `a < b`이고 `b < c`이면 `a < c`여야 한다.

예를 들어 `<`는 이름을 비교하고 `==`는 id만 비교하면 두 관계가 모순될 수 있다. `Comparable`에서는 동등성도 정렬 기준과 같은 의미 체계를 사용해야 한다.

`Int`, `String`처럼 이미 `Comparable`인 원소의 배열은 `sorted()`와 `min()`, `max()`를 조건 클로저 없이 사용할 수 있다.

```swift
let scores = [30, 10, 20]
scores.sorted() // [10, 20, 30], 원본은 유지

var mutableScores = scores
mutableScores.sort() // 자기 자신을 변경
```

`Double.nan`은 특수하다. 자기 자신과도 `==`가 거짓이고 `<`, `>` 역시 거짓이므로 일반 값처럼 동등성과 정렬을 추론하면 안 된다. 부동소수점 입력에 `NaN`이 들어올 수 있다면 별도로 걸러 내거나 정책을 정해야 한다.

> 참고 근거: [Swift 표준 라이브러리 — Comparable의 요구사항과 기본 구현](https://developer.apple.com/documentation/swift/comparable), [Swift 표준 라이브러리 — FloatingPoint의 NaN](https://developer.apple.com/documentation/swift/floatingpoint)

### 표준 타입과 tuple의 비교 기준 (정리 완료)

- 숫자는 수치 값을 기준으로 비교한다. 단, `Int`와 `Double`처럼 타입이 다르면 먼저 명시적으로 변환해야 한다.
- `String`과 `Character`는 Swift의 유니코드 문자열 규칙으로 비교한다. 사용자에게 보여 줄 언어별 정렬은 단순 `<` 대신 locale을 고려하는 Foundation API가 필요할 수 있다.
- tuple의 `==`는 같은 위치의 원소를 모두 비교한다. 순서 비교는 왼쪽부터 처음 다른 원소가 결과를 결정하는 사전식 비교다.
- tuple 원소 이름은 비교 기준이 아니다. 비교 연산을 각 위치의 타입에 적용할 수 있어야 한다.

현재 Swift 공식 언어 가이드가 설명하는 기본 tuple 비교 연산자는 2개에서 6개 원소까지 제공된다. 더 큰 자료 구조나 자체 동작이 필요하면 tuple보다 이름 있는 `struct`가 적합하다.

```swift
(1, "zebra") < (2, "apple") // true: 첫 번째 원소에서 결정
(3, "apple") < (3, "bird")  // true: 두 번째 원소를 비교
(4, "dog") == (4, "dog")    // true
```

`Bool`은 `Equatable`이지만 `Comparable`은 아니므로 `false < true`처럼 쓸 수 없다.

```swift
let integer = 3
let decimal = 3.0

Double(integer) == decimal // true
```

> 참고 근거: [Swift 언어 가이드 — Comparison Operators와 tuple 비교](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/basicoperators/#Comparison-Operators), [Swift 표준 라이브러리 — Comparable](https://developer.apple.com/documentation/swift/comparable)

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

### `Snowflake`에서 왜 `Double`인가

`x`, `y`, `scale`, `speed`는 정수 단계가 아니라 연속적으로 변할 수 있다. Swift가 소수 리터럴의 기본 타입으로 `Double`을 선택하고 SwiftUI의 여러 기하 값도 `CGFloat` 또는 부동소수점 값을 사용하므로 학습 예제에서 `Double`은 자연스러운 선택이다.

다만 특정 API가 `CGFloat`나 `Float`를 요구하면 경계에서 명시적으로 변환한다. 저장 타입을 습관적으로 모두 바꾸기보다 데이터의 의미와 연결할 API를 기준으로 선택한다.

> 참고 근거: [Swift 언어 가이드 — Type Safety and Type Inference](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Type-Safety-and-Type-Inference), [Core Foundation — CGFloat](https://developer.apple.com/documentation/corefoundation/cgfloat-swift.struct)

## 학습 체크리스트

- [ ] 정수, 소수, 문자열, 불리언 리터럴의 추론 타입을 `type(of:)`로 확인한다.
- [ ] `Float`와 `Double`의 `MemoryLayout.size` 및 정밀도를 비교한다.
- [ ] `Int8.max + 1`과 `Int8.max &+ 1`의 차이를 별도 실험 코드에서 확인한다.
- [ ] `UInt8.min &- 1`, `Int8.max &+ 1`, `UInt8(20) &* 20`의 값과 bit pattern을 설명한다.
- [ ] `addingReportingOverflow(_:)`로 trap 없이 범위 초과를 감지하고 `throw`로 변환한다.
- [ ] 일반 산술, wrapping 산술, reporting API를 각각 선택해야 하는 사례를 하나씩 설명한다.
- [ ] `0.1 + 0.2 == 0.3`과 허용 오차 비교의 결과를 확인한다.
- [ ] `"A🇰🇷e\u{301}"`의 `count`, `unicodeScalars.count`, `utf8.count`, `utf16.count`를 비교한다.
- [ ] 조합형과 분해형 `é`가 `==`이지만 UTF-8 code unit은 다른 이유를 설명한다.
- [ ] 정수 index 대신 `String.Index`로 첫 번째, 마지막, 특정 offset의 `Character`에 접근한다.
- [ ] `Substring`을 장기 보관할 때 `String`으로 변환하는 이유를 설명한다.
- [ ] 같은 emoji에 대한 `String.count`와 `NSString.length` 결과가 다른 이유를 설명한다.
- [ ] `Int`와 `Double`을 변환 없이 연산·비교할 때 발생하는 컴파일 오류를 읽는다.
- [ ] `Int("123")`, `Int("snow")`, `Int(exactly: 12.9)`, `UInt8(clamping: 300)`의 결과가 다른 이유를 설명한다.
- [ ] 저장 프로퍼티 전체를 비교하는 합성 `Equatable`과 id만 비교하는 직접 구현을 각각 작성한다.
- [ ] `Comparable`에 `<`를 구현하고 `>`, `<=`, `>=`, `sorted()`가 함께 동작하는지 확인한다.
- [ ] `Equatable`, `Comparable`, 클래스의 `===` identity 비교가 각각 묻는 질문을 설명한다.
- [ ] Array, Set, Dictionary가 같은 원소를 서로 다른 순서로 가질 때 `==` 결과를 비교한다.
- [ ] `ArraySlice`의 `startIndex`를 확인하고 `Array(slice)` 변환 전후를 비교한다.
- [ ] Dictionary의 일반 subscript, `default:` subscript, `updateValue`의 반환 타입을 비교한다.
- [ ] `[String]` ↔ `NSArray` bridge와 `[String?]` → `NSArray` bridge 실패를 확인한다.
- [ ] `Array`/`NSArray`, `Set`/`NSSet`, `Dictionary`/`NSDictionary`의 값·참조 의미 차이를 설명한다.

## 공식 참고 자료 색인

- [The Swift Programming Language: The Basics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/)
- [The Swift Programming Language: Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/)
- [The Swift Programming Language: Basic Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/basicoperators/)
- [The Swift Programming Language: Advanced Operators — Overflow Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/advancedoperators/#Overflow-Operators)
- [The Swift Programming Language: Strings and Characters](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/stringsandcharacters/)
- [The Swift Programming Language: Collection Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/collectiontypes/)
- [The Swift Programming Language: Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
- [Swift Standard Library: Equatable](https://developer.apple.com/documentation/swift/equatable)
- [Swift Standard Library: Comparable](https://developer.apple.com/documentation/swift/comparable)
- [Swift Standard Library: String](https://developer.apple.com/documentation/swift/string)
- [Swift Standard Library: Character](https://developer.apple.com/documentation/swift/character)
- [Swift Standard Library: String.Index](https://developer.apple.com/documentation/swift/string/index)
- [Swift Standard Library: StringProtocol](https://developer.apple.com/documentation/swift/stringprotocol)
- [Swift Standard Library: Array](https://developer.apple.com/documentation/swift/array)
- [Swift Standard Library: Set](https://developer.apple.com/documentation/swift/set)
- [Swift Standard Library: Dictionary](https://developer.apple.com/documentation/swift/dictionary)
- [Swift Standard Library: Int](https://developer.apple.com/documentation/swift/int)
- [Swift Standard Library: FixedWidthInteger](https://developer.apple.com/documentation/swift/fixedwidthinteger)
- [Swift Standard Library: overflow addition operator `&+`](https://developer.apple.com/documentation/swift/uint/%26%2B%28_%3A_%3A%29)
- [Swift Standard Library: `multipliedReportingOverflow(by:)`](https://developer.apple.com/documentation/swift/fixedwidthinteger/multipliedreportingoverflow%28by%3A%29)
- [Swift Standard Library: `dividedReportingOverflow(by:)`](https://developer.apple.com/documentation/swift/fixedwidthinteger/dividedreportingoverflow%28by%3A%29)
- [Adopting Common Protocols](https://developer.apple.com/documentation/swift/adopting-common-protocols)
- [Working with Foundation Types](https://developer.apple.com/documentation/swift/working-with-foundation-types)
- [Foundation: NSArray](https://developer.apple.com/documentation/foundation/nsarray)
- [Foundation: NSSet](https://developer.apple.com/documentation/foundation/nsset)
- [Foundation: NSDictionary](https://developer.apple.com/documentation/foundation/nsdictionary)

