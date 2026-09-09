# Swift의 함수 오버로딩 — argument label이 시그니처의 일부다

## 질문이 나온 코드

`chapter-80/chapter-80/Models/Country.swift`

```swift
// TODO, 아래 함수들은 오버로딩 규칙을 생각해보면 문제가 될 것 같은데
//       컴파일 에러가 발생하지 않네? 왜 정상적으로 동작할 수 있어? Swift에선?
static func getCountryBy(name: String) -> Country? { ... }
static func getCountryBy(code: String) -> Country? { ... }
static func getCountryBy(currencyCode: String) -> Country? { ... }
```

## 공부할 내용

### 왜 문제가 될 것 같았나

**Java나 C++ 관점에서는 실제로 에러다.** 그 언어들에서 함수 시그니처는 이렇게 결정된다.

```text
함수 이름 + 파라미터 타입 목록
```

세 함수 모두 `getCountryBy(String)`이므로 **완전히 같은 시그니처**가 된다.

```java
// Java — 컴파일 에러
static Country getCountryBy(String name) { ... }
static Country getCountryBy(String code) { ... }   // error: already defined
```

파라미터 **이름**은 시그니처에 포함되지 않으므로 구분 수단이 되지 못한다.

### Swift는 다르다 — argument label이 포함된다

**Swift의 함수 이름에는 argument label이 들어간다.** 그래서 위 세 함수는 서로 다른 함수다.

```text
getCountryBy(name:)
getCountryBy(code:)
getCountryBy(currencyCode:)
```

Swift 공식 문서가 이 점을 명시한다.

> Each function parameter has both an *argument label* and a *parameter name*. The argument label is used when calling the function; each argument is written in the function call with its argument label before it.

**호출할 때 라벨이 필수**이므로 애초에 모호할 수가 없다.

```swift
Country.getCountryBy(name: "South Korea")           // 어느 함수인지 명확
Country.getCountryBy(code: "KR")
Country.getCountryBy(currencyCode: "KRW")
```

이 성질은 문서 곳곳에서 이미 봤다. [`at:` 문법과 IndexSet](./argument-labels-and-indexset.md), [클로저의 trailing closure 규칙](./closures-and-view-builders.md)에서 다룬 argument label이 여기서도 작동한다.

### Swift에서 오버로딩을 구분하는 요소

Swift가 같은 이름의 함수를 구별하는 기준은 넷이다.

| 기준 | 예 |
| --- | --- |
| **argument label** | `getCountryBy(name:)` vs `getCountryBy(code:)` |
| 파라미터 타입 | `find(_ x: Int)` vs `find(_ x: String)` |
| 파라미터 개수 | `log(_ a: Int)` vs `log(_ a: Int, _ b: Int)` |
| **반환 타입** | `parse() -> Int` vs `parse() -> String` |

**반환 타입만 다른 오버로딩도 가능하다.** Java에서는 불가능한 것이다.

```swift
func parse(_ s: String) -> Int? { Int(s) }
func parse(_ s: String) -> Double? { Double(s) }

let n: Int? = parse("42")       // 첫 번째
let d: Double? = parse("42")    // 두 번째 — 타입 어노테이션으로 결정
```

문맥에서 반환 타입을 추론할 수 있어야 한다. 표준 라이브러리도 이 기법을 쓴다.

### 진짜 에러가 나는 경우

**라벨까지 같으면 에러다.**

```swift
static func getCountryBy(name: String) -> Country? { ... }
static func getCountryBy(name: String) -> Country? { ... }
// error: invalid redeclaration of 'getCountryBy(name:)'
```

**`_`로 라벨을 생략하면 Java와 같은 상황이 된다.**

```swift
static func getCountryBy(_ value: String) -> Country? { ... }
static func getCountryBy(_ value: String) -> Country? { ... }
// error — 둘 다 getCountryBy(_:)이다
```

즉 **라벨이 구분자 역할을 한다.** 라벨을 없애면 타입으로만 구분해야 하고, 그러면 Java와 같은 제약을 받는다.

### 호출이 모호해지는 경우

선언은 가능하지만 호출 시점에 모호할 수도 있다.

```swift
func show(_ value: Int) { }
func show(_ value: Int?) { }

show(5)      // ⚠️ 모호할 수 있다 — Int가 Int?로 승격 가능
```

이런 경우 컴파일러가 `ambiguous use of 'show'` 에러를 낸다. 타입을 명시해 해결한다.

```swift
show(5 as Int)
show(Optional(5))
```

### 이 코드가 좋은 설계인가

**동작은 정상이지만 개선 여지가 있다.**

**① 세 함수의 본문이 거의 같다**

```swift
static func getCountryBy(name: String) -> Country? {
    sample.filter { $0.countryName.lowercased() == name.lowercased() }.first
}
static func getCountryBy(code: String) -> Country? {
    sample.filter { $0.countryCode.lowercased() == code.lowercased() }.first
}
static func getCountryBy(currencyCode: String) -> Country? {
    sample.filter { $0.currencyCode.lowercased() == currencyCode.lowercased() }.first
}
```

비교하는 프로퍼티만 다르다. [key path](./foreach-id-and-identity-keypath.md)로 묶을 수 있다.

```swift
private static func first(where keyPath: KeyPath<Country, String>, equals value: String) -> Country? {
    sample.first { $0[keyPath: keyPath].lowercased() == value.lowercased() }
}

static func getCountryBy(name: String) -> Country? {
    first(where: \.countryName, equals: name)
}
static func getCountryBy(code: String) -> Country? {
    first(where: \.countryCode, equals: code)
}
static func getCountryBy(currencyCode: String) -> Country? {
    first(where: \.currencyCode, equals: currencyCode)
}
```

공개 API는 그대로 유지하면서 중복이 사라진다.

**② `filter { }.first`는 낭비다**

`filter`는 **모든 원소를 검사해 배열을 만든 뒤** 첫 개를 꺼낸다. `first(where:)`는 **찾으면 즉시 멈춘다.**

```swift
sample.filter { ... }.first      // 전체 순회 + 배열 생성
sample.first { ... }             // 찾으면 중단
```

30개짜리 배열에서는 체감되지 않지만, 습관으로 굳으면 큰 컬렉션에서 문제가 된다.

**③ `sample`이 계산 프로퍼티다**

```swift
static var sample: [Country] {
    [ Country(...), ... ]     // 접근할 때마다 30개를 새로 만든다
}
```

`getCountryBy`를 부를 때마다 배열 30개가 재생성된다. [ViewModel의 `emojiFlag`](./flag-emoji-from-unicode-scalars.md)가 목록의 모든 행에서 호출되므로, 행 개수 × 30개 생성이 된다.

`static let`으로 바꾸면 한 번만 만들어진다. [static var vs static let 문서](./static-stored-vs-computed-property.md)에서 다룬 문제다.

**④ 딕셔너리 조회가 더 적합하다**

조회가 잦다면 미리 인덱스를 만드는 편이 낫다.

```swift
private static let byCurrencyCode: [String: Country] = Dictionary(
    uniqueKeysWithValues: sample.map { ($0.currencyCode.lowercased(), $0) }
)

static func getCountryBy(currencyCode: String) -> Country? {
    byCurrencyCode[currencyCode.lowercased()]
}
```

O(n) 순회가 O(1) 조회로 바뀐다. **단, `currencyCode`가 중복되면 `uniqueKeysWithValues`가 크래시한다.** 이 데이터에는 `EUR`가 여섯 번(독일, 프랑스, 이탈리아, 스페인, 포르투갈, 네덜란드) 나오므로 그대로 쓸 수 없다.

```swift
// 중복을 허용하는 형태
private static let byCurrencyCode: [String: Country] = Dictionary(
    sample.map { ($0.currencyCode.lowercased(), $0) },
    uniquingKeysWith: { first, _ in first }    // 첫 번째를 유지
)
```

**이 중복이 원래 코드에도 영향을 준다.** `getCountryBy(currencyCode: "EUR")`는 `sample` 순서상 첫 번째인 **독일**을 돌려준다. 의도한 동작인지 확인할 만한 지점이다.

### 오버로딩 vs 다른 이름

**오버로딩이 항상 최선은 아니다.**

```swift
// 오버로딩
getCountryBy(name:)
getCountryBy(code:)
getCountryBy(currencyCode:)

// 다른 이름
country(named:)
country(withCountryCode:)
country(withCurrencyCode:)
```

Swift API Design Guidelines는 **역할이 같을 때만 오버로딩**을 권한다. 이 경우는 "국가를 찾는다"는 역할이 동일하므로 오버로딩이 적절하다.

반면 동작이 다르면 이름을 달리해야 한다.

```swift
// ⚠️ 나쁜 오버로딩 — 하는 일이 다르다
func process(data: Data) { save(data) }
func process(url: URL) { download(url) }

// ✅ 이름으로 구분
func save(_ data: Data) { }
func download(from url: URL) { }
```

### 정리

```text
왜 에러가 아닌가
  Swift의 함수 이름에는 argument label이 포함된다
    getCountryBy(name:)
    getCountryBy(code:)
    getCountryBy(currencyCode:)
  → 서로 다른 함수다

Java/C++는 파라미터 타입만 보므로 같은 시그니처 → 에러

Swift의 오버로딩 구분 기준
  argument label / 파라미터 타입 / 파라미터 개수 / 반환 타입

에러가 나는 경우
  라벨까지 같을 때
  _로 라벨을 생략해 타입도 같을 때

이 코드의 개선 여지
  세 함수 본문이 중복 → key path로 통합
  filter{}.first → first(where:)
  static var sample → static let
  EUR 중복 — 첫 번째(독일)만 반환된다
```

## 학습 체크리스트

- [ ] 두 함수의 라벨을 같게 만들어 `invalid redeclaration` 에러를 확인한다.
- [ ] 라벨을 `_`로 바꿔 두 함수를 만들어 에러가 나는지 확인한다.
- [ ] Java나 Kotlin에서 같은 코드를 작성해 에러를 비교한다.
- [ ] 반환 타입만 다른 오버로딩을 만들어 타입 어노테이션으로 선택해 본다.
- [ ] `func show(_ v: Int)`와 `func show(_ v: Int?)`를 만들어 모호성 에러를 확인한다.
- [ ] key path를 쓰는 `first(where:equals:)`로 세 함수를 통합해 본다.
- [ ] `filter { }.first`를 `first(where:)`로 바꿔 본다.
- [ ] `sample`에 `print`를 넣어 `getCountryBy` 호출마다 배열이 재생성되는지 확인한다.
- [ ] `static var sample`을 `static let`으로 바꾸고 호출 횟수를 비교한다.
- [ ] `getCountryBy(currencyCode: "EUR")`가 어느 국가를 돌려주는지 확인한다.
- [ ] 딕셔너리 인덱스를 만들어 조회를 O(1)로 바꿔 본다.
- [ ] `Dictionary(uniqueKeysWithValues:)`로 EUR 중복 시 크래시하는지 확인한다.
- [ ] `uniquingKeysWith:`로 중복을 처리해 본다.

## 공식 참고 자료

- [Swift 공식 문서: Functions — Function Argument Labels and Parameter Names](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/#Function-Argument-Labels-and-Parameter-Names)
- [Swift 공식 문서: Functions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/)
- [Swift 공식 문서: Declarations — Function Declaration](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Function-Declaration)
- [Swift 공식 문서: Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/methods/)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Apple: Sequence.first(where:)](https://developer.apple.com/documentation/swift/sequence/first(where:))
- [Apple: Sequence.filter(_:)](https://developer.apple.com/documentation/swift/sequence/filter(_:))
- [Apple: Dictionary.init(_:uniquingKeysWith:)](https://developer.apple.com/documentation/swift/dictionary/init(_:uniquingkeyswith:)-6ijgm)
- [Apple: KeyPath](https://developer.apple.com/documentation/swift/keypath)
