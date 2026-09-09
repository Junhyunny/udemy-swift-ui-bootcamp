# 백틱(`` ` ``)으로 예약어를 식별자로 쓰기

## 질문이 나온 코드

`chapter-80/chapter-80/Utils/Endpoint.swift`

```swift
enum Endpoint {
    // TODO, default 가 아니라 `default`는 뭔가 다른거야? 예약어이기 때문에 `` 구문 안에 작성한건가?
    case `default`
    case withSymbols
}
```

## 공부할 내용

### 짐작이 정확하다

**`default`가 Swift 예약어이기 때문에 백틱으로 감쌌다.** 백틱은 "이건 키워드가 아니라 이름으로 쓰겠다"는 표시다.

Swift 공식 문서의 설명이다.

> To use a reserved word as an identifier, put a backtick (`` ` ``) before and after it. For example, `class` isn't a valid identifier, but `` `class` `` is valid.

`default`는 `switch` 문의 기본 케이스를 나타내는 키워드다.

```swift
switch value {
case 1: ...
default: ...      // ← 여기서의 default가 키워드
}
```

그래서 백틱 없이 `case default`라고 쓰면 컴파일 에러다.

```swift
enum Endpoint {
    case default        // ⚠️ error: keyword 'default' cannot be used as an identifier here
}
```

### 사용하는 쪽에서는 백틱이 필요 없다

**선언할 때만 필요하다.** 참조할 때는 문맥으로 구분되므로 그냥 쓴다.

```swift
enum Endpoint {
    case `default`          // 선언 — 백틱 필요
}

Endpoint.default            // 사용 — 백틱 불필요
```

이 파일의 다른 부분이 그것을 보여 준다.

```swift
switch self {
case .default:              // 백틱 없이 쓴다
    return ["access_key": AppConfig.apiKey]
case .withSymbols:
    return [...]
}
```

```swift
return urlSession(ExchangeRate.self, with: Endpoint.withSymbols.url!)
```

**단, 백틱을 붙여도 동작한다.** `case .`default`:`처럼 써도 되지만 불필요하게 지저분해진다.

### 백틱을 쓰는 다른 사례들

`default` 외에도 예약어를 이름으로 쓰고 싶은 경우가 있다.

```swift
// JSON 키가 예약어일 때 — 실무에서 가장 흔하다
struct Response: Decodable {
    let `default`: String
    let `class`: String
    let `for`: Int
}

// 열거형 케이스
enum State {
    case `init`
    case `continue`
    case `return`
}

// 프로퍼티·메서드
struct Config {
    let `protocol`: String
    func `do`() { }
}
```

**서버가 준 JSON 키가 Swift 예약어인 경우**가 백틱이 정말 필요한 상황이다. 다만 그때는 [`CodingKeys`로 매핑](./codable-and-codingkey.md)하는 편이 더 깔끔하다.

```swift
// 백틱 대신
struct Response: Decodable {
    let defaultValue: String

    enum CodingKeys: String, CodingKey {
        case defaultValue = "default"     // 이름을 바꿔 받는다
    }
}
```

### 백틱이 필요 없는 경우도 있다

Swift는 **문맥으로 구분할 수 있으면 예약어를 그냥 허용한다.** 그래서 모든 키워드가 백틱을 요구하지는 않는다.

```swift
enum Weekday {
    case some       // Optional의 .some과 겹치지만 문제없다
    case none       // ⚠️ 이건 주의 — Optional.none과 혼동될 수 있다
}

struct Model {
    let type: String      // type은 백틱 없이 된다
    let value: Int        // value도 된다
}

func get() { }            // get은 프로퍼티 접근자 문맥에서만 키워드
```

`get`, `set`, `willSet`, `didSet`, `type`, `value` 등은 **문맥 의존 키워드(contextual keyword)** 라 특정 위치에서만 키워드로 취급된다.

**`case none`은 조심해야 한다.** 컴파일은 되지만 `Optional.none`과 혼동되어 예상치 못한 동작을 만들 수 있다. 이름을 바꾸는 편이 안전하다.

### `Self`와 `self`처럼 대소문자로 구분되는 것도 있다

Swift 키워드는 **대소문자를 구분**한다.

```swift
struct Model {
    let Type: String        // 대문자 T — 백틱 없이 가능
    let `type`: String      // 소문자 — 문맥에 따라 백틱이 필요할 수 있다
}
```

관련해서 `Self`(대문자)와 `self`(소문자)의 차이는 [메타타입 문서](./metatype-and-self.md)에서 다뤘다.

### 백틱을 쓰는 것이 좋은 선택인가

**필요할 때만 쓴다.** 대안이 있으면 대안이 낫다.

| 상황 | 판단 |
| --- | --- |
| JSON 키가 예약어 | `CodingKeys`로 매핑 (백틱보다 명확) |
| 열거형 케이스 이름 | 백틱도 괜찮지만 다른 이름을 먼저 검토 |
| 외부 API가 강제 | 백틱 사용 |
| 그냥 그 단어를 쓰고 싶음 | **다른 이름을 고민** |

이 예제의 `case `default``는 판단이 애매하다. **의미상 "기본 엔드포인트"이므로 `default`가 자연스럽지만**, 다른 이름도 가능하다.

```swift
enum Endpoint {
    case latest                          // "최신 환율" — 더 구체적
    case withSymbols(base: String, symbols: [String])
}
```

`latest`가 실제 API 경로(`/v1/latest`)와도 맞아 의도가 더 잘 드러난다. 백틱을 없앨 수 있다는 부가 이점도 있다.

**다만 강의 예제를 따라가는 중이라면 그대로 두어도 무방하다.** 백틱 자체는 정당한 Swift 문법이다.

### 정리

```text
백틱(`)은 예약어를 식별자로 쓰게 해 준다  ✅ 짐작이 맞다

선언할 때만 필요하다
  case `default`      선언 — 백틱 필요
  Endpoint.default    사용 — 백틱 불필요

가장 실용적인 용도: JSON 키가 예약어일 때
  하지만 CodingKeys 매핑이 더 깔끔하다

문맥 의존 키워드(get, set, type, value)는 백틱이 불필요하다
case none은 Optional.none과 혼동되므로 주의
```

## 학습 체크리스트

- [ ] `case `default``에서 백틱을 지우고 컴파일 에러 메시지를 읽는다.
- [ ] `Endpoint.default`를 `` Endpoint.`default` ``로 써도 동작하는지 확인한다.
- [ ] `switch`의 `case .default:`에 백틱을 붙여도 되는지 확인한다.
- [ ] `let `class` = "A"`처럼 다른 예약어를 백틱으로 써 본다.
- [ ] `let type = "A"`가 백틱 없이 되는 것을 확인한다 (문맥 의존 키워드).
- [ ] `enum X { case none }`을 만들고 `Optional`과의 혼동 가능성을 확인한다.
- [ ] JSON 키가 `"default"`인 응답을 `CodingKeys`로 매핑해 본다.
- [ ] 백틱 방식과 `CodingKeys` 방식의 가독성을 비교한다.
- [ ] `case `default``를 `case latest`로 바꿔 백틱을 없애 본다.
- [ ] Swift 예약어 목록을 문서에서 훑어본다.

## 공식 참고 자료

- [Swift 공식 문서: Lexical Structure — Identifiers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/lexicalstructure/#Identifiers)
- [Swift 공식 문서: Lexical Structure — Keywords and Punctuation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/lexicalstructure/#Keywords-and-Punctuation)
- [Swift 공식 문서: Enumerations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/)
- [Swift 공식 문서: Control Flow — Switch](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/#Switch)
- [Apple: CodingKey](https://developer.apple.com/documentation/swift/codingkey)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
