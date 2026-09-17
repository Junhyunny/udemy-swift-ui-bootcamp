# Swift의 오류 처리 방식들 — `try`, `try?`, `try!`, `do-catch`, `defer`

## 질문이 나온 코드

`chapter-35/chapter-35/ContentView.swift`의 `do { try await URLSession.shared.data(...) } catch { ... }`와 주석 처리된 `// try? await Task.sleep(for: .seconds(2))`

## 공부할 내용

### 출발점 — `throws`를 붙인 함수는 호출할 때 `try`가 강제된다

> "To indicate that a function, method, or initializer can throw an error, you write the `throws` keyword in the function's declaration after its parameters."
>
> "Because the `vend(itemNamed:)` method propagates any errors it throws, any code that calls this method must either handle the errors — using a `do`-`catch` statement, `try?`, or `try!` — or continue to propagate them."

즉 선택지는 **네 가지**다. `do-catch`로 잡거나, `try?`로 옵셔널화하거나, `try!`로 무시하거나, 내 함수도 `throws`를 달아 위로 떠넘기거나.

`try`는 그 자체로 오류를 처리하지 않는다. **"이 줄에서 오류가 튀어나올 수 있다"는 표시**일 뿐이다. `await`가 "여기서 멈출 수 있다"를 표시하는 것과 같은 성격이라, `try await`처럼 나란히 붙는다.

### 1. `do-catch` — 오류를 실제로 다룰 때

```swift
do {
    let (data, response) = try await URLSession.shared.data(from: url)
    // 성공 경로
} catch {
    print("error: \(error.localizedDescription)")
}
```

`catch`에 패턴을 쓰면 오류 종류별로 나눠 처리할 수 있다.

```swift
do {
    try vendingMachine.vend(itemNamed: "Chips")
} catch VendingMachineError.invalidSelection {
    print("Invalid Selection.")
} catch VendingMachineError.outOfStock {
    print("Out of Stock.")
} catch let error as VendingMachineError {
    print("Vending machine error: \(error)")
} catch {
    print("Unexpected error: \(error).")   // 바인딩 없이도 error 사용 가능
}
```

패턴 없는 마지막 `catch`에서는 **`error`라는 이름이 자동으로 바인딩**된다. 지금 코드가 이 형태다.

### 2. `try?` — 오류를 `nil`로 바꿀 때

> "You use `try?` to handle an error by converting it to an optional value. If an error is thrown while evaluating the `try?` expression, the value of the expression is `nil`."

```swift
let x = try? someThrowingFunction()   // 반환 타입이 Int면 x는 Int?
```

아래 `do-catch`와 정확히 같은 뜻이다.

```swift
let y: Int?
do { y = try someThrowingFunction() } catch { y = nil }
```

**오류의 내용은 버려진다.** "실패하면 그냥 안 하면 된다"일 때만 쓴다. 주석 처리된 `try? await Task.sleep(for: .seconds(2))`가 좋은 예다. `Task.sleep`은 취소되면 오류를 던지는데, 이 경우 딱히 할 일이 없으므로 `try?`로 삼킨다.

> "Using `try?` lets you write concise error handling code when you want to handle all errors in the same way."

### 3. `try!` — 절대 실패하지 않는다고 확신할 때

> "Sometimes you know a throwing function or method won't, in fact, throw an error at runtime. On those occasions, you can write `try!` before the expression to disable error propagation and wrap the call in a runtime assertion that no error will be thrown. If an error actually is thrown, you'll get a runtime error."

```swift
let photo = try! loadImage(atPath: "./Resources/John Appleseed.jpg")
```

앱에 번들된 리소스처럼 실패가 곧 프로그래머 실수인 경우에만 쓴다. 틀리면 **런타임 크래시**다. 지금 코드의 `URL(string:)!` 강제 언래핑도 성격이 같다 — 리터럴 문자열이라 실패할 수 없다는 전제다.

### 4. `throws`로 떠넘기기

직접 처리하지 않고 호출자에게 넘긴다. `fetchData()`를 이렇게 바꿀 수도 있다.

```swift
private func fetchData() async throws {
    let (_, _) = try await URLSession.shared.data(from: url)
    randomData.append(Int.random(in: 10...10000))
}
```

그러면 호출부가 `try await fetchData()`로 바뀌고 오류 처리 책임이 위로 올라간다. 어느 계층에서 처리할지는 설계 판단이다.

관련해 `rethrows`도 있다. **인자로 받은 클로저가 던질 때만** 던지는 함수에 쓴다(`map`, `filter` 등이 그렇다). 최신 Swift에는 오류 타입을 명시하는 **typed throws**(`throws(MyError)`)도 있다.

### 5. "try-with-resources 같은 자동 정리가 있나" — `defer`가 그 역할이다

Java의 try-with-resources나 Python의 `with`에 해당하는 전용 문법은 없다. 대신 `defer`가 같은 일을 더 일반적인 방식으로 한다.

> "You use a `defer` statement to execute a set of statements just before code execution leaves the current block of code. This statement lets you do any necessary cleanup that should be performed regardless of how execution leaves the current block of code — whether it leaves because an error was thrown or because of a statement such as `return` or `break`."

```swift
func processFile(filename: String) throws {
    if exists(filename) {
        let file = open(filename)
        defer {
            close(file)          // 어떻게 빠져나가든 반드시 실행된다
        }
        while let line = try file.readline() {
            // Work with the file.
        }
    }
}
```

차이점이 둘 있다. 첫째, `defer`는 **정리 대상 타입이 특정 프로토콜을 따를 필요가 없다.** 아무 코드나 넣을 수 있어 더 자유롭다. 둘째, 여러 개를 쓰면 **역순으로** 실행된다.

> "Deferred actions are executed in the reverse of the order that they're written in your source code. That is, the code in the first `defer` statement executes last... The last `defer` statement in source code order executes first."

또 `defer` 블록 안에서는 `return`, `break`, `throw`로 밖으로 빠져나갈 수 없다.

한편 클래스라면 `deinit`이, 값 타입이라면 스코프 종료가 자동 정리를 맡는 경우도 많다. Swift는 ARC로 메모리를 관리하므로 "닫아야 하는 것"은 대개 파일 핸들·네트워크 연결 같은 외부 자원에 한정된다.

### 정리표

| 방식 | 오류가 나면 | 언제 쓰나 |
| --- | --- | --- |
| `do-catch` | `catch`로 넘어감 | 실제로 대응할 게 있을 때 |
| `try?` | 결과가 `nil` | 실패해도 무시해도 될 때 |
| `try!` | 런타임 크래시 | 절대 실패하지 않음이 보장될 때만 |
| `throws` 전파 | 호출자에게 넘어감 | 이 계층에서 판단할 수 없을 때 |
| `defer` | (오류와 무관) 항상 실행 | 자원 정리 |

## 학습 체크리스트

- [ ] `do-catch`를 `try?`로 바꿔 보고 오류가 나도 조용히 넘어가는 것을 확인한다.
- [ ] URL을 잘못된 주소로 바꿔 `catch` 블록이 실제로 실행되는지 확인한다.
- [ ] `catch`에 `URLError` 패턴을 추가해 오류 종류별로 나눠 처리한다.
- [ ] `try!`로 바꾸고 잘못된 URL을 넣어 크래시를 직접 겪어 본다.
- [ ] `fetchData()`를 `async throws`로 바꾸고 호출부가 어떻게 달라지는지 본다.
- [ ] `defer`를 두 개 넣고 실행 순서가 역순인지 `print`로 확인한다.
- [ ] `defer` 안에 `return`을 넣어 컴파일 오류를 확인한다.
- [ ] 오류를 던지는 `if` 경로와 정상 경로 양쪽에서 `defer`가 모두 실행되는지 확인한다.
- [ ] 자체 `enum MyError: Error`를 정의하고 `throw`해 `catch` 패턴 매칭을 실험한다.
- [ ] `error.localizedDescription`과 `String(describing: error)`의 출력 차이를 비교한다.

## 참고 자료

- [The Swift Programming Language: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)
- [The Swift Programming Language: Control Flow](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/)
- [The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [The Swift Programming Language: Declarations](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/)
- [Swift Evolution SE-0413: Typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md)
- [Apple: Error](https://developer.apple.com/documentation/swift/error)
- [Apple: URLError](https://developer.apple.com/documentation/foundation/urlerror)
- [Apple: URLSession.data(from:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/data(from:delegate:))
- [Apple: Task.sleep(for:tolerance:clock:)](https://developer.apple.com/documentation/swift/task/sleep(for:tolerance:clock:))
