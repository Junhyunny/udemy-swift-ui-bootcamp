# `async throws`와 커스텀 에러 — `enum`을 던질 수 있는가

`try`/`try?`/`do-catch`의 선택 기준은 [별도 문서](./swift-error-handling-forms.md)에, `async/await` 실행 모델은 [여기](./swift-async-await-model.md)에 정리했다. 이 문서는 **`async`와 `throws`의 조합**과 **에러 타입 만들기**를 다룬다.

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
func request<T: Decodable>(...) async throws -> T {
    guard let url = URL(string: endpoint) else {
        throw NetworkError.invalidURL
    }
    // ...
}
```

```swift
enum NetworkError: Error {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingError
    case unknownError
}
```

## 1부 — `async throws`

### 두 키워드는 각각 다른 것을 뜻한다

같이 붙어 있지만 의미가 독립적이다.

| 키워드 | 뜻 | 호출 시 |
| --- | --- | --- |
| `async` | **중간에 멈출 수 있다** (suspension point) | `await` 필요 |
| `throws` | **실패할 수 있다** | `try` 필요 |

둘 다 붙으면 호출부에 둘 다 필요하다.

```swift
let (data, response) = try await URLSession.shared.data(for: request)
//                     ↑    ↑
//                 throws  async
```

이 예제의 이 줄이 정확히 그 형태다. `URLSession.data(for:)`가 `async throws`이므로 `try await`을 함께 쓴다.

### 순서가 정해져 있다

```swift
func right() async throws -> Int { ... }     // ✅
func wrong() throws async -> Int { ... }     // ❌
```

컴파일러가 알려 준다.

```
error: 'async' must precede 'throws'
```

선언에서는 **`async` → `throws`** 순서, 호출에서는 **`try` → `await`** 순서다. 반대로 외우기 쉬우니 주의한다.

```swift
try await someFunction()      // ✅
await try someFunction()      // ❌
```

### `await`와 `try`의 역할 대비

Swift 공식 문서가 둘을 나란히 설명한다.

> When calling an asynchronous method, execution suspends until that method returns. You write `await` in front of the call **to mark the possible suspension point.** This is like writing `try` when calling a throwing function, **to mark the possible change to the program's flow if there's an error.**

**둘 다 "여기서 흐름이 달라질 수 있다"는 표시**다.

- `try` — 여기서 에러가 던져져 흐름이 `catch`로 튈 수 있다
- `await` — 여기서 실행이 멈추고 나중에 재개될 수 있다

명시적으로 쓰게 만든 이유가 여기 있다. 코드를 읽는 사람이 **흐름이 바뀔 수 있는 지점**을 눈으로 찾을 수 있다.

`async`의 중요한 성질도 함께 알아 둘 만하다.

> Inside an asynchronous method, the flow of execution can be suspended **only** when you call another asynchronous method — suspension is never implicit or preemptive.

`await`이 없는 곳에서는 절대 멈추지 않는다. [async/await 모델 문서](./swift-async-await-model.md)에서 다룬 내용이다.

### 왜 이 함수가 둘 다 필요한가

```swift
func request<T: Decodable>(...) async throws -> T
```

**`async`가 필요한 이유** — 네트워크 응답을 기다려야 한다.

```swift
let (data, response) = try await URLSession.shared.data(for: request)
```

**`throws`가 필요한 이유** — 실패 경로가 넷이다.

```swift
throw NetworkError.invalidURL              // ① URL이 잘못됨
try JSONSerialization.data(...)            // ② 파라미터 직렬화 실패
try await URLSession.shared.data(...)      // ③ 네트워크 실패
throw NetworkError.requestFailed(...)      // ④ HTTP 상태 코드 오류
throw NetworkError.decodingError           // ⑤ 디코딩 실패
```

**`throws`가 없다면** 이 실패들을 반환값으로 표현해야 한다. `T?`를 돌려주면 "왜 실패했는지"가 사라지고, `Result<T, Error>`를 쓰면 호출부가 매번 분기해야 한다. `throws`는 성공 경로를 깔끔하게 유지하면서 실패를 별도 경로로 뺀다.

### 조합 가능한 네 가지

| 시그니처 | 호출 | 의미 |
| --- | --- | --- |
| `func f()` | `f()` | 동기, 실패 없음 |
| `func f() throws` | `try f()` | 동기, 실패 가능 |
| `func f() async` | `await f()` | 비동기, 실패 없음 |
| `func f() async throws` | `try await f()` | 비동기, 실패 가능 |

이 파일에 세 가지가 다 나온다.

```swift
func request(...) async throws -> T           // async throws
static func fetchNews() async -> News?        // async만 (throws 없음)
```

`fetchNews()`가 `throws`를 쓰지 않는 이유는 내부에서 `do-catch`로 삼키기 때문이다.

```swift
static func fetchNews() async -> News? {
    do {
        let news = try await NetworkingManager.shared.request(...)
        return news
    } catch {}          // ⚠️ 에러를 버린다
    return nil
}
```

**이게 아쉬운 지점이다.** `throws`로 전달하면 호출부가 실패를 알 수 있는데, 지금은 `nil`만 남아 원인을 알 수 없다.

```swift
// 개선안
static func fetchNews() async throws -> News {
    try await NetworkingManager.shared.request(
        endpoint: "...",
        responseType: News.self
    )
}
```

`do-catch`가 사라져 코드도 짧아진다. 오류 처리는 UI를 아는 뷰에서 하는 것이 맞다. [.task 문서](./task-modifier-and-async-lifecycle.md)에 관련 내용이 있다.

### `rethrows` — 참고

클로저를 받는 함수에서 쓰인다.

```swift
func map<T>(_ transform: (Element) throws -> T) rethrows -> [T]
```

"내가 직접 던지진 않지만, 받은 클로저가 던지면 그대로 전달한다"는 뜻이다. 클로저가 던지지 않으면 호출부에 `try`가 필요 없다.

```swift
[1, 2, 3].map { $0 * 2 }              // try 불필요
try [1, 2, 3].map { try parse($0) }   // try 필요
```

## 2부 — 에러 만들기와 던지기

### `enum`을 던질 수 있는가 — 그렇다. 오히려 권장된다

질문의 답이다. Swift 공식 문서가 명시한다.

> In Swift, errors are represented by values of types that conform to the `Error` protocol. This empty protocol indicates that a type can be used for error handling.
>
> **Swift enumerations are particularly well suited to modeling a group of related error conditions**, with associated values allowing for additional information about the nature of an error to be communicated.

문서의 예제 구조가 이 예제와 똑같다.

```swift
enum VendingMachineError: Error {
    case invalidSelection
    case insufficientFunds(coinsNeeded: Int)
    case outOfStock
}
```

```swift
enum NetworkError: Error {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingError
    case unknownError
}
```

**`Error`는 빈 프로토콜이다.** 요구사항이 하나도 없어서 `: Error`만 붙이면 끝난다.

### `enum`이 에러에 적합한 이유

**① 가능한 실패를 전부 나열한다**

`switch`에서 컴파일러가 누락을 잡아 준다.

```swift
catch let error as NetworkError {
    switch error {
    case .invalidURL:              print("URL 오류")
    case .requestFailed(let code): print("HTTP \(code)")
    case .decodingError:           print("파싱 오류")
    case .unknownError:            print("알 수 없음")
    }   // case를 추가하면 여기서 컴파일 에러가 난다
}
```

**② 연관값으로 상세 정보를 싣는다**

```swift
case requestFailed(statusCode: Int)
```

```swift
throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
```

에러 종류와 함께 **어떤 상태 코드였는지**를 전달한다. 이게 `enum` 에러의 핵심 강점이다. [raw value와 연관값 구분](./enum-raw-values.md) 참조.

**③ 값 타입이라 가볍다**

`class`로 만들 이유가 없다. 에러는 정보를 나르는 값이다.

### 에러를 만드는 다른 방법들

**`enum`이 기본이지만 다른 선택지도 있다.**

**① `struct`** — 필드가 많고 조합이 다양할 때

```swift
struct APIError: Error {
    let statusCode: Int
    let message: String
    let endpoint: String
}
```

case로 나누기 어려운 경우에 적합하다. 다만 `switch`로 분기하는 이점은 사라진다.

**② `LocalizedError`** — 사용자에게 보여줄 메시지가 필요할 때

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "주소가 올바르지 않습니다."
        case .requestFailed(let code):
            "요청이 실패했습니다. (오류 \(code))"
        }
    }
}
```

`error.localizedDescription`이 이 문자열을 돌려준다. **`Error`만 채택하면 `localizedDescription`이 개발자용 기본 문자열**이라 사용자에게 보여주기에 부적절하다. 화면에 표시할 에러라면 `LocalizedError`가 맞다.

`recoverySuggestion`, `failureReason`도 함께 제공할 수 있다.

**③ `NSError`** — Objective-C API와 연동할 때. 새 코드에서 직접 만들 일은 드물다.

**④ 표준 에러 활용** — `DecodingError`, `URLError`, `CancellationError`처럼 시스템이 주는 에러를 그대로 전달하는 경우도 많다.

### 던지는 방법

**`throw` 한 줄이다.**

```swift
throw NetworkError.invalidURL
```

**`guard`와 함께 쓰는 것이 관용적이다.**

```swift
guard let url = URL(string: endpoint) else {
    throw NetworkError.invalidURL
}
```

[`guard` 문서](./guard-keyword.md)에서 다룬 대로 `else`에서 탈출해야 하고, `throw`가 그 수단 중 하나다.

**조건 검사 후 던지기**

```swift
if let httpResponse = response as? HTTPURLResponse,
   !(200...299).contains(httpResponse.statusCode) {
    throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
}
```

**에러를 변환해 던지기**

```swift
do {
    return try JSONDecoder().decode(T.self, from: data)
} catch {
    throw NetworkError.decodingError
}
```

이 예제가 쓰는 방식이다. `DecodingError`를 `NetworkError`로 바꿔 던진다.

**의도는 좋지만 원인 정보가 사라진다.** `DecodingError`는 "어느 키가 없는지", "어떤 타입이 안 맞는지"를 상세히 담고 있는데 버려진다.

**개선안 — 원래 에러를 연관값으로 실어 보낸다.**

```swift
enum NetworkError: Error {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingFailed(underlying: Error)      // ← 원인 보존
    case unknownError
}
```

```swift
do {
    return try JSONDecoder().decode(T.self, from: data)
} catch {
    throw NetworkError.decodingFailed(underlying: error)
}
```

이러면 디버깅 때 원인을 추적할 수 있다.

```swift
catch NetworkError.decodingFailed(let underlying) {
    print("디코딩 실패:", underlying)      // DecodingError의 상세 정보
}
```

[Codable 문서](./codable-and-codingkey.md)에서 `DecodingError`의 종류를 다뤘다.

### 잡는 방법 — 패턴 매칭

`catch`는 패턴을 받는다. 여러 방식이 있다.

```swift
do {
    let news = try await request(...)
} catch NetworkError.invalidURL {
    // 특정 case만
} catch NetworkError.requestFailed(let code) where code == 401 {
    // 연관값 + 조건
} catch let error as NetworkError {
    // 타입으로 잡고 switch로 분기
    switch error { ... }
} catch is CancellationError {
    // 취소는 무시
} catch {
    // 나머지 전부 — error 상수가 암시적으로 제공된다
    print(error)
}
```

**순서가 중요하다.** 위에서부터 매칭되므로 구체적인 것을 먼저 쓴다. 마지막의 인자 없는 `catch`가 없으면 `throws` 함수 안이 아닌 경우 컴파일 에러다.

### 이 예제의 `unknownError`에 대해

```swift
enum NetworkError: Error {
    case invalidURL
    case requestFailed(statusCode: Int)
    case decodingError
    case unknownError          // ← 어디서도 던지지 않는다
}
```

`unknownError`는 선언만 되어 있고 실제로 던지는 곳이 없다. "혹시 모를 경우"를 위한 case인데, 실무에서는 이런 case가 **`switch`에서 처리해야 할 죽은 분기**로 남는 경우가 많다.

정말 필요하다면 원인을 실어 두는 편이 낫다.

```swift
case unknown(underlying: Error)
```

아니면 지워도 된다. `catch`의 마지막 절이 그 역할을 이미 한다.

### 정리

```text
async throws
  async  = 멈출 수 있다  → await
  throws = 실패할 수 있다 → try
  선언: async → throws / 호출: try → await

에러 만들기
  Error는 빈 프로토콜 — : Error만 붙이면 된다
  enum이 가장 적합 (나열 + 연관값 + switch 검증)
  사용자에게 보여줄 메시지가 필요하면 LocalizedError

던지고 잡기
  throw ErrorType.case
  guard ... else { throw ... }  ← 관용적
  catch는 패턴 매칭 — 구체적인 것을 먼저

주의
  에러를 변환할 때 원인을 버리지 않는다
    → case decodingFailed(underlying: Error)
  catch {}로 삼키지 않는다
```

## 학습 체크리스트

- [ ] `func f() throws async`로 순서를 바꿔 컴파일 에러 메시지를 읽는다.
- [ ] `await try`로 순서를 바꿔 에러를 확인한다.
- [ ] `throws`를 지우고 `throw` 문에서 어떤 에러가 나는지 본다.
- [ ] `async`를 지우고 `try await` 줄에서 어떤 에러가 나는지 본다.
- [ ] `fetchNews()`를 `async throws -> News`로 바꾸고 뷰에서 `do-catch`로 처리한다.
- [ ] `catch {}`에 `print(error)`를 넣어 실제로 어떤 에러가 오는지 확인한다.
- [ ] 잘못된 URL을 넣어 `NetworkError.invalidURL`이 던져지는지 확인한다.
- [ ] 잘못된 API 키로 401을 받아 `requestFailed(statusCode: 401)`을 확인한다.
- [ ] `catch NetworkError.requestFailed(let code)`로 상태 코드를 꺼내 출력한다.
- [ ] `where code == 401` 조건을 붙인 `catch`를 작성한다.
- [ ] `case decodingFailed(underlying: Error)`로 바꿔 원인을 보존해 본다.
- [ ] `NetworkError`를 `LocalizedError`로 바꾸고 `localizedDescription`을 출력한다.
- [ ] `Error`만 채택했을 때와 `LocalizedError`일 때의 메시지를 비교한다.
- [ ] `catch` 절의 순서를 바꿔 구체적인 것이 뒤에 오면 도달하지 않는 것을 확인한다.
- [ ] `unknownError` case를 지우고 컴파일이 되는지 확인한다.

## 공식 참고 자료

- [Swift 공식 문서: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [Swift 공식 문서: Error Handling — Representing and Throwing Errors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/#Representing-and-Throwing-Errors)
- [Swift 공식 문서: Error Handling — Handling Errors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/#Handling-Errors)
- [Swift 공식 문서: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift 공식 문서: Concurrency — Defining and Calling Asynchronous Functions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Defining-and-Calling-Asynchronous-Functions)
- [Swift 공식 문서: Declarations — Rethrowing Functions and Methods](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/#Rethrowing-Functions-and-Methods)
- [Apple: Error](https://developer.apple.com/documentation/swift/error)
- [Apple: LocalizedError](https://developer.apple.com/documentation/foundation/localizederror)
- [Apple: DecodingError](https://developer.apple.com/documentation/swift/decodingerror)
- [Apple: URLError](https://developer.apple.com/documentation/foundation/urlerror)
- [Apple: CancellationError](https://developer.apple.com/documentation/swift/cancellationerror)
- [Apple: Result](https://developer.apple.com/documentation/swift/result)
