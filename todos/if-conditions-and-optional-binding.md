# `if`의 조건 결합과 옵셔널 바인딩 — `,`는 왜 AND인가

`guard`의 조기 탈출은 [별도 문서](./guard-keyword.md)에 정리했다. 이 문서는 **`if` 조건의 다양한 형태**와 **바인딩된 변수의 스코프**를 다룬다.

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
if let parameters = parameters, method != .get {
    request.httpBody = try JSONSerialization.data(...)
}
```

```swift
if let httpResponse = response as? HTTPURLResponse,
    !(200...299).contains(httpResponse.statusCode)
{
    throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
}
```

## 1부 — `,`는 AND이고, OR은 왜 안 되는가

### `,`가 AND인 이유

옵셔널 바인딩과 조건을 함께 쓸 때는 `&&`가 아니라 `,`를 쓴다.

```swift
if let parameters = parameters, method != .get { ... }
//                            ↑
//                        AND의 의미
```

**`&&`를 쓸 수 없는 이유**가 있다.

```swift
if let parameters = parameters && method != .get { ... }   // ❌
```

`let parameters = parameters`는 **값을 돌려주는 표현식이 아니다.** `Bool`이 아니므로 `&&`의 좌변이 될 수 없다. 옵셔널 바인딩은 "값이 있으면 꺼내서 이름을 붙이고 참으로 취급"하는 **특수한 조건 형태**다.

그래서 Swift는 `,`로 조건을 나열하는 문법을 따로 두었다. 각 항목은 **순서대로 평가되고 모두 통과해야** 본문이 실행된다.

**중요한 성질: 앞의 바인딩을 뒤 조건에서 쓸 수 있다.**

```swift
if let httpResponse = response as? HTTPURLResponse,
   !(200...299).contains(httpResponse.statusCode) {
//                       ↑
//              앞에서 바인딩한 값을 여기서 쓴다
}
```

이것이 `,`의 핵심 가치다. `&&`로는 불가능하다. 왼쪽에서 만든 이름을 오른쪽에서 참조하려면 순차 평가가 보장되어야 하고, `,`가 그것을 보장한다.

### 그래서 OR은 어떻게 쓰나

**바인딩이 섞이지 않은 순수 `Bool` 조건이라면 `||`를 그대로 쓴다.**

```swift
if method == .post || method == .put { ... }
if code < 200 || code >= 300 { ... }
```

**`,`와 `||`를 섞을 수도 있다.** 각 `,` 항목 안에서는 `&&`, `||`가 자유롭다.

```swift
if let response = response as? HTTPURLResponse,
   response.statusCode == 401 || response.statusCode == 403 {
    // 인증 오류
}
```

`,`가 AND, 그 안의 `||`가 OR이므로 `response가 있고 AND (401 OR 403)`이 된다.

**진짜 제약은 이것이다 — 바인딩 자체를 OR로 묶을 수 없다.**

```swift
if let a = optionalA || let b = optionalB { ... }    // ❌ 불가능
```

당연한 제약이다. `a`가 바인딩됐는지 `b`가 됐는지 모르는 상태로 본문에 들어가면 어느 이름을 쓸 수 있는지 알 수 없다.

**대안**이 몇 가지 있다.

```swift
// ① nil 합병 연산자
if let value = optionalA ?? optionalB { ... }

// ② 미리 계산
let hasEither = optionalA != nil || optionalB != nil
if hasEither { ... }

// ③ switch로 조합 처리
switch (optionalA, optionalB) {
case (.some(let a), _):        use(a)
case (_, .some(let b)):        use(b)
case (nil, nil):               handleNeither()
}
```

### 다양한 조건 형태 정리

`if`가 받을 수 있는 조건은 생각보다 다양하다.

**① 불리언 조건**

```swift
if isEnabled { }
if count > 0 && count < 100 { }
if !items.isEmpty { }
```

**② 옵셔널 바인딩**

```swift
if let value = optional { }
if var value = optional { value += 1 }        // var로도 가능
```

**③ 축약 바인딩 (Swift 5.7+)**

이름이 같으면 우변을 생략할 수 있다.

```swift
if let parameters { }              // if let parameters = parameters
```

예제의 이 줄은 축약형으로 바꿀 수 있다.

```swift
if let parameters = parameters, method != .get { }   // 현재
if let parameters, method != .get { }                 // 축약
```

같은 파일의 다른 곳에서는 이미 축약형을 쓴다.

```swift
guard let url = URL(string: endpoint) else { }   // 이름이 다르므로 축약 불가
```

**④ 조건부 캐스팅 — 예제가 쓰는 것**

```swift
if let httpResponse = response as? HTTPURLResponse { }
```

`as?`는 캐스팅에 실패하면 `nil`을 돌려주므로 옵셔널 바인딩과 결합된다.

`URLSession.data(for:)`가 돌려주는 `response`는 `URLResponse` 타입이고, 상태 코드는 그 하위 타입인 `HTTPURLResponse`에만 있다. 그래서 캐스팅이 필요하다.

값이 필요 없다면 `is`로 타입만 확인할 수도 있다.

```swift
if response is HTTPURLResponse { }
```

**⑤ 패턴 매칭 — `case`**

```swift
if case .success(let value) = result { }
if case .requestFailed(let code) = error, code == 404 { }
```

열거형의 특정 case만 확인할 때 쓴다. [연관값](./enum-raw-values.md)을 꺼낼 수 있다.

**⑥ 범위 확인**

```swift
if (200...299).contains(code) { }
if 200 <= code && code < 300 { }
if case 200...299 = code { }          // 패턴 매칭 방식
```

예제는 첫 번째 방식을 부정으로 쓴다.

```swift
!(200...299).contains(httpResponse.statusCode)
```

**⑦ `where` 절과 조합**

```swift
if let user, user.age >= 18 { }
```

`if`에서는 `,`를 쓰고, `for`나 `switch`에서는 `where`를 쓴다.

```swift
for article in articles where article.author != nil { }

switch error {
case .requestFailed(let code) where code >= 500:
    print("서버 오류")
default:
    break
}
```

**⑧ `if`를 표현식으로 — Swift 5.9+**

```swift
let label = if code < 300 { "성공" } else { "실패" }
```

값을 돌려주는 `if`다. `switch`도 같은 방식으로 쓸 수 있다. 이 문법은 [enum raw value 문서](./enum-raw-values.md)의 `displayName` 예제에서도 활용했다.

### 줄바꿈과 중괄호 위치

예제의 두 번째 `if`가 독특한 형태다.

```swift
if let httpResponse = response as? HTTPURLResponse,
    !(200...299).contains(httpResponse.statusCode)
{
    throw NetworkError.requestFailed(...)
}
```

**중괄호가 다음 줄에 있다.** 조건이 여러 줄일 때 Xcode의 자동 포맷이 이렇게 만든다. 조건과 본문의 경계가 눈에 잘 보이는 장점이 있다.

한 줄이면 붙여 쓴다.

```swift
if let parameters = parameters, method != .get {
```

**문법적으로 둘 다 유효하다.** 스타일 문제다.

## 2부 — 바인딩된 변수의 스코프

### 질문 확인: 스코프는 어디까지인가

**`if` 본문(중괄호 안)까지다.** 밖에서는 쓸 수 없다.

```swift
if let httpResponse = response as? HTTPURLResponse {
    print(httpResponse.statusCode)      // ✅ 사용 가능
}
print(httpResponse.statusCode)          // ❌ 컴파일 에러 — 여기선 없다
```

Swift 공식 문서의 설명이다.

> You use optional binding to find out whether an optional contains a value, and if so, **to make that value available as a temporary constant or variable.**

**`temporary`(임시)** 라는 표현이 스코프를 말해 준다.

**`guard`와의 결정적 차이가 여기 있다.**

```swift
// if let — 중괄호 안에서만
if let url = URL(string: endpoint) {
    // url 사용 가능
}
// 여기서는 못 씀

// guard let — 이후 스코프 전체
guard let url = URL(string: endpoint) else { return }
// 함수 끝까지 url 사용 가능
```

[`guard` 문서](./guard-keyword.md)에서 이 차이를 자세히 다뤘다. 예제도 두 상황에서 각각 적절한 것을 쓰고 있다.

```swift
guard let url = URL(string: endpoint) else {   // url을 이후에 계속 써야 한다
    throw NetworkError.invalidURL
}
var request = URLRequest(url: url)             // 여기서 쓴다
```

```swift
if let parameters = parameters, method != .get {   // 이 블록 안에서만 필요
    request.httpBody = try JSONSerialization.data(withJSONObject: parameters, ...)
}
```

### 그늘짐(shadowing) — 같은 이름을 쓰는 경우

예제에서 눈여겨볼 부분이다.

```swift
if let parameters = parameters, method != .get {
//     ↑            ↑
//  새 상수      원래 옵셔널 파라미터
```

**이름이 같지만 다른 변수다.**

- 우변 `parameters` — 함수 파라미터, 타입은 `[String: Any]?`
- 좌변 `parameters` — 새로 만든 상수, 타입은 `[String: Any]` (옵셔널이 아니다)

블록 안에서 `parameters`를 쓰면 **새로 만든 비옵셔널 상수**를 가리킨다. 원래 옵셔널은 가려진다(shadowed).

**이것이 Swift의 관용적 패턴이다.** 이름을 새로 짓지 않아도 되고, 블록 안에서는 항상 안전한 값만 보인다.

```swift
// 이름을 다르게 지으면 오히려 헷갈린다
if let unwrappedParameters = parameters { ... }
```

Swift 5.7의 축약 문법이 이 패턴을 공식화한 것이다.

```swift
if let parameters { ... }      // 같은 이름 그늘짐을 문법으로 지원
```

### 질문 확인: 순차 평가와 단축 평가

> 아래 조건은 `httpResponse` 객체가 있는 경우에만 다음 `statusCode` 확인하는 부분이 진행되는거지?

**정확하다.** `,`로 나열된 조건은 **순서대로 평가되고, 하나가 실패하면 그 뒤는 평가되지 않는다.**

```swift
if let httpResponse = response as? HTTPURLResponse,   // ① 먼저 평가
   !(200...299).contains(httpResponse.statusCode)     // ② ①이 성공했을 때만
{
```

`response`가 `HTTPURLResponse`가 아니면 ①에서 멈추고 ②는 실행되지 않는다. 그래야 안전하다 — ②가 `httpResponse`를 참조하는데 바인딩이 실패했다면 존재하지 않는 값을 쓰게 되기 때문이다.

이 동작을 **단축 평가(short-circuit evaluation)** 라 부르고, `&&`나 `||`도 같은 성질을 갖는다.

```swift
if array.count > 0 && array[0] == 1 { }    // count가 0이면 array[0]을 평가하지 않는다
```

### 이 코드의 논리를 읽어 보면

```swift
if let httpResponse = response as? HTTPURLResponse,
   !(200...299).contains(httpResponse.statusCode) {
    throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
}
```

**"HTTP 응답이고, 상태 코드가 2xx가 아니면 에러를 던진다"** 는 뜻이다.

여기서 한 가지 짚어볼 점이 있다. **`response`가 `HTTPURLResponse`가 아니면 이 검사를 그냥 통과한다.** HTTP 요청이므로 실무에서는 항상 `HTTPURLResponse`가 오지만, 논리적으로는 "응답 타입을 확인할 수 없는 경우"가 검증 없이 넘어간다.

더 엄격하게 하려면 `guard`로 뒤집는 방법이 있다.

```swift
guard let httpResponse = response as? HTTPURLResponse else {
    throw NetworkError.unknownError        // 예상치 못한 응답 타입
}
guard (200...299).contains(httpResponse.statusCode) else {
    throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
}
```

**부정(`!`)이 사라져 읽기 쉬워지는 것도 이점이다.** `guard`는 "이 조건이 참이어야 계속 진행"이므로 성공 조건을 그대로 쓴다. `if`에 부정을 넣는 것보다 의도가 명확하다.

앞서 만들어 둔 `unknownError` case가 여기서 쓸 자리를 찾는다. [커스텀 에러 문서](./async-throws-and-custom-errors.md)에서 "던지는 곳이 없다"고 지적한 그 case다.

### 정리

```text
,는 AND
  옵셔널 바인딩은 Bool 표현식이 아니라 &&를 쓸 수 없다
  순차 평가되므로 앞의 바인딩을 뒤 조건에서 쓸 수 있다  ← 핵심 가치

OR
  순수 Bool 조건이면 || 그대로
  , 항목 안에서 || 사용 가능
  바인딩 자체를 OR로 묶는 것은 불가 → ?? 나 switch로 대체

스코프
  if let  → 중괄호 안까지 (임시)
  guard let → 이후 스코프 전체
  같은 이름으로 그늘짐이 관용적 패턴

단축 평가
  앞 조건이 실패하면 뒤는 평가되지 않는다
  그래서 뒤 조건에서 앞의 바인딩을 안전하게 쓸 수 있다
```

## 학습 체크리스트

- [ ] `if let parameters = parameters && method != .get`으로 바꿔 에러 메시지를 읽는다.
- [ ] `if let parameters, method != .get`으로 축약 문법을 써 본다.
- [ ] `if` 블록 밖에서 `httpResponse`를 참조해 컴파일 에러를 확인한다.
- [ ] `if let` 안의 `parameters` 타입을 확인해 옵셔널이 아닌 것을 본다.
- [ ] 두 조건에 각각 `print`를 넣어 단축 평가를 관찰한다 (첫 조건 실패 시 두 번째 미실행).
- [ ] `if let a = x || let b = y`를 시도해 불가능한 것을 확인한다.
- [ ] `if let value = optionalA ?? optionalB`로 OR 대안을 구현한다.
- [ ] `,` 항목 안에서 `||`를 써서 401 또는 403을 잡는 조건을 만든다.
- [ ] 상태 코드 검사를 `guard` 두 개로 뒤집어 부정이 사라지는 것을 확인한다.
- [ ] `response`가 `HTTPURLResponse`가 아닌 경우가 검증 없이 통과하는 것을 확인한다.
- [ ] `if case .requestFailed(let code) = error`로 패턴 매칭을 써 본다.
- [ ] `if case 200...299 = code`로 범위 패턴 매칭을 시험한다.
- [ ] `for article in articles where ...`로 `where` 절을 써 본다.
- [ ] `let label = if code < 300 { "성공" } else { "실패" }`로 `if` 표현식을 써 본다.
- [ ] `if var value = optional`로 변수 바인딩을 만들어 값을 수정해 본다.

## 공식 참고 자료

- [Swift 공식 문서: The Basics — Optional Binding](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optional-Binding)
- [Swift 공식 문서: The Basics — Optionals](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals)
- [Swift 공식 문서: Control Flow](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/)
- [Swift 공식 문서: Control Flow — Conditional Statements](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/#Conditional-Statements)
- [Swift 공식 문서: Control Flow — Early Exit](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/#Early-Exit)
- [Swift 공식 문서: Statements — If Statement](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#If-Statement)
- [Swift 공식 문서: Patterns](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/patterns/)
- [Swift 공식 문서: Type Casting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/typecasting/)
- [Swift 공식 문서: Basic Operators — Logical Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/basicoperators/#Logical-Operators)
- [Swift Evolution SE-0345: if let shorthand for shadowing an existing optional variable](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0345-if-let-shorthand.md)
- [Swift Evolution SE-0380: if and switch expressions](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0380-if-switch-expressions.md)
- [Apple: HTTPURLResponse](https://developer.apple.com/documentation/foundation/httpurlresponse)
