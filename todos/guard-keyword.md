# `guard` 키워드 — 조기 탈출과 그 장점

## 질문이 나온 코드

`chapter-50/chapter-50/ContentView.swift`

```swift
func extractFirstURL(from text: String) -> URL? {
    let types: NSTextCheckingResult.CheckingType = .link
    guard let detector = try? NSDataDetector(types: types.rawValue) else {
        return nil
    }
    let matches = detector.matches(...)
    return matches.first?.url
}
```

## 공부할 내용

### 무엇을 하는 문장인가

> A `guard` statement, like an `if` statement, executes statements depending on the Boolean value of an expression. You use a `guard` statement to require that a condition must be true in order for the code after the `guard` statement to be executed. Unlike an `if` statement, a `guard` statement always has an `else` clause — the code inside the `else` clause is executed if the condition isn't true.

핵심은 **"이 조건이 참이어야만 아래 코드가 실행된다"** 는 요구사항 선언이다.

```swift
guard 조건 else {
    // 조건이 거짓일 때 실행되고, 반드시 이 스코프를 빠져나가야 한다
}
// 조건이 참일 때 이어지는 코드
```

`if`와 결정적으로 다른 점이 셋이다.

- **`else` 절이 필수다.**
- **`else` 절은 반드시 스코프를 벗어나야 한다.**
- **옵셔널 바인딩한 값이 `guard` 이후에도 살아 있다.**

세 번째가 실무에서 가장 크게 체감되는 차이다.

### `else` 절의 의무 — 반드시 탈출해야 한다

> If that condition isn't met, the code inside the `else` branch is executed. That branch must transfer control to exit the code block in which the `guard` statement appears. It can do this with a control transfer statement such as `return`, `break`, `continue`, or `throw`, or it can call a function or method that doesn't return, such as `fatalError(_:file:line:)`.

`else` 안에서 쓸 수 있는 것들이다.

| 방법 | 쓰이는 곳 |
| --- | --- |
| `return` | 함수 — 예제가 쓰는 것 |
| `break` | 반복문, `switch` |
| `continue` | 반복문 |
| `throw` | 오류를 던지는 함수 |
| `fatalError(...)` | 절대 도달하면 안 되는 경우 |

빠져나가지 않으면 컴파일 에러다. **"조건이 틀렸는데도 계속 진행하는" 실수를 언어가 막아 준다.**

```swift
guard let x = optionalValue else {
    print("없음")      // ⚠️ 컴파일 에러 — 탈출하지 않았다
}
```

### 옵셔널 바인딩이 이후에도 살아 있다 — 가장 큰 장점

`if let`과 비교하면 차이가 분명하다.

```swift
// if let — 바인딩한 값이 중괄호 안에서만 유효
func extractA(from text: String) -> URL? {
    if let detector = try? NSDataDetector(types: 0) {
        let matches = detector.matches(...)
        return matches.first?.url
    }
    return nil
}
// detector는 여기서 못 쓴다

// guard let — 바인딩한 값이 함수 끝까지 유효
func extractB(from text: String) -> URL? {
    guard let detector = try? NSDataDetector(types: 0) else {
        return nil
    }
    let matches = detector.matches(...)   // detector 사용 가능
    return matches.first?.url
}
```

공식 문서가 이 성질을 명시한다.

> If the `guard` statement's condition is met, code execution continues after the `guard` statement's closing brace. Any variables or constants that were assigned values using an optional binding as part of the condition are available for the rest of the code block that the `guard` statement appears in.

예제의 `detector`가 `guard` 이후 `matches(...)` 호출에서 쓰이는 것이 정확히 이 성질 덕분이다.

### 왜 읽기 쉬워지는가 — 중첩이 사라진다

공식 문서가 장점을 직접 설명한다.

> Using a `guard` statement for requirements improves the readability of your code, compared to doing the same check with an `if` statement. It lets you write the code that's typically executed without wrapping it in an `else` block, and it lets you keep the code that handles a violated requirement next to the requirement.

두 가지를 말하고 있다.

**① 정상 경로를 `else` 블록으로 감싸지 않아도 된다**

조건이 여러 개면 차이가 극적이다.

```swift
// if let 중첩 — 오른쪽으로 계속 밀린다 (pyramid of doom)
func process(_ input: String?) -> String? {
    if let input = input {
        if let url = URL(string: input) {
            if let host = url.host {
                return host.uppercased()
            } else {
                return nil
            }
        } else {
            return nil
        }
    } else {
        return nil
    }
}

// guard — 평평하게 유지된다
func process(_ input: String?) -> String? {
    guard let input else { return nil }
    guard let url = URL(string: input) else { return nil }
    guard let host = url.host else { return nil }
    return host.uppercased()
}
```

**정상 경로가 들여쓰기 0단계에 남는다**는 것이 핵심이다. 함수의 본론을 읽는 데 방해가 없다.

**② 실패 처리가 조건 바로 옆에 있다**

`if-else`는 조건과 실패 처리 사이에 정상 코드가 통째로 끼어든다. `guard`는 "이 조건이 틀리면 이렇게 한다"가 붙어 있어 대응 관계가 즉시 보인다.

### 추가 장점 — 의도가 드러난다

`guard`는 문법이자 **선언**이다. 코드를 읽는 사람에게 이렇게 말한다.

> "여기서부터 아래는 이 조건이 참이라고 가정한다."

`if`는 분기를 뜻하지만 `guard`는 **전제 조건(precondition)** 을 뜻한다. 함수 맨 위에 `guard`들이 모여 있으면 그것이 곧 그 함수의 입력 계약서가 된다.

```swift
func transfer(amount: Decimal, from: Account?, to: Account?) throws {
    guard let from else { throw TransferError.missingSource }
    guard let to else { throw TransferError.missingDestination }
    guard amount > 0 else { throw TransferError.invalidAmount }
    guard from.balance >= amount else { throw TransferError.insufficientFunds }

    // 여기부터는 모든 전제가 충족된 상태
}
```

### 쓸 수 있는 조건의 형태

**옵셔널 바인딩**

```swift
guard let detector = try? NSDataDetector(types: types.rawValue) else { return nil }
```

Swift 5.7부터는 같은 이름이면 축약할 수 있다.

```swift
guard let detectedURL else { return }     // guard let detectedURL = detectedURL
```

예제 코드의 `if let detectedURL {`도 같은 축약 문법이다.

#### 축약 문법을 자세히 — `chapter-88`의 질문

`chapter-88/chapter-88/WebView.swift`에 이 문법이 나온다.

```swift
struct WebView: UIViewRepresentable {
    let urlString: String?          // ← 멤버 프로퍼티 (옵셔널)

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // TODO, 여기서 urlString 이라는 키워드가 위 멤버 변수 urlString이 있는지 없는지
        //       보기 위한 가드가 되는거야? let 을 사용해서 새로 선언한 것인줄 알았는데
        guard let urlString, let url = URL(string: urlString) else { return }
        // ...
    }
}
```

**질문의 첫 번째 이해가 맞다.** 멤버 프로퍼티 `urlString`이 `nil`인지 확인하는 것이다.

**두 번째 짐작("`let`으로 새로 선언한 것")도 절반은 맞다.** 실제로 **새 상수를 만든다.** 다만 값을 다른 데서 가져오는 것이 아니라 **같은 이름의 옵셔널에서 꺼낸다.**

```swift
guard let urlString              // 축약형
guard let urlString = urlString  // 원래 형태 — 완전히 같다
//        ↑ 새 상수      ↑ self.urlString (옵셔널)
```

즉 **두 개의 `urlString`이 존재한다.**

| | 타입 | 정체 |
| --- | --- | --- |
| `self.urlString` | `String?` | 멤버 프로퍼티 |
| `urlString` (guard 이후) | **`String`** | 새로 만든 비옵셔널 상수 |

블록 안에서 `urlString`을 쓰면 **새로 만든 비옵셔널 상수**를 가리키고, 원래 옵셔널은 가려진다(shadowed). 이것이 [`if` 조건 문서](./if-conditions-and-optional-binding.md)에서 다룬 **그늘짐(shadowing)** 이다.

**그래서 `URL(string: urlString)`에 옵셔널이 아닌 값이 들어간다.**

```swift
guard let urlString, let url = URL(string: urlString) else { return }
//                                         ↑ 비옵셔널 String
```

축약형이 없던 시절에는 이름을 다르게 지어야 했다.

```swift
// Swift 5.7 이전 관례
guard let unwrappedURLString = urlString else { return }
guard let urlString = self.urlString else { return }   // self.로 구분
```

**축약 문법이 이 번거로움을 없앤 것**이다. Swift Evolution SE-0345가 그 제안이다.

**주의할 점** — 축약형은 **이름이 같을 때만** 쓸 수 있다.

```swift
guard let url = URL(string: urlString) else { return }   // 이름이 다르므로 축약 불가
guard let url else { ... }                               // url이라는 옵셔널이 있어야 성립
```

같은 줄의 두 바인딩이 서로 다른 형태인 이유가 이것이다. `urlString`은 이름이 같아 축약했고, `url`은 `URL(string:)`의 결과라 이름을 명시했다.

**`self`를 축약할 때는 의미가 조금 다르다.**

```swift
guard let self else { return }      // weak self를 강한 참조로 승격
```

[`[weak self]` 문서](./weak-self-and-deinit.md)에서 다룬 형태다. 문법은 같지만 "옵셔널 `self`를 비옵셔널로"라는 목적이 뚜렷하다.

**불리언 조건**

```swift
guard !text.isEmpty else { return nil }
guard index < array.count else { return }
```

**여러 조건을 쉼표로**

```swift
guard let url = URL(string: input),
      let host = url.host,
      !host.isEmpty else {
    return nil
}
```

쉼표는 AND다. 하나라도 실패하면 `else`로 간다.

**`case` 패턴 매칭**

```swift
guard case .success(let value) = result else { return }
```

**`where` 절**

```swift
guard let age = person.age, age >= 18 else { return }
```

### `if`와 `guard`, 어느 쪽을 쓰나

| 상황 | 선택 |
| --- | --- |
| 조건이 틀리면 **더 진행할 수 없다** | `guard` |
| 바인딩한 값을 **이후에도 써야 한다** | `guard` |
| 함수 입구의 **전제 조건 검사** | `guard` |
| 두 갈래가 **둘 다 정상 경로**다 | `if` |
| 조건이 참일 때만 **잠깐 뭘 한다** | `if` |
| 값이 있을 때만 뷰를 그린다 (SwiftUI) | `if let` |

예제 코드가 둘을 적절히 나눠 쓴다.

```swift
// guard — detector가 없으면 함수를 진행할 수 없다
guard let detector = try? NSDataDetector(types: types.rawValue) else {
    return nil
}
```

```swift
// if let — URL이 있을 때만 Link를 그리고, 없으면 그냥 안 그린다
if let detectedURL {
    Link(...)
}
```

두 번째는 "없으면 아무것도 안 한다"이지 "탈출한다"가 아니다. 게다가 `body` 안이라 `return`으로 빠져나갈 수도 없다. `if let`이 맞다.

### `guard`와 오류 처리의 조합

예제의 `try?`와 `guard`가 함께 쓰인 것도 눈여겨볼 만하다.

```swift
guard let detector = try? NSDataDetector(types: types.rawValue) else {
    return nil
}
```

`NSDataDetector(types:)`는 `throws` 이니셜라이저다. `try?`가 오류를 `nil`로 바꾸고, `guard let`이 그 `nil`을 걸러낸다.

오류 내용을 알아야 한다면 `do-catch`가 맞다.

```swift
do {
    let detector = try NSDataDetector(types: types.rawValue)
    // ...
} catch {
    print("탐지기 생성 실패:", error)
    return nil
}
```

이 예제는 `.link` 타입이 항상 유효해서 실패할 일이 사실상 없으므로 `try?`로 충분하다. 선택 기준은 [Swift의 오류 처리 방식들](./swift-error-handling-forms.md)에 정리했다.

### 다른 언어와 비교

| 언어 | 대응 개념 |
| --- | --- |
| Java/Kotlin | early return (`if (x == null) return;`) — 언어 강제는 없음 |
| Kotlin | `?:` 엘비스 + `return` |
| Rust | `let ... else`, `?` 연산자 |
| Go | `if err != nil { return }` 관용구 |

공통점은 **조기 반환(early return)** 패턴이다. Swift의 `guard`는 이 패턴을 **문법으로 강제**하고, 바인딩 스코프까지 확장해 준다는 점이 특징이다.

### 정리

```text
guard 조건 else { 반드시 탈출 }

if let 대비 장점
  ① 바인딩 값이 이후에도 살아 있다      ← 가장 실용적
  ② 정상 경로가 들여쓰기 0단계에 남는다
  ③ 실패 처리가 조건 바로 옆에 있다
  ④ 탈출을 컴파일러가 강제한다
  ⑤ "전제 조건"이라는 의도가 드러난다

쓸 곳: 더 진행할 수 없는 조건, 함수 입구의 검사
안 쓸 곳: 두 갈래가 모두 정상인 분기, SwiftUI body 안의 조건부 렌더링
```

## 학습 체크리스트

- [ ] `guard`의 `else`에서 `return`을 지우고 어떤 컴파일 에러가 나는지 읽는다.
- [ ] `else` 없이 `guard`만 써 보고 에러를 확인한다.
- [ ] 예제의 `guard let`을 `if let`으로 바꿔 `detector`를 이후에 쓸 수 없는 것을 확인한다.
- [ ] 옵셔널 세 개를 검사하는 함수를 `if let` 중첩과 `guard` 두 방식으로 작성해 비교한다.
- [ ] `guard let detectedURL else { }` 축약 문법을 써 본다.
- [ ] 쉼표로 여러 조건을 잇는 `guard`를 작성하고 하나만 실패시켜 본다.
- [ ] 반복문 안에서 `guard ... else { continue }`를 써 본다.
- [ ] `guard ... else { throw ... }`로 오류를 던지는 함수를 만든다.
- [ ] `fatalError`를 쓰는 `guard`를 만들고 언제 적절한지 설명한다.
- [ ] `body` 안에서 `guard`를 시도해 왜 안 되는지 확인한다.
- [ ] `if let detectedURL { Link(...) }`를 `guard`로 바꿀 수 없는 이유를 설명한다.
- [ ] `guard case`로 열거형 패턴 매칭을 해 본다.
- [ ] `try?` + `guard let` 조합을 `do-catch`로 바꿔 오류 내용을 출력해 본다.

## 공식 참고 자료

- [Swift 공식 문서: Control Flow — Early Exit](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/#Early-Exit)
- [Swift 공식 문서: Statements — Guard Statement](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/statements/#Guard-Statement)
- [Swift 공식 문서: The Basics — Optional Binding](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optional-Binding)
- [Swift 공식 문서: The Basics — Optionals](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals)
- [Swift 공식 문서: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [Swift 공식 문서: Control Flow](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/)
- [Apple: fatalError(_:file:line:)](https://developer.apple.com/documentation/swift/fatalerror(_:file:line:))
