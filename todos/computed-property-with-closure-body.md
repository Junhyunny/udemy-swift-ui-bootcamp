# `var formatter: NumberFormatter { ... }` — 이 선언 방식은 무엇인가

`static` 저장/계산 프로퍼티의 차이는 [별도 문서](./static-stored-vs-computed-property.md)에 정리했다. 이 문서는 **지역 계산 프로퍼티와 즉시 실행 클로저**를 다룬다.

## 질문이 나온 코드

`chapter-80/chapter-80/ViewModels/ViewModel.swift`

```swift
func formatRateForLocale(for key: String) -> String {
    guard let mainRates = exchangeRate?.rates else { return "" }
    let rate = mainRates[key] ?? 1.0

    // TODO, NumberFormatter는 클래스야? 프로토콜이야?
    //       왜 타입 {클로져} 로 선언하고 내부에서 다시 NumberFormatter 객체를 만들어서
    //       특정 작업을 수행하지? 이런 방식을 뭐라고 불러?
    var formatter: NumberFormatter {
        let fm = NumberFormatter()
        fm.numberStyle = .currency
        fm.locale = Locale(identifier: key.dropLast() + "_" + key.dropLast().uppercased())
        return fm
    }

    return formatter.string(from: NSNumber(value: rate))!
}
```

## 공부할 내용

### 질문 ① `NumberFormatter`는 클래스다

```swift
class NumberFormatter : Formatter
```

**프로토콜이 아니라 클래스**다. `Formatter`를 상속하고, `Formatter`는 `NSObject`를 상속한다. [NS 접두사 문서](./ns-prefix-foundation-classes.md)에서 다룬 Objective-C 계열 타입이다.

```text
NSObject → Formatter → NumberFormatter
                     → DateFormatter
                     → ByteCountFormatter
```

**참조 타입이므로** 인스턴스를 만들고 프로퍼티를 설정한 뒤 쓰는 방식이 자연스럽다. 그래서 코드가 `let fm = NumberFormatter()` 다음에 설정을 이어가는 형태가 된다.

### 질문 ② `{ }`는 클로저가 아니다 — 계산 프로퍼티다

**이것이 핵심 오해다.** 저 `{ }`는 클로저가 아니라 **계산 프로퍼티(computed property)의 본문**이다.

```swift
var formatter: NumberFormatter {
    // 여기가 getter 본문
    return fm
}
```

Swift에서 프로퍼티 선언 뒤에 `{ }`가 오면 계산 프로퍼티다. `get`을 생략한 형태이고, 원래는 이렇게 쓴다.

```swift
var formatter: NumberFormatter {
    get {
        let fm = NumberFormatter()
        // ...
        return fm
    }
}
```

**읽기 전용이면 `get`을 생략할 수 있다.** [static 프로퍼티 문서](./static-stored-vs-computed-property.md)에서 다룬 `static var sample: [Course] { ... }`와 같은 문법이다.

**즉시 실행 클로저와 혼동하기 쉽다.** 그쪽은 끝에 `()`가 붙는다.

```swift
// 계산 프로퍼티 — 접근할 때마다 실행
var formatter: NumberFormatter { ... }

// 즉시 실행 클로저 — 선언 시점에 한 번 실행
let formatter: NumberFormatter = { ... }()
//                                     ↑ 이 괄호가 차이
```

chapter-61의 `AppConfig`가 후자였다.

```swift
static let apiKey: String = {
    guard let value = ... else { fatalError(...) }
    return value
}()          // ← 즉시 실행
```

### 두 방식의 차이

| | 계산 프로퍼티 `{ }` | 즉시 실행 클로저 `{ }()` |
| --- | --- | --- |
| 실행 시점 | **접근할 때마다** | 선언 시 한 번 |
| 선언 | `var` 필수 | `let` 가능 |
| 값 저장 | 안 함 | 저장됨 |
| 용도 | 매번 계산해야 할 때 | 복잡한 초기화 |

**이 코드는 계산 프로퍼티이므로 `formatter`에 접근할 때마다 `NumberFormatter`가 새로 만들어진다.** 그리고 접근은 딱 한 번(`formatter.string(...)`)이므로 결과적으로 한 번만 만들어진다.

### 질문 ③ 왜 이렇게 쓰나 — 함수 안의 지역 계산 프로퍼티

**함수 안에서 여러 줄 설정이 필요한 값을 만들 때 쓰는 방식**이다.

```swift
// 이렇게 쓸 수도 있다 — 가장 단순
let formatter = NumberFormatter()
formatter.numberStyle = .currency
formatter.locale = Locale(identifier: ...)
return formatter.string(from: ...)!
```

```swift
// 계산 프로퍼티로 감싸면
var formatter: NumberFormatter {
    let fm = NumberFormatter()
    fm.numberStyle = .currency
    fm.locale = Locale(identifier: ...)
    return fm
}
return formatter.string(from: ...)!
```

**감싸서 얻는 것**

- 설정 코드가 한 블록에 묶여 **범위가 명확하다**
- `fm`이라는 임시 변수가 블록 밖으로 노출되지 않는다
- "이 값을 만드는 과정"과 "그 값을 쓰는 코드"가 분리된다

**하지만 이 경우는 과하다.** 한 번만 쓰는 값이라면 직접 만드는 쪽이 짧고 읽기 쉽다. 계산 프로퍼티는 "접근할 때마다 다시 계산한다"는 의미를 갖는데, 여기서는 그럴 필요가 없다.

**즉시 실행 클로저가 더 맞는 표현이다.**

```swift
let formatter: NumberFormatter = {
    let fm = NumberFormatter()
    fm.numberStyle = .currency
    fm.locale = Locale(identifier: ...)
    return fm
}()
```

`let`이라 값이 고정되고, "한 번 만들어 쓴다"는 의도가 드러난다.

### 이 방식을 부르는 이름

질문의 "이런 방식을 뭐라고 불러?"에 답하면 상황에 따라 이름이 다르다.

| 형태 | 이름 |
| --- | --- |
| `var x: T { ... }` | **계산 프로퍼티** (computed property) |
| `let x: T = { ... }()` | **즉시 실행 클로저** (IIFE, immediately-invoked closure) |
| `lazy var x: T = { ... }()` | **지연 저장 프로퍼티** (lazy stored property) |

즉시 실행 클로저 패턴은 다른 언어에서 **IIFE**(Immediately Invoked Function Expression)라 부른다. JavaScript에서 온 용어다.

### 더 나은 대안 — `lazy` 또는 인스턴스 프로퍼티

**진짜 문제는 이 코드가 매 호출마다 `NumberFormatter`를 만든다는 것이다.**

`formatRateForLocale`은 화면의 **환율 목록 모든 행에서 호출**된다. 통화가 24개면 `NumberFormatter`가 24개 만들어진다.

**`NumberFormatter` 생성은 비용이 있다.** 내부적으로 로케일 데이터를 로드하므로 반복 생성은 피하는 것이 좋다. 오래된 Apple 문서와 커뮤니티에서 널리 알려진 사실이다.

**개선 방향 세 가지**

**① 로케일별 캐싱**

`locale`이 통화 코드에 따라 달라지므로 하나로 재사용할 수 없다. 딕셔너리로 캐싱한다.

```swift
@ObservationIgnored
private var formatters: [String: NumberFormatter] = [:]

private func formatter(for currencyCode: String) -> NumberFormatter {
    if let cached = formatters[currencyCode] {
        return cached
    }
    let fm = NumberFormatter()
    fm.numberStyle = .currency
    fm.currencyCode = currencyCode        // locale 대신 currencyCode 직접 지정
    formatters[currencyCode] = fm
    return fm
}
```

**② `currencyCode`를 직접 쓴다 — 더 정확하다**

현재 코드는 통화 코드에서 로케일 식별자를 조합한다.

```swift
fm.locale = Locale(identifier: key.dropLast() + "_" + key.dropLast().uppercased())
// "KRW" → "kr_KR"
```

**이 조합이 항상 맞지 않는다.**

| 통화 | 조합 결과 | 유효한가 |
| --- | --- | --- |
| `KRW` | `kr_KR` | ⚠️ 언어 코드는 `ko`다 |
| `JPY` | `jp_JP` | ⚠️ 언어 코드는 `ja`다 |
| `USD` | `us_US` | ⚠️ 언어 코드는 `en`이다 |
| `GBP` | `gb_GB` | ⚠️ 언어 코드는 `en`이다 |

**앞 두 글자는 국가 코드이고 로케일의 첫 부분은 언어 코드**다. 서로 다르다. [국기 이모지 문서](./flag-emoji-from-unicode-scalars.md)에서 다룬 것과 같은 관례에 기댄 코드인데, 로케일에서는 통하지 않는다.

`NumberFormatter`는 무효한 로케일을 받으면 fallback을 쓰므로 크래시하지 않지만, **통화 기호가 의도와 다르게 표시될 수 있다.**

`currencyCode`를 직접 지정하는 편이 정확하다.

```swift
let fm = NumberFormatter()
fm.numberStyle = .currency
fm.currencyCode = "KRW"          // 통화만 지정, 표시 형식은 사용자 로케일
```

**③ `FormatStyle`로 옮긴다 — 현행 API**

iOS 15부터는 `NumberFormatter` 없이 쓸 수 있다.

```swift
rate.formatted(.currency(code: key))     // "₩1,583"
```

**한 줄이면 끝난다.** [Foundation 문서](./foundation-framework.md)에서 다룬 `FormatStyle` API다. 캐싱을 신경 쓸 필요도 없고, 내부적으로 최적화되어 있다.

### 강제 언래핑도 주의

```swift
return formatter.string(from: NSNumber(value: rate))!
```

`string(from:)`은 `String?`을 돌려준다. **`nil`이면 크래시한다.** 실무에서는 fallback을 두는 편이 안전하다.

```swift
return formatter.string(from: NSNumber(value: rate)) ?? "\(rate)"
```

### 정리

```text
NumberFormatter는 클래스다 (NSObject → Formatter → NumberFormatter)

var formatter: T { ... }는 클로저가 아니라 계산 프로퍼티다
  접근할 때마다 실행된다
  즉시 실행 클로저는 끝에 ()가 붙는다 — let x: T = { ... }()

함수 안 지역 계산 프로퍼티를 쓰는 이유
  여러 줄 설정을 한 블록에 묶어 범위를 명확히
  하지만 한 번만 쓰는 값이라면 과하다

이 코드의 실제 문제
  ① 매 호출마다 NumberFormatter 생성 (목록 행마다)
  ② locale 조합이 부정확 (KRW → kr_KR, 실제 언어 코드는 ko)
  ③ string(from:)의 강제 언래핑

개선: rate.formatted(.currency(code: key)) 한 줄
```

## 학습 체크리스트

- [ ] `var formatter: NumberFormatter { ... }`에 `print`를 넣어 몇 번 실행되는지 확인한다.
- [ ] `let formatter: NumberFormatter = { ... }()`로 바꿔 차이를 비교한다.
- [ ] 두 형태에서 `var`/`let` 사용 가능 여부를 확인한다.
- [ ] `get { }`을 명시적으로 써도 같은지 확인한다.
- [ ] `NumberFormatter`의 상속 계층을 정의로 점프해 확인한다.
- [ ] `Locale(identifier: "kr_KR")`과 `Locale(identifier: "ko_KR")`의 차이를 출력한다.
- [ ] `"KRW"`로 만든 로케일이 유효한지 `Locale.identifier`로 확인한다.
- [ ] `fm.currencyCode = "KRW"` 방식으로 바꿔 결과를 비교한다.
- [ ] `rate.formatted(.currency(code: "KRW"))`로 한 줄 대체를 시험한다.
- [ ] 목록 행 개수만큼 `NumberFormatter`가 생성되는지 로그로 확인한다.
- [ ] 로케일별 캐싱 딕셔너리를 만들어 생성 횟수를 줄여 본다.
- [ ] `string(from:)`이 `nil`을 돌려주는 경우를 만들어 크래시를 확인한다.

## 공식 참고 자료

- [Apple: NumberFormatter](https://developer.apple.com/documentation/foundation/numberformatter)
- [Apple: Formatter](https://developer.apple.com/documentation/foundation/formatter)
- [Apple: NumberFormatter.currencyCode](https://developer.apple.com/documentation/foundation/numberformatter/currencycode)
- [Apple: NumberFormatter.string(from:)](https://developer.apple.com/documentation/foundation/numberformatter/string(from:))
- [Apple: FormatStyle](https://developer.apple.com/documentation/foundation/formatstyle)
- [Apple: Numeric formatting — currency](https://developer.apple.com/documentation/foundation/formatstyle/currency)
- [Apple: Locale](https://developer.apple.com/documentation/foundation/locale)
- [Swift 공식 문서: Properties — Computed Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Computed-Properties)
- [Swift 공식 문서: Properties — Lazy Stored Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Lazy-Stored-Properties)
- [Swift 공식 문서: Properties — Shorthand Getter Declaration](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Shorthand-Getter-Declaration)
- [Swift 공식 문서: Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/)
