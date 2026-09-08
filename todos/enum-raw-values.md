# `enum Foo: String`은 상속이 아니다 — raw value

`enum`이 `Hashable`을 채택하는 이야기는 [별도 문서](./enum-hashable-conformance.md)에 있다. 이 문서는 **콜론 뒤에 `String` 같은 타입이 오는 경우**를 다룬다.

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
enum CodingKeys: String, CodingKey {
    case status
    case totalResults
    case articles
}
```

```swift
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
```

## 공부할 내용

### 결론 먼저 — 상속이 아니다

`enum`은 **상속을 할 수 없다.** 콜론 뒤에 오는 것은 두 가지 중 하나다.

```swift
enum CodingKeys: String, CodingKey { ... }
//               ↑       ↑
//          raw value  프로토콜
//            타입
```

| 위치 | 의미 |
| --- | --- |
| 첫 번째가 `String`, `Int` 등 구체 타입 | **raw value 타입 지정** |
| 그 밖의 것 (프로토콜) | 프로토콜 준수 |

`enum HTTPMethod: String`은 "`String`을 상속한다"가 아니라 **"각 case가 `String` 값을 갖는다"** 는 선언이다.

[Swift의 타입 체계와 상속](./swift-type-system-and-inheritance.md)에서 다룬 대로, Swift에서 상속은 `class`에만 있다.

### raw value란

> As an alternative to associated values, enumeration cases can come prepopulated with default values (called *raw values*), which are all of the same type.

**각 case에 미리 붙여 두는 고정값**이다. 모든 case가 같은 타입의 값을 갖는다.

Swift 공식 문서의 예제다.

```swift
enum ASCIIControlCharacter: Character {
    case tab = "\t"
    case lineFeed = "\n"
    case carriageReturn = "\r"
}
```

`HTTPMethod`가 정확히 같은 구조다.

```swift
enum HTTPMethod: String {
    case get = "GET"        // rawValue == "GET"
    case post = "POST"
}
```

### 무엇을 할 수 있게 되나

raw value를 지정하면 **두 가지 기능**이 생긴다.

**① `rawValue` 프로퍼티로 값을 꺼낸다**

예제가 이것을 쓴다.

```swift
request.httpMethod = method.rawValue      // "GET"
```

`URLRequest.httpMethod`는 `String?`을 요구한다. `HTTPMethod` 열거형을 그대로 넘길 수 없으므로 `rawValue`로 변환한다. **타입 안전한 열거형으로 코드를 쓰고, 경계에서만 문자열로 바꾸는** 좋은 패턴이다.

```swift
// enum이 없다면
request.httpMethod = "GET"        // 오타 가능: "GTE", "Get"

// enum이 있으면
request.httpMethod = HTTPMethod.get.rawValue   // 컴파일러가 검증
```

**② raw value로 case를 찾는다 — `init?(rawValue:)`**

```swift
let method = HTTPMethod(rawValue: "POST")     // Optional(.post)
let unknown = HTTPMethod(rawValue: "PATCH")   // nil
```

**실패 가능한 이니셜라이저**라 옵셔널을 돌려준다. 맞는 case가 없으면 `nil`이다.

서버가 보낸 문자열을 열거형으로 바꿀 때 유용하다.

```swift
if let method = HTTPMethod(rawValue: serverValue) {
    // 알려진 메서드
} else {
    // 모르는 값 — 처리 방법 결정
}
```

### 값을 생략하면 어떻게 되나

`CodingKeys`가 그 경우다.

```swift
enum CodingKeys: String, CodingKey {
    case status              // rawValue == "status"
    case totalResults        // rawValue == "totalResults"
    case articles            // rawValue == "articles"
}
```

**`String` raw value는 생략하면 case 이름이 그대로 값이 된다.** 그래서 `status`의 `rawValue`는 `"status"`다.

`Int`는 규칙이 다르다.

```swift
enum Planet: Int {
    case mercury = 1        // 1
    case venus              // 2  — 앞 값에서 1 증가
    case earth              // 3
}

enum Level: Int {
    case low                // 0  — 첫 값을 생략하면 0부터
    case medium             // 1
    case high               // 2
}
```

| raw value 타입 | 생략 시 |
| --- | --- |
| `String` | **case 이름 그대로** |
| `Int` | 0부터, 또는 앞 값 + 1 |
| 그 외 (`Character`, `Double` 등) | **생략 불가 — 명시해야 한다** |

이 규칙 덕분에 `CodingKeys`에서 JSON 키와 프로퍼티 이름이 같을 때는 값을 안 써도 된다. 다를 때만 쓴다.

```swift
enum CodingKeys: String, CodingKey {
    case status                            // "status"
    case profileImageURL = "profile_image_url"   // 다르므로 명시
}
```

[Codable 문서](./codable-and-codingkey.md)에서 이어서 다룬다.

### 어떤 타입을 raw value로 쓸 수 있나

`String`, `Character`, 정수 타입, 부동소수점 타입이다. 정확히는 `RawRepresentable`을 통해 **리터럴로 표현 가능한 타입**이어야 한다.

```swift
enum Direction: String { case north, south }        // ✅
enum Priority: Int { case low = 1, high = 10 }      // ✅
enum Scale: Double { case half = 0.5, full = 1.0 }  // ✅
enum Marker: Character { case star = "*" }          // ✅

enum Bad: [String] { ... }                          // ❌ 배열은 불가
enum Bad2: CGSize { ... }                           // ❌ 구조체는 불가
```

### raw value와 연관값(associated value)은 다르다

혼동하기 쉬운 두 개념이다. 같은 파일에 둘 다 나온다.

```swift
// raw value — 모든 case가 같은 타입의 고정값
enum HTTPMethod: String {
    case get = "GET"
}

// 연관값 — case마다 다른 타입의 값을 담을 수 있고, 런타임에 정해진다
enum NetworkError: Error {
    case invalidURL                          // 값 없음
    case requestFailed(statusCode: Int)      // Int를 담는다
    case decodingError
}
```

| | raw value | 연관값 |
| --- | --- | --- |
| 문법 | `enum X: String { case a = "A" }` | `enum X { case a(Int) }` |
| 값이 정해지는 시점 | **컴파일 타임 (고정)** | **런타임 (case를 만들 때)** |
| case별 타입 | 모두 같아야 함 | 달라도 됨 |
| 개수 | case당 하나 | case당 여러 개 가능 |
| 꺼내는 법 | `.rawValue` | `switch`의 패턴 매칭 |

**둘을 함께 쓸 수는 없다.**

```swift
enum Bad: String {
    case a = "A"
    case b(Int)          // ❌ raw value가 있는 enum은 연관값을 가질 수 없다
}
```

연관값을 꺼낼 때는 패턴 매칭을 쓴다.

```swift
catch let error as NetworkError {
    switch error {
    case .requestFailed(let statusCode):     // 값을 꺼낸다
        print("HTTP \(statusCode)")
    case .invalidURL:
        print("URL이 잘못됐다")
    default:
        break
    }
}
```

[에러 타입 문서](./async-throws-and-custom-errors.md)에서 이어서 다룬다.

### `CaseIterable`과 조합

raw value가 있는 열거형은 `CaseIterable`과 잘 어울린다.

```swift
enum HTTPMethod: String, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

HTTPMethod.allCases.map(\.rawValue)   // ["GET", "POST", "PUT", "DELETE"]
```

Picker의 선택지를 만들 때 흔히 쓰는 패턴이다.

```swift
Picker("메서드", selection: $method) {
    ForEach(HTTPMethod.allCases, id: \.self) { m in
        Text(m.rawValue).tag(m)
    }
}
```

### raw value가 필요 없는 경우

**모든 열거형에 raw value가 필요한 것은 아니다.**

```swift
// 필요 없다 — 내부에서만 쓰이는 상태
enum LoadState {
    case idle, loading, loaded, failed
}

// 필요 없다 — 연관값이 있다
enum NetworkError: Error {
    case requestFailed(statusCode: Int)
}
```

외부 표현(문자열·숫자)과 주고받을 일이 없으면 붙이지 않는다. 붙이면 "이 값이 외부와 연결된다"는 신호가 되므로, 불필요하게 붙이면 오해를 준다.

**raw value를 붙이는 기준**은 이렇다.

- JSON·DB 등 **외부 형식과 매핑**해야 한다 → 필요
- URL 경로, HTTP 메서드처럼 **문자열로 변환**해야 한다 → 필요
- 사용자에게 보여줄 **표시 문자열**이 필요하다 → 계산 프로퍼티가 더 낫다

마지막 경우를 구분하는 것이 중요하다.

```swift
// ⚠️ 지역화가 안 되고, 표시용 문자열이 데이터 계약에 섞인다
enum Category: String {
    case tech = "기술"
    case sports = "스포츠"
}

// ✅ 데이터 값과 표시 문자열을 분리
enum Category: String {
    case tech = "technology"       // 서버와 주고받는 값
    case sports = "sports"

    var displayName: String {      // 화면에 보여줄 값
        switch self {
        case .tech:   "기술"
        case .sports: "스포츠"
        }
    }
}
```

### 정리

```text
enum HTTPMethod: String
                 ↑
          raw value 타입 (상속이 아니다)

생기는 기능
  .rawValue           case → 값
  init?(rawValue:)    값 → case (옵셔널)

생략 규칙
  String: case 이름 그대로
  Int:    0부터 또는 앞 값 +1
  그 외:  명시 필수

raw value ≠ 연관값
  raw value: 컴파일 타임 고정, 모든 case 같은 타입
  연관값:    런타임 결정, case마다 다른 타입 가능
  둘을 함께 쓸 수 없다
```

## 학습 체크리스트

- [ ] `HTTPMethod.get.rawValue`를 출력해 `"GET"`이 나오는지 확인한다.
- [ ] `CodingKeys.status.rawValue`를 출력해 case 이름이 그대로 나오는지 확인한다.
- [ ] `HTTPMethod(rawValue: "POST")`와 `HTTPMethod(rawValue: "PATCH")`의 결과를 비교한다.
- [ ] `enum HTTPMethod: String`에서 `String`을 지우고 `rawValue`가 사라지는 것을 확인한다.
- [ ] `enum Planet: Int { case a = 1, b, c }`에서 `b`와 `c`의 값을 출력한다.
- [ ] `Int` raw value에서 첫 값을 생략하면 0부터 시작하는 것을 확인한다.
- [ ] `enum X: Character { case a }`처럼 값을 생략해 컴파일 에러를 확인한다.
- [ ] raw value가 있는 `enum`에 연관값 case를 추가해 에러를 확인한다.
- [ ] `NetworkError.requestFailed(statusCode: 404)`를 만들어 `switch`로 값을 꺼낸다.
- [ ] `HTTPMethod`에 `CaseIterable`을 붙여 `allCases.map(\.rawValue)`를 출력한다.
- [ ] `enum`에서 `class`를 상속하려 시도해 에러 메시지를 읽는다.
- [ ] 표시용 문자열을 `displayName` 계산 프로퍼티로 분리해 본다.
- [ ] `enum Bad: [String]`처럼 배열을 raw value로 지정해 에러를 확인한다.

## 공식 참고 자료

- [Swift 공식 문서: Enumerations — Raw Values](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/#Raw-Values)
- [Swift 공식 문서: Enumerations — Associated Values](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/#Associated-Values)
- [Swift 공식 문서: Enumerations — Initializing from a Raw Value](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/#Initializing-from-a-Raw-Value)
- [Swift 공식 문서: Enumerations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/)
- [Swift 공식 문서: Declarations — Enumeration Declaration](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Enumeration-Declaration)
- [Apple: RawRepresentable](https://developer.apple.com/documentation/swift/rawrepresentable)
- [Apple: CaseIterable](https://developer.apple.com/documentation/swift/caseiterable)
- [Apple: CodingKey](https://developer.apple.com/documentation/swift/codingkey)
- [Apple: URLRequest.httpMethod](https://developer.apple.com/documentation/foundation/urlrequest/httpmethod)
