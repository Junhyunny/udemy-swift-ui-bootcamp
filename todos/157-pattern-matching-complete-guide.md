# 패턴 매칭 총정리 — `case .enumCase(let x)`가 쓰이는 모든 자리

`for await` 자체와 **`for await x in` vs `for x in await ...`의 구분**은 [`for await` — 비동기 시퀀스를 반복하기](./105-for-await-async-sequence.md)에서 다룬다. 이 문서는 그 옆에 붙은 **`case ...` 패턴**이 정체가 무엇이고, Swift의 어느 자리에서 쓸 수 있는지를 망라한다.

이 문서의 모든 예제는 **Apple Swift 6.4**로 직접 컴파일해 확인했다.

## 질문이 나온 코드

외부 프로젝트 `voip-ios`의 테스트 코드.

```swift
for await case .iceCandidate(let payload) in sut.events {
    #expect(payload.candidate == offerSdp)
    return
}
```

## 공부할 내용

### 결론부터 — 두 개의 독립된 문법이 겹쳐 있다

어렵게 느껴지는 이유는 **서로 상관없는 두 기능이 한 줄에 붙어 있기** 때문이다. 떼어 놓고 보면 각각은 단순하다.

```swift
for   await   case .iceCandidate(let payload)   in sut.events
//    ~~~~~   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//      │                    └─ ② 패턴: 이 모양인 것만 고르고, 속을 꺼내 payload 에 담는다
//      └─ ① 비동기: 다음 값이 올 때까지 기다린다
```

①은 대상이 `AsyncSequence`라서 붙는 것이고, ②는 **동기 배열에도 똑같이 쓸 수 있는** 문법이다. 둘은 서로 몰라도 된다.

```swift
for case .iceCandidate(let payload) in someArray { }        // ② 만
for await payload in someStream { }                          // ① 만
for await case .iceCandidate(let payload) in someStream { }  // ① + ②
for try await case .iceCandidate(let payload) in throwingStream { }  // 던지는 스트림
```

### `case`가 하는 일 — 필터 + 분해를 한 번에

`for case`는 **조건에 맞는 요소만 남기고, 동시에 연관값을 꺼낸다.** 아래 두 코드는 완전히 같다.

```swift
for case .a(let n) in arr {
    print(n)
}
```

```swift
for e in arr {
    switch e {
    case .a(let n): print(n)
    default: continue          // ← 안 맞으면 조용히 건너뛴다
    }
}
```

실제로 돌려 보면 같은 출력이 나온다.

```
arr = [.c, .a(1), .b("x"), .a(2), .c]

— for case .a —
  받음 1
  받음 2
— 동등한 for + switch —
  받음 1
  받음 2
```

**핵심은 `default: continue`다.** `for case`는 매치되지 않는 요소를 오류로 만들지 않고 **말없이 건너뛴다.** 이 성질이 뒤에서 볼 테스트 함정의 원인이 된다.

### 패턴을 쓸 수 있는 자리 — 여덟 군데

`case` 뒤에 오는 것을 Swift는 **패턴(pattern)** 이라 부르고, 같은 패턴 문법이 여러 구문에서 재사용된다. 하나를 익히면 나머지가 전부 따라온다.

| 자리 | 문법 | 매치 실패 시 | 망라성 요구 |
| --- | --- | --- | --- |
| `switch` | `case .a(let x):` | 다음 `case`로 | **예** (모든 경우를 덮어야 함) |
| `if case` | `if case .a(let x) = e { }` | `if` 건너뜀 | 아니오 |
| `guard case` | `guard case .a(let x) = e else { return }` | `else` 실행 | 아니오 |
| `while case` | `while case .a(let x) = next() { }` | 루프 종료 | 아니오 |
| `for case` | `for case .a(let x) in arr { }` | **그 요소만 건너뜀** | 아니오 |
| `for await case` | `for await case .a(let x) in stream { }` | 그 요소만 건너뜀 | 아니오 |
| `catch` | `catch MyError.bad(let code) { }` | 다음 `catch`로 | 아니오(`catch` 하나는 필요) |
| 변수 선언 | `let (a, b) = pair` | 컴파일 오류 | — |

`switch`만 망라적이어야 한다는 점이 중요하다. 나머지는 **"맞으면 하고 아니면 만다"** 구조다.

```swift
if case .ice(let s) = e { print(s) }                    // else 없어도 됨
guard case .point(let x, let y) = e else { return }     // else 필수
while case .some(.ice(let s)) = it.next() { print(s) }  // 옵셔널 중첩 패턴
catch MyError.bad(let code) where code > 0 { }          // catch 도 패턴 자리
```

### 패턴의 종류 — 여덟 가지

`case` 뒤에 올 수 있는 것들이다. 전부 조합할 수 있다.

| 패턴 | 문법 | 하는 일 |
| --- | --- | --- |
| 와일드카드 | `_` | 아무거나 매치, 버림 |
| 식별자 | `let x` / `var x` | 값을 이름에 바인딩 |
| 값 바인딩 | `case let .a(x)` | 아래 하위 패턴을 전부 바인딩 |
| 튜플 | `case (let a, let b)` | 튜플 분해 |
| 열거형 케이스 | `case .a(let x)` | 케이스 확인 + 연관값 추출 |
| 옵셔널 | `case let x?` / `case .some(x)` | `nil`을 걸러내고 언래핑 |
| 타입 캐스팅 | `case let v as String` / `case is Int` | 동적 타입 확인 + 캐스팅 |
| 표현식 | `case 1...9` / `case Even()` | `~=` 연산자로 비교 |

실제 코드로 보면 이렇다. **모두 `for`에서도 그대로 쓸 수 있다.**

```swift
// 옵셔널 걸러내기 — compactMap 없이
let maybe: [Int?] = [1, nil, 3]
for case let n? in maybe { print(n) }          // 1, 3

// 타입으로 걸러내기
let anys: [Any] = [1, "hi", 2.0]
for case let s as String in anys { print(s) }  // "hi"

// 튜플 분해 + 상수 고정
for case (2, let s) in [(1, "a"), (2, "b")] { print(s) }  // "b"

// 레이블 있는 연관값
for case .point(x: let a, y: let b) in events { print(a, b) }
```

표현식 패턴은 `~=` 연산자를 직접 정의해 확장할 수 있다.

```swift
struct Even {}
func ~= (pattern: Even, value: Int) -> Bool { value % 2 == 0 }

switch n {
case Even(): print("짝수")
case 1...9:  print("한 자리 홀수")
default:     print("그 외")
}
```

`1...9`가 `switch`에서 동작하는 이유도 표준 라이브러리에 `Range`용 `~=`가 정의돼 있어서다. 특별 문법이 아니라 **연산자 오버로딩**이다.

### `let`의 위치가 두 가지인 이유

가장 많이 헷갈리는 지점이다. 둘 다 컴파일되고 의미도 같다.

```swift
for case .point(let a, let b) in events { }   // 개별 바인딩
for case let .point(a, b) in events { }       // 값 바인딩 패턴 — 한 번에
```

- `case .point(let a, let b)` — 꺼낼 값마다 `let`을 붙인다. **일부만 바인딩할 때** 쓸 수 있다: `case .point(x: 0, y: let y)`처럼 `x`는 값으로 고정하고 `y`만 꺼내는 식이다.
- `case let .point(a, b)` — 패턴 전체 앞에 `let` 하나를 붙이면 **안쪽 이름이 전부 바인딩**된다. 전부 꺼낼 때 짧다.

`var`로 바꾸면 루프 본문에서 수정 가능한 복사본이 된다(컴파일 확인). 보통은 `let`을 쓴다.

```swift
for case .a(var n) in arr { n += 1; print(n) }   // 동작하지만 원본은 안 바뀜
```

### `where` 절로 조건을 더한다

패턴이 맞은 **뒤에** 추가 조건을 건다. 바인딩한 변수를 조건에 쓸 수 있다는 게 핵심이다.

```swift
for case .iceCandidate(let s) in events where s.count > 0 { print(s) }
for await case let .iceCandidate(p) in events where !p.candidate.isEmpty { }
switch e {
case .ice(let s) where s.isEmpty: print("빈 후보")
case .ice(let s):                 print(s)
}
```

`if case`에서는 `where` 대신 쉼표를 쓴다. [옵셔널 바인딩 문서](./158-conditional-statements-complete-guide.md)에서 본 `if let a = x, a > 0`과 같은 구조다.

```swift
if case let .ice(s) = e, s.count > 2 { print(s) }
```

### 컴파일되지 않는 것들 (실측 메시지)

헷갈리기 쉬운 실수와 그때 나오는 메시지다.

| 코드 | 메시지 | 이유 |
| --- | --- | --- |
| `for .a(let n) in arr` | `expected pattern` | **`case` 키워드가 빠졌다.** 이게 가장 흔한 실수다 |
| `if .a(let n) = e` | `expected expression in list of expressions` | 위와 같음 |
| `case .a(let n), .b(let n)` (`Int`와 `String`) | `pattern variable bound to type 'String', expected type 'Int'` | 여러 패턴이 같은 이름을 바인딩하면 **타입이 같아야** 한다 |
| `case .a(let n), .b` | `'n' must be bound in every pattern` | 한 패턴에서만 바인딩할 수 없다 |

타입만 같으면 여러 패턴을 묶는 것은 정상이다.

```swift
enum Two { case a(Int), b(Int) }
switch t {
case .a(let n), .b(let n): print(n)   // OK
}
```

### 이 테스트 코드의 함정

질문의 코드로 돌아가면, **`for case`가 말없이 건너뛴다**는 성질이 테스트에서는 위험해진다.

```swift
for await case .iceCandidate(let payload) in sut.events {
    #expect(payload.candidate == offerSdp)
    return                      // 첫 매치에서 탈출
}
```

- `.iceCandidate` 외의 이벤트는 **조용히 무시**된다. 여기까진 의도대로다.
- 그런데 `.iceCandidate`가 **영영 오지 않으면** `#expect`는 한 번도 실행되지 않는다. `AsyncStream`은 끝나지 않는 스트림이므로 루프는 종료되지도 않는다. **실패가 아니라 무한 대기**다.
- 스트림이 `finish()`로 닫히면 루프는 그냥 빠져나가고, 이번에도 `#expect` 없이 **테스트가 통과**해 버린다.

즉 이 테스트는 **거짓 통과(false pass)와 멈춤(hang) 양쪽에 열려 있다.** 매치를 받았다는 사실 자체를 검증에 포함시키고 시간 제한을 두는 편이 안전하다.

```swift
var received: Candidate?
for await case .iceCandidate(let payload) in sut.events {
    received = payload
    break
}
#expect(received?.candidate == offerSdp)   // 못 받았으면 nil 이라 실패한다
```

Swift Testing이면 `@Test(.timeLimit(.minutes(1)))` 트레이트로 멈춤도 막을 수 있다.

한 가지 더 — `payload.candidate == offerSdp`는 **ICE candidate 문자열을 offer SDP와 비교**하고 있다. 도메인상 다른 값일 가능성이 높으니 기대값이 맞는지 확인해 볼 만하다.

### 정리 — 읽는 순서

낯선 패턴 문법을 만나면 이 순서로 끊어 읽으면 된다.

1. **`case`가 있나?** → 있으면 "필터 + 분해", 없으면 단순 순회
2. **`await`가 있나?** → 있으면 각 요소를 기다림 (`AsyncSequence`)
3. **`let`이 어디 붙었나?** → 패턴 앞이면 전부 바인딩, 안쪽이면 그것만
4. **`where`가 있나?** → 패턴이 맞은 뒤의 추가 조건
5. **매치 안 되면?** → `for case`/`if case`는 건너뛰고, `guard case`는 `else`로 간다

## 학습 체크리스트

- [ ] `for case .a(let n) in arr`를 `for` + `switch` + `default: continue`로 직접 풀어 써서 같은 출력을 확인한다.
- [ ] 매치가 0건인 배열로 `for case`를 돌려 본문이 한 번도 실행되지 않는 것을 확인한다.
- [ ] `case` 키워드를 빼고 `for .a(let n) in arr`를 컴파일해 `expected pattern` 메시지를 본다.
- [ ] `case .a(let x)`와 `case let .a(x)`를 서로 바꿔 써 보고 동작이 같은지 확인한다.
- [ ] `case .point(x: 0, y: let y)`처럼 일부만 바인딩해 본다.
- [ ] `[Int?]`에 `for case let n?`을 써서 `compactMap` 없이 `nil`을 걸러낸다.
- [ ] `[Any]`에 `for case let s as String`을 써서 타입으로 걸러낸다.
- [ ] `~=` 연산자를 직접 정의해 커스텀 타입을 `switch`의 `case`에 넣어 본다.
- [ ] 타입이 다른 두 패턴이 같은 이름을 바인딩하게 해서 오류 메시지를 확인한다.
- [ ] `if case`, `guard case`, `while case`, `catch`에 같은 패턴을 각각 넣어 본다.
- [ ] `for await case`에서 매치되는 이벤트를 아예 보내지 않고 테스트가 멈추는지 확인한다.
- [ ] 위 테스트를 `received` 변수로 고쳐 못 받았을 때 실패하도록 만든다.

## 참고 자료

- [The Swift Programming Language: Patterns](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/patterns/)
- [The Swift Programming Language: Control Flow — Switch](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow/#Switch)
- [The Swift Programming Language: Enumerations — Associated Values](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/#Associated-Values)
- [The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [The Swift Programming Language: Error Handling — Handling Errors Using Do-Catch](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/#Handling-Errors-Using-Do-Catch)
- [Apple: AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence)
- [Apple: Pattern Match Operator `~=`](https://developer.apple.com/documentation/swift/1539349)
- [Apple: Swift Testing — TimeLimitTrait](https://developer.apple.com/documentation/testing/timelimittrait)
