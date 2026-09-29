# 조건문 총정리 — `if` / `guard` / `while`의 모든 형태

`if`, `guard`, `while`은 **같은 "조건절(condition list)" 문법**을 공유한다. 하나를 익히면 나머지가 전부 따라오므로 한 문서에 모았다. 이전에 `if` 조건과 `guard`로 나뉘어 있던 두 문서를 여기로 합쳤다.

옆 문서들과의 경계는 이렇다.

| 문서 | 다루는 축 |
| --- | --- |
| **이 문서** | 조건절에 무엇이 올 수 있는가, 스코프, `if`/`guard` 선택 |
| [옵셔널 총정리](./141-optional-complete-guide.md) | 옵셔널 자체 — `??`, 체이닝, `map`, 강제 언래핑 |
| [패턴 매칭 총정리](./157-pattern-matching-complete-guide.md) | `case` 패턴의 종류와 `switch`/`for case` |
| [`Type!`](./005-implicitly-unwrapped-optional.md) | 암시적 언래핑 옵셔널 |

이 문서의 컴파일 판정은 **Apple Swift 6.4**로 직접 확인했다.

## 질문이 나온 코드

외부 프로젝트 `voip-ios` — 조건에 `await`이 들어간 형태.

```swift
guard await buffer.accept(candidate: iceCandidate) else { return }
```

`chapter-61/chapter-61/ContentView.swift` — `,`로 조건을 잇는 형태.

```swift
if let parameters = parameters, method != .get {
    request.httpBody = try JSONSerialization.data(...)
}

if let httpResponse = response as? HTTPURLResponse,
    !(200...299).contains(httpResponse.statusCode)
{
    throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
}
```

`chapter-50/chapter-50/ContentView.swift` — `guard`로 조기 탈출.

```swift
guard let detector = try? NSDataDetector(types: types.rawValue) else {
    return nil
}
```

`chapter-88/chapter-88/WebView.swift` — 축약 바인딩.

```swift
guard let urlString, let url = URL(string: urlString) else { return }
```

## 1부 — 조건절에 올 수 있는 것 전부

`if`, `guard`, `while` 모두 아래를 똑같이 받는다.

### ① 불리언 조건

```swift
if isEnabled { }
if count > 0 && count < 100 { }
guard !text.isEmpty else { return nil }
guard index < array.count else { return }
```

### ② 옵셔널 바인딩

```swift
if let value = optional { }
if var value = optional { value += 1 }        // var 로도 가능
guard let detector = try? NSDataDetector(types: 0) else { return nil }
```

**옵셔널 바인딩은 `Bool` 표현식이 아니다.** 이것이 뒤에 나올 `,` 문법의 이유가 된다.

### ③ 축약 바인딩 (Swift 5.7+, SE-0345)

이름이 같으면 우변을 생략한다.

```swift
if let parameters { }                 // if let parameters = parameters
guard let urlString else { return }   // guard let urlString = urlString
```

`chapter-88`의 코드가 정확히 이것이다. 여기서 **`urlString`은 두 개가 존재한다.**

| | 타입 | 정체 |
| --- | --- | --- |
| `self.urlString` | `String?` | 멤버 프로퍼티 |
| `urlString` (guard 이후) | **`String`** | 새로 만든 비옵셔널 상수 |

```swift
guard let urlString              // 축약형
guard let urlString = urlString  // 원래 형태 — 완전히 같다
//        ↑ 새 상수      ↑ self.urlString (옵셔널)
```

그래서 다음 줄의 `URL(string: urlString)`에 **옵셔널이 아닌 값**이 들어간다.

축약형이 없던 시절에는 이름을 다르게 지어야 했다.

```swift
guard let unwrappedURLString = urlString else { return }   // Swift 5.7 이전 관례
guard let urlString = self.urlString else { return }       // self. 로 구분
```

**주의** — 축약형은 **이름이 같을 때만** 쓸 수 있다.

```swift
guard let urlString, let url = URL(string: urlString) else { return }
//        ↑ 이름이 같아 축약      ↑ URL(string:) 의 결과라 이름을 명시
```

`self`를 축약할 때는 목적이 조금 다르다. `weak self`를 강한 참조로 승격하는 관용구다([`[weak self]`와 `deinit`](./023-weak-self-and-deinit.md)).

```swift
guard let self else { return }
```

### ④ 조건부 캐스팅 — `as?` / `is`

```swift
if let httpResponse = response as? HTTPURLResponse { }
if response is HTTPURLResponse { }                      // 값이 필요 없으면
```

`as?`는 실패하면 `nil`을 돌려주므로 옵셔널 바인딩과 자연스럽게 결합된다. `URLSession.data(for:)`가 돌려주는 `response`는 `URLResponse`이고 상태 코드는 하위 타입인 `HTTPURLResponse`에만 있어 캐스팅이 필요하다. 자세한 것은 [Swift의 형변환](./021-swift-type-casting.md)에 있다.

### ⑤ `case` 패턴 매칭

```swift
if case .success(let value) = result { }
guard case .success(let value) = result else { return }
if case .requestFailed(let code) = error, code == 404 { }
while case .some(.ice(let s)) = it.next() { }
```

패턴의 종류(옵셔널 패턴, 타입 캐스팅 패턴, 튜플, `~=`)는 [패턴 매칭 총정리](./157-pattern-matching-complete-guide.md)에 전부 정리했다.

### ⑥ 범위 확인

```swift
if (200...299).contains(code) { }
if 200 <= code && code < 300 { }
if case 200...299 = code { }          // 패턴 매칭 방식
```

### ⑦ `await` / `try` — 이번 질문

**조건절 안에서도 `await`과 `try`를 그대로 쓴다.** 특별한 문법이 아니라, 조건이 표현식이니 표현식에 붙는 키워드가 그대로 붙는 것이다.

```swift
// 비동기 Bool 조건 — 질문의 코드
guard await buffer.accept(candidate: iceCandidate) else { return }

// 비동기 옵셔널 바인딩
guard let n = await buffer.find(ice) else { return }

// 던지기까지 하면
guard let m = try await mayThrow() else { return }

// if 와 while 도 동일
if await buffer.accept(candidate: ice) { }
if let k = await buffer.find(ice), k > 0 { }
while await buffer.accept(candidate: ice) { break }
```

여러 조건에 `await`이 각각 붙어도 된다. **`,`는 순차 평가이므로 앞 조건이 실패하면 뒤의 `await`은 아예 실행되지 않는다.**

```swift
guard await buffer.accept(candidate: ice),
      let v = await buffer.find(ice),
      v > 0
else { return }
```

`await`이 붙는 자리를 헷갈린다면 [`for await` 문서](./105-for-await-async-sequence.md)의 "`await`은 무엇에 붙는가" 절과 같은 원리다. **`guard`/`if`의 `await`은 언제나 "표현식에 붙는 `await`"** 이고, `for await`처럼 루프 문법의 일부가 되는 경우는 없다.

### ⑧ 여러 조건을 `,`로

```swift
guard let url = URL(string: input),
      let host = url.host,
      !host.isEmpty else {
    return nil
}
```

## 2부 — `,`는 AND이고, OR은 왜 안 되는가

### `,`가 AND인 이유

옵셔널 바인딩과 조건을 함께 쓸 때는 `&&`가 아니라 `,`를 쓴다.

```swift
if let parameters = parameters, method != .get { ... }
//                            ↑ AND 의 의미
```

`&&`를 쓸 수 없는 이유가 분명히 있다.

```swift
if let x = x && x > 0 { }
// ❌ optional type 'Int?' cannot be used as a boolean; test for '!= nil' instead
```

`let x = x`는 **값을 돌려주는 표현식이 아니다.** `Bool`이 아니므로 `&&`의 좌변이 될 수 없다. 옵셔널 바인딩은 "값이 있으면 꺼내 이름을 붙이고 참으로 취급"하는 **특수한 조건 형태**다.

그래서 Swift는 `,`로 조건을 나열하는 문법을 따로 두었다. 각 항목은 **순서대로 평가되고 모두 통과해야** 본문이 실행된다.

**핵심 가치 — 앞의 바인딩을 뒤 조건에서 쓸 수 있다.**

```swift
if let httpResponse = response as? HTTPURLResponse,
   !(200...299).contains(httpResponse.statusCode) {
//                       ↑ 앞에서 바인딩한 값을 여기서 쓴다
}
```

`&&`로는 불가능하다. 왼쪽에서 만든 이름을 오른쪽에서 참조하려면 순차 평가가 보장되어야 하고, `,`가 그것을 보장한다.

### 단축 평가(short-circuit evaluation)

`,`로 나열된 조건은 **하나가 실패하면 그 뒤는 평가되지 않는다.**

```swift
if let httpResponse = response as? HTTPURLResponse,   // ① 먼저 평가
   !(200...299).contains(httpResponse.statusCode)     // ② ①이 성공했을 때만
{
```

`response`가 `HTTPURLResponse`가 아니면 ①에서 멈추고 ②는 실행되지 않는다. **그래야 안전하다** — ②가 `httpResponse`를 참조하는데 바인딩이 실패했다면 존재하지 않는 값을 쓰게 된다.

`&&`, `||`도 같은 성질을 갖는다.

```swift
if array.count > 0 && array[0] == 1 { }   // count 가 0 이면 array[0] 을 평가하지 않는다
```

⑦에서 본 대로 **`await`이 붙은 조건에도 그대로 적용된다.** 앞 조건이 실패하면 뒤의 비동기 호출은 일어나지 않는다.

### 그래서 OR은 어떻게 쓰나

**순수 `Bool` 조건이면 `||`를 그대로 쓴다.**

```swift
if method == .post || method == .put { }
if code < 200 || code >= 300 { }
```

**`,`와 `||`를 섞을 수도 있다.** 각 `,` 항목 안에서는 `&&`, `||`가 자유롭다.

```swift
if let response = response as? HTTPURLResponse,
   response.statusCode == 401 || response.statusCode == 403 {
    // response 가 있고 AND (401 OR 403)
}
```

**진짜 제약은 이것이다 — 바인딩 자체를 OR로 묶을 수 없다.**

```swift
if let a = optionalA || let b = optionalB { }
// ❌ expected expression after operator
```

당연한 제약이다. `a`가 바인딩됐는지 `b`가 됐는지 모르는 채로 본문에 들어가면 어느 이름을 쓸 수 있는지 알 수 없다.

**대안**이 몇 가지 있다.

```swift
// ① nil 합병 연산자
if let value = optionalA ?? optionalB { }

// ② 미리 계산
let hasEither = optionalA != nil || optionalB != nil
if hasEither { }

// ③ switch 로 조합 처리
switch (optionalA, optionalB) {
case (.some(let a), _): use(a)
case (_, .some(let b)): use(b)
case (nil, nil):        handleNeither()
}
```

## 3부 — `guard`의 규칙

### 무엇을 하는 문장인가

> A `guard` statement, like an `if` statement, executes statements depending on the Boolean value of an expression. You use a `guard` statement to require that a condition must be true in order for the code after the `guard` statement to be executed. Unlike an `if` statement, a `guard` statement always has an `else` clause — the code inside the `else` clause is executed if the condition isn't true.

핵심은 **"이 조건이 참이어야만 아래 코드가 실행된다"** 는 요구사항 선언이다. `if`와 결정적으로 다른 점이 셋이다.

- **`else` 절이 필수다.**
- **`else` 절은 반드시 스코프를 벗어나야 한다.**
- **옵셔널 바인딩한 값이 `guard` 이후에도 살아 있다.**

세 번째가 실무에서 가장 크게 체감되는 차이다.

### `else`의 의무 — 반드시 탈출해야 한다

> That branch must transfer control to exit the code block in which the `guard` statement appears. It can do this with a control transfer statement such as `return`, `break`, `continue`, or `throw`, or it can call a function or method that doesn't return, such as `fatalError(_:file:line:)`.

| 방법 | 쓰이는 곳 |
| --- | --- |
| `return` | 함수 |
| `break` | 반복문, `switch` |
| `continue` | 반복문 |
| `throw` | 오류를 던지는 함수 |
| `fatalError(...)` | 절대 도달하면 안 되는 경우 |

빠져나가지 않으면 컴파일 에러다. **"조건이 틀렸는데도 계속 진행하는" 실수를 언어가 막아 준다.**

```swift
guard let x = x else { print("없음") }
// ❌ 'guard' body must not fall through, consider using a 'return' or 'throw' to exit the scope

guard let x = x
// ❌ expected 'else' after 'guard' condition
```

`fatalError()`가 허용되는 이유는 반환 타입이 `Never`이기 때문이다. [2단계 초기화 문서](./155-two-phase-initialization-and-super-init.md)에서 `guard ... else { fatalError }`가 `super.init()` 앞에 와도 되는 이유와 같다.

### 바인딩이 이후에도 살아 있다 — 가장 큰 장점

> Any variables or constants that were assigned values using an optional binding as part of the condition are available for the rest of the code block that the `guard` statement appears in.

```swift
// if let — 바인딩한 값이 중괄호 안에서만 유효
func extractA(from text: String) -> URL? {
    if let detector = try? NSDataDetector(types: 0) {
        return detector.matches(...).first?.url
    }
    return nil
}
// detector 는 여기서 못 쓴다

// guard let — 바인딩한 값이 함수 끝까지 유효
func extractB(from text: String) -> URL? {
    guard let detector = try? NSDataDetector(types: 0) else { return nil }
    let matches = detector.matches(...)   // 사용 가능
    return matches.first?.url
}
```

### 중첩이 사라진다

> Using a `guard` statement for requirements improves the readability of your code, compared to doing the same check with an `if` statement. It lets you write the code that's typically executed without wrapping it in an `else` block, and it lets you keep the code that handles a violated requirement next to the requirement.

조건이 여러 개면 차이가 극적이다.

```swift
// if let 중첩 — 오른쪽으로 계속 밀린다 (pyramid of doom)
func process(_ input: String?) -> String? {
    if let input = input {
        if let url = URL(string: input) {
            if let host = url.host {
                return host.uppercased()
            } else { return nil }
        } else { return nil }
    } else { return nil }
}

// guard — 평평하게 유지된다
func process(_ input: String?) -> String? {
    guard let input else { return nil }
    guard let url = URL(string: input) else { return nil }
    guard let host = url.host else { return nil }
    return host.uppercased()
}
```

**정상 경로가 들여쓰기 0단계에 남는다**는 것이 핵심이다. 그리고 `if-else`는 조건과 실패 처리 사이에 정상 코드가 통째로 끼어들지만, `guard`는 "이 조건이 틀리면 이렇게 한다"가 붙어 있어 대응 관계가 즉시 보인다.

### 의도가 드러난다

`guard`는 문법이자 **선언**이다. 읽는 사람에게 "여기서부터 아래는 이 조건이 참이라고 가정한다"고 말한다. `if`는 분기를 뜻하지만 `guard`는 **전제 조건(precondition)** 을 뜻한다. 함수 맨 위에 `guard`들이 모여 있으면 그것이 곧 그 함수의 입력 계약서다.

```swift
func transfer(amount: Decimal, from: Account?, to: Account?) throws {
    guard let from else { throw TransferError.missingSource }
    guard let to else { throw TransferError.missingDestination }
    guard amount > 0 else { throw TransferError.invalidAmount }
    guard from.balance >= amount else { throw TransferError.insufficientFunds }
    // 여기부터는 모든 전제가 충족된 상태
}
```

## 4부 — 스코프와 그늘짐(shadowing)

### 바인딩의 유효 범위

```swift
// if let — 중괄호 안까지 (임시)
if let httpResponse = response as? HTTPURLResponse {
    print(httpResponse.statusCode)      // ✅
}
print(httpResponse.statusCode)          // ❌ 여기선 없다

// guard let — 이후 스코프 전체
guard let url = URL(string: endpoint) else { throw NetworkError.invalidURL }
var request = URLRequest(url: url)      // ✅ 함수 끝까지
```

공식 문서의 표현이 스코프를 말해 준다.

> You use optional binding to find out whether an optional contains a value, and if so, **to make that value available as a temporary constant or variable.**

`chapter-61`의 코드가 두 상황을 적절히 나눠 쓴다. `url`은 이후에 계속 써야 하니 `guard`, `parameters`는 그 블록 안에서만 필요하니 `if let`이다.

### 같은 이름을 쓰는 것이 관용적이다

```swift
if let parameters = parameters, method != .get { }
//     ↑ 새 상수     ↑ 원래 옵셔널 파라미터
```

**이름이 같지만 다른 변수다.** 우변은 `[String: Any]?`, 좌변은 `[String: Any]`(비옵셔널)이다. 블록 안에서 `parameters`를 쓰면 **새로 만든 비옵셔널 상수**를 가리키고 원래 옵셔널은 가려진다(shadowed).

이름을 다르게 지으면 오히려 헷갈린다.

```swift
if let unwrappedParameters = parameters { }   // 장황하다
```

Swift 5.7의 축약 문법(①③)이 이 패턴을 문법으로 공식화한 것이다.

### `!= nil` 검사는 언래핑이 아니다

흔한 오해다. `nil`이 아님을 확인해도 **타입은 여전히 옵셔널**이다.

```swift
guard x != nil else { return }
print(x + 1)
// ❌ value of optional type 'Int?' must be unwrapped to a value of type 'Int'
```

바인딩(`guard let x`)만이 비옵셔널 값을 만든다.

## 5부 — `if`와 `guard`, 어느 쪽을 쓰나

| 상황 | 선택 |
| --- | --- |
| 조건이 틀리면 **더 진행할 수 없다** | `guard` |
| 바인딩한 값을 **이후에도 써야 한다** | `guard` |
| 함수 입구의 **전제 조건 검사** | `guard` |
| 두 갈래가 **둘 다 정상 경로**다 | `if` |
| 조건이 참일 때만 **잠깐 뭘 한다** | `if` |
| 값이 있을 때만 뷰를 그린다 (SwiftUI) | `if let` |

`chapter-50`이 둘을 적절히 나눠 쓴다.

```swift
// guard — detector 가 없으면 함수를 진행할 수 없다
guard let detector = try? NSDataDetector(types: types.rawValue) else { return nil }

// if let — URL 이 있을 때만 Link 를 그리고, 없으면 그냥 안 그린다
if let detectedURL { Link(...) }
```

두 번째는 "없으면 아무것도 안 한다"이지 "탈출한다"가 아니다. 뷰를 나열하는 `@ViewBuilder` 문맥이라 `return`으로 빠져나갈 수도 없다.

#### SwiftUI `body`의 `guard` — "못 쓴다"가 아니라 조건이 붙는다

흔히 "`body`에서는 `guard`를 못 쓴다"고 정리하지만 정확하지 않다. 실제 컴파일 결과는 이렇다.

```swift
// ✅ 모든 경로에 명시적 return + 반환 타입이 같으면 된다
var body: some View {
    guard let name else { return Text("없음") }
    return Text(name)
}

// ❌ @ViewBuilder 가 동작하는 문맥(뷰 나열) 안에서는 불가
var body: some View {
    VStack {
        guard let name else { return }   // 컴파일 실패
        Text(name)
    }
}

// ❌ 반환 타입이 다르면 some View 추론에 실패
var body: some View {
    guard let name else { return EmptyView() }
    return Text(name)
    // error: function declares an opaque return type 'some View',
    //        but the return statements in its body do not have matching underlying types
}
```

정리하면 **명시적 `return`을 쓰는 순간 `@ViewBuilder`가 비활성화된다.** 그래서 `guard`를 쓰려면 모든 분기를 직접 `return`해야 하고 타입도 맞춰야 한다. 조건부 렌더링에서 `if let`이 관용적인 이유가 이것이다 — `@ViewBuilder`가 분기마다 다른 타입을 알아서 감싸 준다.

### `guard`를 뒤집으면 부정이 사라진다

```swift
// if + 부정
if let httpResponse = response as? HTTPURLResponse,
   !(200...299).contains(httpResponse.statusCode) {
    throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
}

// guard 로 뒤집기
guard let httpResponse = response as? HTTPURLResponse else {
    throw NetworkError.unknownError
}
guard (200...299).contains(httpResponse.statusCode) else {
    throw NetworkError.requestFailed(statusCode: httpResponse.statusCode)
}
```

`guard`는 "이 조건이 참이어야 계속 진행"이므로 **성공 조건을 그대로** 쓴다. `if`에 부정을 넣는 것보다 의도가 명확하다.

논리도 달라진다. 위 `if` 버전은 **`response`가 `HTTPURLResponse`가 아니면 검사를 그냥 통과한다.** 실무에서는 HTTP 요청이니 항상 `HTTPURLResponse`가 오지만, 논리적으로는 "응답 타입을 확인할 수 없는 경우"가 검증 없이 넘어간다. `guard` 버전은 그 구멍을 막는다.

### `guard`와 오류 처리의 조합

```swift
guard let detector = try? NSDataDetector(types: types.rawValue) else { return nil }
```

`NSDataDetector(types:)`는 `throws` 이니셜라이저다. `try?`가 오류를 `nil`로 바꾸고 `guard let`이 그 `nil`을 걸러낸다. 오류 내용을 알아야 한다면 `do-catch`가 맞다. 선택 기준은 [Swift의 오류 처리 방식들](./100-swift-error-handling-forms.md)에 있다.

## 6부 — 나머지 형태들

### `while`도 같은 조건절을 쓴다

```swift
while let line = readLine() { }
while case .some(.ice(let s)) = it.next() { }
while await buffer.accept(candidate: ice) { break }
```

### `if`를 표현식으로 (Swift 5.9+, SE-0380)

```swift
let label = if code < 300 { "성공" } else { "실패" }
let y = if let x { x } else { 0 }        // 바인딩도 된다
```

`switch`도 같은 방식으로 쓸 수 있다.

### `where`는 어디에 쓰나

`if`/`guard`에서는 `,`를 쓰고, `for`나 `switch`에서는 `where`를 쓴다.

```swift
if let user, user.age >= 18 { }                     // if 는 쉼표

for article in articles where article.author != nil { }   // for 는 where

switch error {
case .requestFailed(let code) where code >= 500: print("서버 오류")
default: break
}
```

자세한 것은 [`where` 절의 쓰임새](./031-where-clause-usages.md)에 있다.

### 줄바꿈과 중괄호 위치

조건이 여러 줄이면 Xcode 자동 포맷이 중괄호를 다음 줄로 내린다.

```swift
if let httpResponse = response as? HTTPURLResponse,
    !(200...299).contains(httpResponse.statusCode)
{
    throw NetworkError.requestFailed(...)
}
```

**문법적으로 둘 다 유효하다.** 스타일 문제다.

## 7부 — 오류 메시지 대조표 (Swift 6.4 실측)

| 코드 | 메시지 | 원인 |
| --- | --- | --- |
| `guard let x = x` | `expected 'else' after 'guard' condition` | `else` 필수 |
| `guard let x = x else { print(x) }` | `'guard' body must not fall through, consider using a 'return' or 'throw' to exit the scope` | `else`는 반드시 탈출 |
| `if let x = x && x > 0` | `optional type 'Int?' cannot be used as a boolean; test for '!= nil' instead` | 바인딩은 `Bool`이 아니다 → `,` 사용 |
| `if let a = a \|\| let b = b` | `expected expression after operator` | 바인딩을 OR로 묶을 수 없다 |
| `guard x != nil else { return }` 후 `x + 1` | `value of optional type 'Int?' must be unwrapped to a value of type 'Int'` | `nil` 검사는 언래핑이 아니다 |

## 8부 — 다른 언어와 비교

| 언어 | 대응 개념 |
| --- | --- |
| Java/Kotlin | early return (`if (x == null) return;`) — 언어 강제는 없음 |
| Kotlin | `?:` 엘비스 + `return` |
| Rust | `let ... else`, `?` 연산자 |
| Go | `if err != nil { return }` 관용구 |

공통점은 **조기 반환(early return)** 패턴이다. Swift의 `guard`는 이 패턴을 **문법으로 강제**하고, 바인딩 스코프까지 확장해 준다는 점이 특징이다.

## 정리

```text
조건절에 올 수 있는 것 (if / guard / while 공통)
  Bool · 옵셔널 바인딩 · 축약 바인딩 · as?/is · case 패턴
  · 범위 · await / try · 그리고 이들을 , 로 연결

, 는 AND
  옵셔널 바인딩은 Bool 표현식이 아니라 && 를 쓸 수 없다
  순차 평가 → 앞의 바인딩을 뒤 조건에서 쓸 수 있다   ← 핵심 가치
  앞이 실패하면 뒤는 평가되지 않는다 (await 포함)
  바인딩 자체를 OR 로 묶는 것은 불가 → ?? 나 switch 로 대체

guard
  else 필수, else 는 반드시 탈출 (return/break/continue/throw/Never)
  바인딩이 이후 스코프 전체에서 살아 있다   ← 가장 실용적
  정상 경로가 들여쓰기 0단계에 남는다
  "전제 조건"이라는 의도가 드러난다

스코프
  if let    → 중괄호 안까지 (임시)
  guard let → 이후 스코프 전체
  같은 이름으로 그늘짐이 관용적 패턴 (SE-0345 축약형)
  != nil 검사는 언래핑이 아니다

선택
  더 진행 불가 / 이후에도 사용 / 입구 검사 → guard
  둘 다 정상 경로 / 잠깐 처리 / SwiftUI 조건부 렌더링 → if
```

## 학습 체크리스트

**조건절의 형태**

- [ ] `if let parameters = parameters && method != .get`으로 바꿔 에러 메시지를 읽는다.
- [ ] `if let parameters, method != .get`으로 축약 문법을 써 본다.
- [ ] `if var value = optional`로 변수 바인딩을 만들어 값을 수정해 본다.
- [ ] `if case .requestFailed(let code) = error`로 패턴 매칭을 써 본다.
- [ ] `if case 200...299 = code`로 범위 패턴 매칭을 시험한다.
- [ ] `let label = if code < 300 { "성공" } else { "실패" }`로 `if` 표현식을 써 본다.

**`,`와 단축 평가**

- [ ] 두 조건에 각각 `print`를 넣어 단축 평가를 관찰한다 (첫 조건 실패 시 두 번째 미실행).
- [ ] `if let a = x || let b = y`를 시도해 불가능한 것을 확인한다.
- [ ] `if let value = optionalA ?? optionalB`로 OR 대안을 구현한다.
- [ ] `,` 항목 안에서 `||`를 써서 401 또는 403을 잡는 조건을 만든다.

**`guard`**

- [ ] `guard`의 `else`에서 `return`을 지우고 컴파일 에러를 읽는다.
- [ ] `else` 없이 `guard`만 써 보고 에러를 확인한다.
- [ ] 예제의 `guard let`을 `if let`으로 바꿔 `detector`를 이후에 쓸 수 없는 것을 확인한다.
- [ ] 옵셔널 세 개를 검사하는 함수를 `if let` 중첩과 `guard` 두 방식으로 작성해 비교한다.
- [ ] 반복문 안에서 `guard ... else { continue }`를 써 본다.
- [ ] `guard ... else { throw ... }`로 오류를 던지는 함수를 만든다.
- [ ] `fatalError`를 쓰는 `guard`를 만들고 언제 적절한지 설명한다.
- [ ] `body`에서 모든 분기를 명시적 `return`으로 쓴 `guard`가 컴파일되는 것을 확인한다.
- [ ] 같은 `guard`의 두 분기 반환 타입을 다르게 만들어 `some View` 추론 실패를 본다.
- [ ] `VStack { }` 안에서 `guard`를 시도해 `@ViewBuilder` 문맥에서는 안 되는 것을 확인한다.
- [ ] `guard case`로 열거형 패턴 매칭을 해 본다.
- [ ] `try?` + `guard let` 조합을 `do-catch`로 바꿔 오류 내용을 출력해 본다.

**스코프**

- [ ] `if` 블록 밖에서 `httpResponse`를 참조해 컴파일 에러를 확인한다.
- [ ] `if let` 안의 `parameters` 타입을 확인해 옵셔널이 아닌 것을 본다.
- [ ] `guard x != nil` 뒤에서 `x`를 그대로 써 보고 언래핑이 안 된 것을 확인한다.
- [ ] 상태 코드 검사를 `guard` 두 개로 뒤집어 부정이 사라지는 것을 확인한다.
- [ ] `response`가 `HTTPURLResponse`가 아닌 경우가 검증 없이 통과하는 것을 확인한다.

**`await` / `try`**

- [ ] `actor`에 `Bool`을 돌려주는 메서드를 두고 `guard await ...  else { return }`을 써 본다.
- [ ] `guard let n = await ... else`로 비동기 옵셔널 바인딩을 만든다.
- [ ] `guard let m = try await ... else`로 `try`까지 붙여 본다.
- [ ] `await`이 붙은 조건 두 개를 `,`로 이어 앞이 실패할 때 뒤가 호출되지 않는 것을 `print`로 확인한다.
- [ ] `async` 아닌 함수에서 `guard await`을 써서 어떤 에러가 나는지 본다.

## 공식 참고 자료

- [The Swift Programming Language: Control Flow — Conditional Statements](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/#Conditional-Statements)
- [The Swift Programming Language: Control Flow — Early Exit](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/#Early-Exit)
- [The Swift Programming Language: Statements — If Statement](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#If-Statement)
- [The Swift Programming Language: Statements — Guard Statement](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#Guard-Statement)
- [The Swift Programming Language: Statements — While Statement](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#While-Statement)
- [The Swift Programming Language: The Basics — Optional Binding](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optional-Binding)
- [The Swift Programming Language: Basic Operators — Logical Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/basicoperators/#Logical-Operators)
- [The Swift Programming Language: Type Casting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/typecasting/)
- [The Swift Programming Language: Patterns](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/patterns/)
- [The Swift Programming Language: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift Evolution SE-0345: if let shorthand for shadowing an existing optional variable](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0345-if-let-shorthand.md)
- [Swift Evolution SE-0380: if and switch expressions](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0380-if-switch-expressions.md)
- [Apple: fatalError(_:file:line:)](https://developer.apple.com/documentation/swift/fatalerror(_:file:line:))
- [Apple: HTTPURLResponse](https://developer.apple.com/documentation/foundation/httpurlresponse)
