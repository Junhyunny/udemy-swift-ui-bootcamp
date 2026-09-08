# `Codable`과 `CodingKeys` — JSON을 타입으로 옮기기

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
struct News: Codable, Identifiable {
    let id = UUID()
    let status: String
    let totalResults: Int
    let articles: [Article]

    enum CodingKeys: String, CodingKey {
        case status
        case totalResults
        case articles
    }
}
```

```swift
struct Article: Codable, Identifiable {
    let id = UUID()
    // ...
    enum CodingKeys: CodingKey {     // ← String이 없다
        case source
        // ...
    }
}
```

## 1부 — `Codable`

### 정체는 타입 별칭이다

> `Codable` is a type alias for the `Encodable` and `Decodable` protocols. When you use `Codable` as a type or a generic constraint, it matches any type that conforms to both protocols.

```swift
typealias Codable = Decodable & Encodable
```

프로토콜이 아니라 **두 프로토콜을 묶은 별칭**이다. [typealias 문서](./typealias-and-associated-type.md)에서 다룬 "여러 프로토콜 묶기" 용법의 표준 라이브러리 사례다.

| 프로토콜 | 방향 | 요구사항 |
| --- | --- | --- |
| `Decodable` | 외부 데이터 → Swift 타입 | `init(from decoder:)` |
| `Encodable` | Swift 타입 → 외부 데이터 | `encode(to encoder:)` |
| `Codable` | 양방향 | 위 둘 다 |

**한 방향만 필요하면 한쪽만 채택하는 것이 낫다.** 이 예제는 서버 응답을 **읽기만** 하므로 `Decodable`만으로 충분하다.

```swift
struct News: Decodable, Identifiable { ... }
```

### 언제 쓰나

**JSON·plist 같은 외부 데이터 형식과 Swift 타입 사이를 변환할 때**다. 가장 흔한 경우가 이 예제처럼 API 응답을 파싱하는 것이다.

```swift
let news = try JSONDecoder().decode(News.self, from: data)
```

`News.self`처럼 타입을 넘기는 것도 [메타타입](./metatype-and-self.md)의 용법이다.

주요 용도를 정리하면 이렇다.

- **네트워크 응답 파싱** — 이 예제
- **로컬 저장** — `UserDefaults`, 파일에 JSON으로 저장
- **네비게이션 상태 복원** — [`NavigationPath.codable`](./navigation-path-and-typed-array.md)이 `Codable`을 요구한다
- **앱 간 데이터 전달**

### 자동 합성 — 대부분 선언만으로 끝난다

`Hashable`처럼 컴파일러가 구현을 만들어 준다. 조건은 **모든 저장 프로퍼티가 `Codable`** 인 것이다.

`Source`가 그 예다.

```swift
struct Source: Codable {
    let id: String?
    let name: String
}
```

`String?`과 `String`이 모두 `Codable`이므로 `init(from:)`과 `encode(to:)`가 자동 생성된다. `CodingKeys`도 프로퍼티 이름 그대로 만들어진다.

**표준 타입 대부분이 이미 `Codable`이다.** `String`, `Int`, `Double`, `Bool`, `Date`, `Data`, `URL`, `UUID`, 그리고 이들을 담은 `Array`·`Dictionary`·`Optional`도 포함된다. 그래서 `[Article]`처럼 중첩된 구조도 각 요소가 `Codable`이면 자동으로 처리된다.

### 옵셔널의 의미

`Article`의 프로퍼티를 보면 옵셔널이 섞여 있다.

```swift
let author: String?          // 없을 수 있다
let title: String            // 반드시 있어야 한다
let description: String?
```

**디코딩에서 이 차이가 중요하다.**

- **비옵셔널** — JSON에 키가 없거나 `null`이면 **디코딩 실패**(에러를 던진다)
- **옵셔널** — 키가 없거나 `null`이면 `nil`이 되고 성공한다

API 응답에서 값이 없을 수 있는 필드는 반드시 옵셔널로 선언해야 한다. NewsAPI는 `author`나 `content`가 `null`인 기사가 흔하므로 이 선언이 맞다.

## 2부 — `CodingKeys`

### 무엇을 하는가

`CodingKey`는 **JSON의 키 이름과 Swift 프로퍼티 이름을 연결**하는 프로토콜이다.

```swift
protocol CodingKey : CustomDebugStringConvertible, CustomStringConvertible, Sendable {
    var stringValue: String { get }
    var intValue: Int? { get }
    init?(stringValue: String)
    init?(intValue: Int)
}
```

직접 구현할 일은 거의 없다. **`CodingKeys`라는 이름의 중첩 `enum`으로 선언하면 컴파일러가 알아서 쓴다.** 이름이 정확히 `CodingKeys`여야 한다.

### 언제 필요한가

**① 키 이름이 다를 때 — 가장 흔한 이유**

```swift
struct User: Decodable {
    let firstName: String
    let profileImageURL: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"           // snake_case → camelCase
        case profileImageURL = "profile_image_url"
    }
}
```

서버가 snake_case를 쓰고 Swift는 camelCase를 쓰는 경우다.

**② 일부 프로퍼티를 제외할 때 — 이 예제가 여기 해당한다**

```swift
struct News: Codable, Identifiable {
    let id = UUID()          // ← JSON에 없다
    let status: String
    let totalResults: Int
    let articles: [Article]

    enum CodingKeys: String, CodingKey {
        case status           // id가 목록에 없다
        case totalResults
        case articles
    }
}
```

**`id`를 `CodingKeys`에서 빼는 것이 핵심이다.** `id`는 `Identifiable`을 만족시키려고 앱에서 만든 값이고 서버 응답에는 없다. `CodingKeys`에 포함되면 디코더가 JSON에서 `id`를 찾다가 실패한다.

`CodingKeys`를 선언하는 순간 **거기 나열된 것만** 인코딩·디코딩 대상이 된다. 나열되지 않은 프로퍼티는 무시되고, 대신 **기본값이 있어야 한다.** `let id = UUID()`가 기본값을 갖고 있으므로 성립한다.

**③ 키 순서나 형식을 바꿔야 할 때**

**④ 중첩 구조를 평탄화할 때** — 이 경우는 `init(from:)`을 직접 구현해야 한다.

### `String`을 왜 붙이나 — raw value

```swift
enum CodingKeys: String, CodingKey { ... }
```

여기서 `String`은 **상속이 아니라 raw value 타입 지정**이다. 자세한 내용은 [enum raw value 문서](./enum-raw-values.md)에 정리했다.

`String` raw value가 있으면 각 case의 **문자열 값이 JSON 키**가 된다.

```swift
enum CodingKeys: String, CodingKey {
    case firstName = "first_name"   // 명시하면 그 문자열
    case status                     // 생략하면 case 이름 그대로 "status"
}
```

**`String`을 붙이지 않으면 이름을 바꿀 수 없다.** `Article`이 그 상태다.

```swift
struct Article: Codable, Identifiable {
    enum CodingKeys: CodingKey {    // ← String 없음
        case source
        case author
        // ...
    }
}
```

이 코드도 **컴파일되고 동작한다.** `CodingKey` 프로토콜의 `stringValue`가 case 이름을 그대로 돌려주기 때문이다. 하지만 두 가지가 아쉽다.

- `case author = "author_name"`처럼 **이름을 매핑할 수 없다**
- `News`는 `String`을 붙였고 `Article`은 안 붙여 **일관성이 없다**

`String`을 붙여 두는 편이 안전하다. 나중에 서버가 키 이름을 바꿔도 한 줄로 대응할 수 있다.

### 실은 `CodingKeys`가 필요 없을 수도 있다

`Article`의 `CodingKeys`를 다시 보자.

```swift
enum CodingKeys: CodingKey {
    case source
    case author
    case title
    case description
    case url
    case urlToImage
    case publishedAt
    case content
}
```

**`id`를 제외하고 모든 프로퍼티가 그대로 나열되어 있다.** 즉 `id`를 빼는 것 외에 하는 일이 없다.

문제는 이 목록이 **프로퍼티를 추가할 때마다 함께 고쳐야 하는 중복**이라는 점이다. 하나 빠뜨리면 그 필드가 조용히 디코딩되지 않는다.

**더 나은 방법**은 `id`를 저장 프로퍼티로 두지 않는 것이다.

```swift
struct Article: Decodable, Identifiable {
    var id: String { url }      // 계산 프로퍼티 — 인코딩 대상이 아니다
    let source: Source
    let author: String?
    let title: String
    let url: String
    // ...
    // CodingKeys가 필요 없다
}
```

**계산 프로퍼티는 `Codable`이 무시한다.** 저장 프로퍼티만 대상이기 때문이다. 그래서 `CodingKeys`를 쓸 이유가 사라진다.

`url`을 `id`로 쓰면 **신원이 안정적**이라는 이점도 생긴다. `let id = UUID()`는 디코딩할 때마다 새 값이 되어, 같은 기사를 두 번 받으면 다른 것으로 취급된다. [`Hashable`과 신원 문제](./hashable-id-and-collisions.md)와 [static var 문제](./static-stored-vs-computed-property.md)에서 다룬 것과 같은 함정이다.

`News`도 같은 방식으로 정리할 수 있다.

```swift
struct News: Decodable {
    let status: String
    let totalResults: Int
    let articles: [Article]
}
```

`News`는 목록에 나열되는 타입이 아니므로 `Identifiable`이 필요 없다. 그러면 `id`도, `CodingKeys`도 사라진다.

### snake_case를 한 번에 처리하는 방법

키 이름이 규칙적으로 다르다면 `CodingKeys`를 일일이 쓰지 않아도 된다.

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
```

`first_name` → `firstName` 변환을 자동으로 해 준다. NewsAPI는 이미 camelCase(`totalResults`, `urlToImage`)를 쓰므로 이 예제에는 불필요하다.

날짜도 전략을 지정할 수 있다.

```swift
decoder.dateDecodingStrategy = .iso8601
```

예제의 `publishedAt`이 `String`으로 선언되어 있는데, NewsAPI는 ISO 8601 형식(`2024-01-15T10:30:00Z`)을 보낸다. `Date`로 선언하고 위 전략을 쓰면 타입이 정확해진다.

```swift
let publishedAt: Date
```

### 디코딩 오류를 읽는 법

`DecodingError`는 무엇이 잘못됐는지 상세히 알려 준다.

```swift
do {
    return try JSONDecoder().decode(T.self, from: data)
} catch let error as DecodingError {
    switch error {
    case .keyNotFound(let key, let context):
        print("키 없음: \(key.stringValue) — \(context.debugDescription)")
    case .typeMismatch(let type, let context):
        print("타입 불일치: \(type) — \(context.codingPath)")
    case .valueNotFound(let type, let context):
        print("값이 null: \(type) — \(context.codingPath)")
    case .dataCorrupted(let context):
        print("데이터 손상: \(context.debugDescription)")
    @unknown default:
        print("알 수 없는 디코딩 오류")
    }
    throw NetworkError.decodingError
}
```

이 예제의 `NetworkingManager`는 이렇게 되어 있다.

```swift
do {
    return try JSONDecoder().decode(T.self, from: data)
} catch {
    throw NetworkError.decodingError      // ← 원인 정보가 사라진다
}
```

**원래 오류를 버리고 있다.** 디코딩 실패의 원인(어느 키인지, 어떤 타입인지)을 알 수 없어 디버깅이 어렵다. 최소한 로그를 남기거나, 오류를 연관값으로 실어 보내는 편이 낫다.

```swift
enum NetworkError: Error {
    case decodingError(underlying: Error)
}
```

[커스텀 에러 문서](./async-throws-and-custom-errors.md)에서 이어서 다룬다.

## 학습 체크리스트

- [ ] `News`의 `CodingKeys`에서 `case id`를 추가하고 디코딩이 실패하는지 확인한다.
- [ ] `CodingKeys` 전체를 지우고 `id` 때문에 디코딩이 실패하는 것을 확인한다.
- [ ] `id`를 `var id: String { url }` 계산 프로퍼티로 바꾸고 `CodingKeys`를 지워 본다.
- [ ] `Article`의 `CodingKeys`에 `String`을 붙이고 `case author = "author"`처럼 매핑해 본다.
- [ ] `CodingKeys`에서 프로퍼티 하나를 빼고 그 값이 어떻게 되는지 확인한다.
- [ ] 비옵셔널 프로퍼티에 `null`이 오는 JSON으로 디코딩해 오류를 확인한다.
- [ ] 같은 프로퍼티를 옵셔널로 바꿔 성공하는지 확인한다.
- [ ] `Codable`을 `Decodable`로 바꿔도 동작하는지 확인한다.
- [ ] `publishedAt`을 `Date`로 바꾸고 `dateDecodingStrategy = .iso8601`을 적용한다.
- [ ] `DecodingError`를 `switch`로 분기해 실제 오류 종류를 출력한다.
- [ ] 일부러 타입을 틀리게 선언(`Int` → `String`)해 `typeMismatch`를 확인한다.
- [ ] `keyDecodingStrategy = .convertFromSnakeCase`를 시험해 본다.
- [ ] `News`를 `JSONEncoder`로 인코딩해 어떤 JSON이 나오는지 확인한다.
- [ ] `Source`처럼 `CodingKeys` 없는 타입이 자동 합성으로 동작하는 것을 확인한다.

## 공식 참고 자료

- [Apple: Codable](https://developer.apple.com/documentation/swift/codable)
- [Apple: Decodable](https://developer.apple.com/documentation/swift/decodable)
- [Apple: Encodable](https://developer.apple.com/documentation/swift/encodable)
- [Apple: CodingKey](https://developer.apple.com/documentation/swift/codingkey)
- [Apple: Encoding, Decoding, and Serialization](https://developer.apple.com/documentation/swift/encoding-decoding-and-serialization)
- [Apple: JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder)
- [Apple: JSONEncoder](https://developer.apple.com/documentation/foundation/jsonencoder)
- [Apple: JSONDecoder.KeyDecodingStrategy](https://developer.apple.com/documentation/foundation/jsondecoder/keydecodingstrategy)
- [Apple: JSONDecoder.DateDecodingStrategy](https://developer.apple.com/documentation/foundation/jsondecoder/datedecodingstrategy)
- [Apple: DecodingError](https://developer.apple.com/documentation/swift/decodingerror)
- [Apple: KeyedDecodingContainer](https://developer.apple.com/documentation/swift/keyeddecodingcontainer)
- [Apple: Identifiable](https://developer.apple.com/documentation/swift/identifiable)
