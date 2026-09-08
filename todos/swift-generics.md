# Swift의 제네릭 — 선언, 사용, 주의사항

`some` 키워드와 opaque type은 [별도 문서](./some-keyword-opaque-types.md)에, `associatedtype`은 [여기](./typealias-and-associated-type.md)에 정리했다. 이 문서는 **제네릭 자체**를 다룬다.

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
func request<T: Decodable>(
    endpoint: String,
    method: HTTPMethod = .get,
    parameters: [String: Any]? = nil,
    headers: [String: String]? = nil,
    responseType: T.Type
) async throws -> T {
    // ...
    return try JSONDecoder().decode(T.self, from: data)
}
```

```swift
let news = try await NetworkingManager.shared.request(
    endpoint: "...",
    responseType: News.self
)
```

## 공부할 내용

### 무엇을 해결하는가

> *Generic code* enables you to write flexible, reusable functions and types that can work with any type, subject to requirements that you define. You can write code that avoids duplication and expresses its intent in a clear, abstracted manner.

Swift 공식 문서가 `swapTwoInts`로 문제를 보여 준다.

```swift
func swapTwoInts(_ a: inout Int, _ b: inout Int) { ... }
```

`String`도 바꾸려면 함수를 또 써야 한다.

```swift
func swapTwoStrings(_ a: inout String, _ b: inout String) { ... }
func swapTwoDoubles(_ a: inout Double, _ b: inout Double) { ... }
```

**내용은 같고 타입만 다른 코드가 반복된다.** 제네릭이 이를 하나로 만든다.

```swift
func swapTwoValues<T>(_ a: inout T, _ b: inout T) { ... }
```

**이 예제에도 같은 문제가 있었을 것이다.** 제네릭이 없다면 이렇게 됐다.

```swift
func requestNews(endpoint: String) async throws -> News { ... }
func requestArticles(endpoint: String) async throws -> [Article] { ... }
func requestUser(endpoint: String) async throws -> User { ... }
// 응답 타입마다 함수를 또 만들어야 한다
```

네트워크 요청 로직(URL 만들기, 헤더 설정, 상태 코드 확인)은 완전히 같고 **디코딩할 타입만 다르다.** 제네릭 함수 하나로 해결된다.

### 선언 방법

**① 타입 파라미터를 `<>` 안에 쓴다**

```swift
func request<T>(...) -> T { ... }
//           ↑
//     타입 파라미터 (자리 표시자)
```

`T`는 관례적인 이름이고 아무 이름이나 쓸 수 있다. 의미가 있으면 이름을 붙이는 편이 낫다.

```swift
func decode<Response: Decodable>(...) -> Response { ... }
func transform<Input, Output>(_ value: Input) -> Output { ... }
```

**② 제약(constraint)을 붙인다 — 실무에서 거의 항상 필요하다**

```swift
func request<T: Decodable>(...) -> T { ... }
//              ↑
//         T는 Decodable을 만족해야 한다
```

제약이 없는 `<T>`는 **아무 것도 할 수 없다.** 어떤 타입인지 모르니 메서드도 프로퍼티도 쓸 수 없다.

이 예제가 `T: Decodable`을 요구하는 이유는 명확하다.

```swift
return try JSONDecoder().decode(T.self, from: data)
//                              ↑
//              decode는 Decodable 타입만 받는다
```

제약을 지우면 이 줄이 컴파일되지 않는다.

**③ 여러 제약은 `&`나 `where`로**

```swift
func process<T: Decodable & Sendable>(_ value: T) { ... }

func process<T>(_ value: T) where T: Decodable, T: Equatable { ... }
```

`where` 절은 조건이 복잡할 때 읽기 좋다.

```swift
func merge<C1, C2>(_ a: C1, _ b: C2) -> [C1.Element]
    where C1: Collection, C2: Collection, C1.Element == C2.Element
{ ... }
```

`C1.Element == C2.Element`처럼 **associated type 사이의 관계**를 요구할 수 있다는 점이 강력하다.

### 사용 방법 — 타입 추론이 대부분 처리한다

**호출할 때 타입 파라미터를 명시하지 않는다.** Swift는 인자에서 추론한다.

```swift
var a = 3, b = 5
swapTwoValues(&a, &b)            // T = Int로 추론
```

**그런데 이 예제는 반환 타입이 `T`다.** 인자만으로는 추론할 수 없다.

```swift
func request<T: Decodable>(endpoint: String) async throws -> T
```

이러면 호출부에서 타입을 알려 줘야 한다.

```swift
let news: News = try await request(endpoint: "...")   // 타입 어노테이션으로
```

**예제는 다른 방법을 쓴다 — 타입을 인자로 받는다.**

```swift
func request<T: Decodable>(
    ...
    responseType: T.Type       // ← 메타타입을 파라미터로
) async throws -> T
```

```swift
let news = try await request(
    endpoint: "...",
    responseType: News.self    // ← 여기서 T = News로 확정
)
```

`T.Type`은 **타입 자체를 받는 파라미터**다. `News.self`를 넘기면 `T`가 `News`로 결정된다. [메타타입과 `.self`](./metatype-and-self.md)에서 다룬 개념이고, `navigationDestination(for:)`이나 `decode(_:from:)`도 같은 방식이다.

**두 방식의 비교**

```swift
// ① 타입 어노테이션 방식
let news: News = try await request(endpoint: "...")

// ② 타입 파라미터 방식 (이 예제)
let news = try await request(endpoint: "...", responseType: News.self)
```

| | 타입 어노테이션 | `responseType:` 인자 |
| --- | --- | --- |
| 호출 코드 | 짧다 | 명시적이다 |
| 어디서 타입이 보이나 | 왼쪽 (변수 선언) | 오른쪽 (인자) |
| 체이닝 | 어려움 | 자연스럽다 |
| 표준 라이브러리 관례 | — | `decode(_:from:)`이 이 방식 |

**②가 SDK의 관례에 가깝다.** `JSONDecoder.decode(News.self, from:)`, `container.decode(String.self, forKey:)`가 모두 그렇다. 반환값을 바로 다른 함수에 넘길 때도 타입이 확정되어 있어 편하다.

`responseType:`을 없애고 싶다면 기본값처럼 동작하게 만들 수도 있다.

```swift
func request<T: Decodable>(
    endpoint: String,
    responseType: T.Type = T.self      // 문맥에서 추론 가능하면 생략
) async throws -> T
```

`navigationDestination(for: K.Type = K.self)`이 실제로 이 패턴을 쓴다.

### 제네릭 타입 — 함수가 아닌 타입에도

`struct`, `class`, `enum`도 제네릭일 수 있다.

```swift
struct Stack<Element> {
    private var items: [Element] = []

    mutating func push(_ item: Element) { items.append(item) }
    mutating func pop() -> Element? { items.popLast() }
}
```

```swift
var intStack = Stack<Int>()
var stringStack = Stack<String>()
```

**이미 매일 쓰고 있다.** `Array<Element>`, `Dictionary<Key, Value>`, `Optional<Wrapped>`, `Set<Element>`가 모두 제네릭 타입이다.

```swift
[String: Any]        // Dictionary<String, Any>의 축약
[Article]            // Array<Article>의 축약
String?              // Optional<String>의 축약
```

이 예제의 `parameters: [String: Any]?`도 제네릭 타입 셋이 겹친 것이다.

**응답 래퍼**를 만들 때도 흔히 쓴다.

```swift
struct APIResponse<Data: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: Data
}

let response = try await request(
    endpoint: "...",
    responseType: APIResponse<News>.self
)
```

### 확장에서의 제네릭 — 조건부 확장

제네릭 타입을 확장할 때 조건을 걸 수 있다.

```swift
extension Stack where Element: Equatable {
    func contains(_ item: Element) -> Bool { items.contains(item) }
}
```

`Element`가 `Equatable`일 때만 이 메서드가 생긴다. [extension 문서](./extension-keyword.md)에서 다룬 조건부 확장이다.

표준 라이브러리가 이 기법을 대량으로 쓴다. `Array`는 요소가 `Equatable`일 때만 `contains`를, `Comparable`일 때만 `sorted()`를 제공한다.

### 주의사항

**① 제약 없는 `<T>`는 대개 잘못된 신호다**

```swift
func doSomething<T>(_ value: T) {
    // T에 대해 아무것도 알 수 없다
    // print(value)는 되지만 그 이상은 어렵다
}
```

무엇을 할지 정하려면 제약이 필요하다. 제약이 전혀 없다면 제네릭이 아니라 `Any`나 구체 타입을 써야 하는 상황일 수 있다.

**② `any`(existential)와 구분한다**

```swift
func request<T: Decodable>(...) -> T          // 제네릭
func request(...) -> any Decodable            // existential
```

| | 제네릭 `<T>` | `any Protocol` |
| --- | --- | --- |
| 타입이 정해지는 시점 | **컴파일 타임** | 런타임 |
| 호출자가 구체 타입을 아나 | **안다** | 모른다 |
| 비용 | 없음 (특수화) | 박싱 |
| 반환값 사용 | `news.articles`처럼 바로 접근 | 캐스팅 필요 |

이 예제가 제네릭이어야 하는 이유가 여기 있다.

```swift
let news = try await request(..., responseType: News.self)
print(news.articles.count)     // News의 프로퍼티에 바로 접근
```

`any Decodable`을 돌려줬다면 `as? News` 캐스팅이 필요했다. [some과 any 비교](./some-keyword-opaque-types.md) 참조.

**③ 제네릭은 오버로드와 다르다**

```swift
func format(_ value: Int) -> String { "\(value)" }
func format(_ value: Double) -> String { String(format: "%.2f", value) }
```

**타입마다 동작이 달라야 한다면 오버로드**가 맞다. 제네릭은 "동작은 같고 타입만 다를 때" 쓴다.

**④ 컴파일 시간과 코드 크기**

Swift는 제네릭 함수를 타입별로 특수화(specialization)해 성능을 확보한다. 그 대신 타입이 많아지면 컴파일 시간과 바이너리 크기가 늘어날 수 있다. 일반적인 앱 규모에서는 걱정할 수준이 아니지만, 제네릭을 깊게 중첩하면 컴파일이 느려지는 것을 체감할 수 있다.

**⑤ 타입 추론이 실패하면 에러 메시지가 불친절하다**

제네릭 관련 컴파일 에러는 원인을 짚기 어려운 경우가 많다. 이럴 때는 **타입을 명시**해 범위를 좁힌다.

```swift
let news: News = try await request(endpoint: "...")   // 명시하면 에러가 명확해진다
```

**⑥ 이름을 의미 있게 짓는다**

`T`, `U`는 관례지만, 역할이 분명하면 이름을 붙이는 편이 읽기 좋다. Swift API Design Guidelines도 이를 권한다.

```swift
func request<Response: Decodable>(...) -> Response      // T보다 명확
struct Cache<Key: Hashable, Value> { ... }
```

### 이 예제의 제네릭이 잘 만들어진 이유

```swift
func request<T: Decodable>(
    endpoint: String,
    method: HTTPMethod = .get,
    parameters: [String: Any]? = nil,
    headers: [String: String]? = nil,
    responseType: T.Type
) async throws -> T
```

- **제약이 최소한이다.** `Decodable`만 요구한다. `Codable`을 요구하면 인코딩이 필요 없는 타입까지 배제된다
- **기본값이 있어 호출이 간결하다.** `method`, `parameters`, `headers`를 생략할 수 있다
- **`responseType:`으로 추론을 확정한다.** 반환 타입만으로는 추론이 안 되는 문제를 해결
- **로직이 타입과 무관하다.** URL 생성, 헤더, 상태 코드 확인이 모든 타입에 공통

**아쉬운 점 하나**는 `parameters: [String: Any]?`의 `Any`다. 타입 안전성이 없어 잘못된 값을 넣어도 컴파일에서 잡히지 않고, `JSONSerialization`이 런타임에 실패한다. `Encodable`을 받는 편이 안전하다.

```swift
func request<Request: Encodable, Response: Decodable>(
    endpoint: String,
    method: HTTPMethod = .get,
    body: Request? = nil,
    responseType: Response.Type
) async throws -> Response
```

다만 `body`가 없는 경우를 다루기가 번거로워져, 실무에서는 오버로드로 나누거나 `Never`를 활용하는 등 여러 방식이 쓰인다.

### 정리

```text
선언   func request<T: Decodable>(...) -> T
                    ↑  ↑
              타입 파라미터  제약 (거의 항상 필요)

사용   대부분 타입 추론
       반환 타입만 제네릭이면 추론 불가
         → 타입 어노테이션 또는 responseType: T.Type

제네릭 타입   struct Stack<Element>
              Array, Dictionary, Optional이 모두 이것

주의   제약 없는 <T>는 대개 설계 문제
       any Protocol과 구분 (컴파일 타임 vs 런타임)
       동작이 타입마다 다르면 오버로드
       이름을 의미 있게
```

## 학습 체크리스트

- [ ] `T: Decodable`에서 `: Decodable`을 지우고 `decode(T.self, ...)`가 실패하는 것을 확인한다.
- [ ] `responseType:` 파라미터를 지우고 타입 어노테이션으로 호출해 본다.
- [ ] `responseType: T.Type = T.self`로 기본값을 주고 생략 가능한지 시험한다.
- [ ] `T`를 `Response`로 이름을 바꿔 가독성을 비교한다.
- [ ] `Stack<Element>` 제네릭 구조체를 직접 만들어 본다.
- [ ] `extension Stack where Element: Equatable`로 조건부 확장을 추가한다.
- [ ] `Array<Article>`과 `[Article]`이 같은 타입임을 확인한다.
- [ ] `APIResponse<News>` 같은 래퍼 타입을 만들어 디코딩해 본다.
- [ ] `where` 절로 두 컬렉션의 `Element`가 같음을 요구하는 함수를 작성한다.
- [ ] `func request(...) -> any Decodable`로 바꿔 보고 호출부에서 캐스팅이 필요해지는 것을 확인한다.
- [ ] `swapTwoValues<T>`를 직접 작성해 `Int`와 `String`에 모두 써 본다.
- [ ] `parameters: [String: Any]?`에 잘못된 값을 넣어 런타임에 실패하는 것을 확인한다.
- [ ] 제약을 `Codable`로 바꿔 보고 `Decodable`만 채택한 타입이 거부되는지 확인한다.
- [ ] 제네릭 타입 추론이 실패하는 상황을 만들어 에러 메시지를 읽는다.

## 공식 참고 자료

- [Swift 공식 문서: Generics](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [Swift 공식 문서: Generics — Type Constraints](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Type-Constraints)
- [Swift 공식 문서: Generics — Generic Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Generic-Types)
- [Swift 공식 문서: Generics — Extending a Generic Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Extending-a-Generic-Type)
- [Swift 공식 문서: Generics — Generic Where Clauses](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Generic-Where-Clauses)
- [Swift 공식 문서: Generics — Associated Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/#Associated-Types)
- [Swift 공식 문서: Opaque and Boxed Protocol Types](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/opaquetypes/)
- [Apple: Decodable](https://developer.apple.com/documentation/swift/decodable)
- [Apple: JSONDecoder.decode(_:from:)](https://developer.apple.com/documentation/foundation/jsondecoder/decode(_:from:))
- [Apple: Array](https://developer.apple.com/documentation/swift/array)
- [Apple: Dictionary](https://developer.apple.com/documentation/swift/dictionary)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
