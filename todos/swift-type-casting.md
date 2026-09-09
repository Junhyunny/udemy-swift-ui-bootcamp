# Swift의 형변환 — `as?`, `as!`, `as`, `is`

`.self` 메타타입은 [별도 문서](./metatype-and-self.md)에, 옵셔널 바인딩은 [여기](./if-conditions-and-optional-binding.md)에 정리했다. 이 문서는 **타입 캐스팅**을 다룬다.

## 질문이 나온 코드

`chapter-65/chapter-65/ContentView.swift`

```swift
if let userInfo = notification.userInfo,
   let moreInfo = userInfo["Course"] as? DTCourse
{
    await MainActor.run {
        additionalInfo = "\(moreInfo.name) by: \(moreInfo.author)"
    }
}
```

```swift
if let device = notification.object as? UIDevice { ... }
```

## 공부할 내용

### 질문 확인 — 이해가 정확하다

> `as?`는 형변환을 시도해보고 에러가 발생하면 `moreInfo`가 nil이 되고 if 구문을 만족할 수 없어서 실행되지 않는건가?

**맞다.** 다만 "에러가 발생한다"는 표현만 다듬으면 완벽하다. **에러가 던져지는 것이 아니라 `nil`을 반환한다.**

Swift 공식 문서의 설명이다.

> Because downcasting can fail, the type cast operator comes in two different forms. **The conditional form, `as?`, returns an optional value of the type you are trying to downcast to.** The forced form, `as!`, attempts the downcast and force-unwraps the result as a single compound action.
>
> Use the conditional form of the type cast operator (`as?`) when you aren't sure if the downcast will succeed. **This form of the operator will always return an optional value, and the value will be `nil` if the downcast was not possible.**

즉 흐름이 이렇다.

```text
userInfo["Course"]           → Any? 타입의 값
        ↓
as? DTCourse                 → DTCourse? (성공하면 값, 실패하면 nil)
        ↓
let moreInfo = ...           → 옵셔널 바인딩
        ↓
nil이면 → if 본문을 건너뛴다
값이면 → moreInfo는 DTCourse (옵셔널 아님)
```

`throw`나 `do-catch`가 관여하지 않는다. [오류 처리](./swift-error-handling-forms.md)와는 별개의 메커니즘이다.

### 질문 확인: `moreInfo`가 항상 있다고 보장할 수 있는가

**보장할 수 없다. 그래서 `as?`를 쓴 것이다.**

`userInfo`는 `[AnyHashable: Any]?` 타입이라 두 가지가 불확실하다.

1. **`"Course"` 키가 있는가** — 딕셔너리 조회는 항상 옵셔널을 돌려준다
2. **그 값이 `DTCourse`인가** — 값 타입이 `Any`라 무엇이든 들어올 수 있다

이 예제는 같은 파일 안에서 보내고 받으므로 사실상 확실하다. 하지만 **`NotificationCenter`는 누구나 같은 이름으로 알림을 보낼 수 있는 구조**다([NotificationCenter 문서](./notification-center.md) 참조). 다른 코드가 `"Course"`에 `String`을 넣어 보낼 수도 있다.

주석 처리된 줄이 그 가능성을 보여 준다.

```swift
let additionalInfo = [
    // "Course": "Practical SwiftData in SwiftUI"    ← String이었다면
    "Course": course                                  //  DTCourse
]
```

이 주석을 살리면 `as? DTCourse`가 `nil`이 되어 `if` 본문이 실행되지 않는다. **크래시 없이 조용히 넘어간다** — 이것이 `as?`의 가치다.

### 네 가지 캐스팅 연산자

| 연산자 | 결과 | 실패 시 |
| --- | --- | --- |
| `as?` | 옵셔널 (`T?`) | **`nil` 반환** |
| `as!` | 비옵셔널 (`T`) | **런타임 크래시** |
| `as` | 비옵셔널 (`T`) | **컴파일 에러** (실패할 수 없을 때만) |
| `is` | `Bool` | `false` |

**① `as?` — 조건부 캐스팅 (가장 안전)**

```swift
if let device = notification.object as? UIDevice { ... }
```

실패 가능성이 있으면 이것을 쓴다. **기본 선택지다.**

**② `as!` — 강제 캐스팅**

> Use the forced form of the type cast operator (`as!`) only when you are sure that the downcast will always succeed. **This form of the operator will trigger a runtime error** if you try to downcast to an incorrect class type.

`URL(string:)!`과 같은 위험을 갖는다([AsyncImage 문서](./async-image.md)에서 다룬 크래시). **확신이 있어도 `as?` + `guard`가 낫다.**

**③ `as` — 업캐스팅과 브리징**

실패할 수 없는 변환에만 쓴다.

```swift
let value: Any = 42 as Any           // 업캐스팅 — 항상 성공
let nsString = "hello" as NSString   // 브리징
let double = 3 as Double             // 리터럴 타입 지정
```

하위 타입 → 상위 타입은 항상 성공하므로 `as`로 충분하다. 반대 방향(다운캐스팅)에 `as`를 쓰면 컴파일 에러다.

**④ `is` — 타입 확인만**

```swift
if notification.object is UIDevice {
    // 값은 필요 없고 타입만 확인
}
```

값을 쓰지 않을 때 쓴다. `switch`에서도 유용하다.

```swift
switch value {
case is String:  print("문자열")
case is Int:     print("정수")
default:         break
}
```

### 어떤 캐스팅이 가능한가

**① 클래스 계층의 다운캐스팅 — 원래 용도**

```swift
let responses: [URLResponse] = [...]
if let http = response as? HTTPURLResponse {
    print(http.statusCode)      // HTTPURLResponse에만 있는 프로퍼티
}
```

[chapter-61의 상태 코드 검사](./if-conditions-and-optional-binding.md)가 이 경우였다.

**② `Any`/`AnyObject`에서 구체 타입으로 — 이 예제**

```swift
let value: Any = DTCourse(name: "...", author: "...")
if let course = value as? DTCourse { ... }
```

`Any`는 모든 타입을 담을 수 있으므로 꺼낼 때 캐스팅이 필요하다.

**③ 프로토콜 준수 확인**

```swift
if let codable = value as? Codable { ... }
if value is Identifiable { ... }
```

**④ Objective-C 브리징**

```swift
let str = "hello" as NSString
let arr = nsArray as? [String]
```

[NS 접두사 문서](./ns-prefix-foundation-classes.md)에서 다룬 값 타입 ↔ 참조 타입 대응이다.

### 캐스팅이 안 되는 경우

**서로 관계없는 타입끼리는 변환되지 않는다.**

```swift
let number = 42
let text = number as? String        // ⚠️ 항상 nil (경고도 뜬다)
```

`Int`와 `String`은 상속 관계도 아니고 브리징 대상도 아니다. **캐스팅은 "타입을 바꾸는 것"이 아니라 "이미 그 타입인지 확인하는 것"** 이다.

값을 실제로 변환하려면 이니셜라이저를 쓴다.

```swift
let text = String(number)           // "42"
let number = Int("42")              // Optional(42)
let double = Double(intValue)       // 명시적 변환
```

이 구분이 중요하다. [CGFloat 문서](./coregraphics-types-and-cgfloat.md)에서 다룬 `CGFloat(columns)`도 캐스팅이 아니라 이니셜라이저 호출이다.

| | 캐스팅 (`as?`) | 변환 (이니셜라이저) |
| --- | --- | --- |
| 하는 일 | **이미 그 타입인지 확인** | **새 값을 만든다** |
| 메모리 | 같은 값을 다르게 본다 | 새로 생성 |
| 예 | `value as? DTCourse` | `String(42)` |

### `Any`와 `AnyObject`

```swift
let anything: Any = ...        // 모든 타입 (struct, enum, 함수 포함)
let object: AnyObject = ...    // 클래스 인스턴스만
```

`userInfo`가 `[AnyHashable: Any]`인 이유는 **무엇이든 담을 수 있어야** 하기 때문이다. [NotificationCenter 문서](./notification-center.md)에서 다룬 대로 `Codable` 같은 제약이 없다.

**`Any`는 편리하지만 타입 안전성을 포기하는 것이다.** 꺼낼 때마다 캐스팅해야 하고, 컴파일러가 검증해 주지 않는다. 가능하면 구체 타입이나 제네릭을 쓰는 편이 낫다([제네릭 문서](./swift-generics.md) 참조).

### 실무 권장 패턴

**① `guard`로 조기 탈출**

```swift
guard let course = userInfo["Course"] as? DTCourse else { return }
// 이후 course를 계속 쓸 수 있다
```

[`guard` 문서](./guard-keyword.md)에서 다룬 대로 바인딩이 이후 스코프까지 살아남는다.

**② 옵셔널 체이닝과 조합**

```swift
if let course = notification.userInfo?["Course"] as? DTCourse { ... }
```

`userInfo`가 옵셔널이므로 `?.`로 이어 쓸 수 있다. 이 예제는 두 단계를 `,`로 나눴는데, 옵셔널 체이닝을 쓰면 한 줄이 된다.

```swift
// 현재
if let userInfo = notification.userInfo,
   let moreInfo = userInfo["Course"] as? DTCourse { ... }

// 축약
if let moreInfo = notification.userInfo?["Course"] as? DTCourse { ... }
```

**③ 캐스팅 실패를 로그로 남긴다**

조용히 넘어가는 것이 항상 좋지는 않다. 디버깅 시 원인을 알 수 없다.

```swift
if let course = userInfo["Course"] as? DTCourse {
    // 정상 처리
} else {
    print("⚠️ Course 캐스팅 실패:", userInfo["Course"] ?? "키 없음")
}
```

**④ `as!`는 피한다**

확신이 있더라도 `as?` + `guard`로 대체할 수 있다. 크래시보다 무시나 로그가 낫다.

### 정리

```text
as?   실패하면 nil — 기본 선택지
as!   실패하면 크래시 — 피한다
as    실패할 수 없을 때만 (업캐스팅, 브리징)
is    타입 확인만, Bool 반환

에러를 던지는 것이 아니라 nil을 반환한다
  → do-catch가 아니라 옵셔널 바인딩으로 처리

캐스팅 ≠ 변환
  as?          이미 그 타입인지 확인
  String(42)   새 값을 생성

Any에서 꺼낼 때는 항상 캐스팅이 필요하다
  타입 안전성을 잃으므로 가능하면 구체 타입/제네릭
```

## 학습 체크리스트

- [ ] `userInfo["Course"]`에 `String`을 넣고 `as? DTCourse`가 `nil`이 되는지 확인한다.
- [ ] 그 상태에서 `if` 본문이 실행되지 않는 것을 확인한다.
- [ ] 주석 처리된 `"Course": "Practical SwiftData in SwiftUI"`를 되살려 동작을 관찰한다.
- [ ] `as?`를 `as!`로 바꾸고 타입이 안 맞을 때 크래시하는 것을 확인한다.
- [ ] `userInfo["없는키"] as? DTCourse`가 `nil`인 것을 확인한다.
- [ ] `notification.object is UIDevice`로 타입만 확인해 본다.
- [ ] `let text = 42 as? String`을 써서 경고와 `nil`을 확인한다.
- [ ] `String(42)`와 `42 as? String`의 차이를 설명한다.
- [ ] 두 단계 `if let`을 옵셔널 체이닝 한 줄로 줄여 본다.
- [ ] `guard let ... as? ... else { return }`으로 바꿔 스코프 차이를 확인한다.
- [ ] `switch value { case is String: ... }` 패턴을 써 본다.
- [ ] `Any` 배열에 서로 다른 타입을 담고 `for`로 순회하며 캐스팅해 본다.
- [ ] `"hello" as NSString`처럼 브리징을 시험한다.
- [ ] 캐스팅 실패 시 `else`에서 로그를 남기도록 고쳐 본다.

## 공식 참고 자료

- [Swift 공식 문서: Type Casting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/typecasting/)
- [Swift 공식 문서: Type Casting — Downcasting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/typecasting/#Downcasting)
- [Swift 공식 문서: Type Casting — Checking Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/typecasting/#Checking-Type)
- [Swift 공식 문서: Type Casting — Type Casting for Any and AnyObject](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/typecasting/#Type-Casting-for-Any-and-AnyObject)
- [Swift 공식 문서: Expressions — Type-Casting Operators](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Type-Casting-Operators)
- [Swift 공식 문서: Types — Any Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Any-Type)
- [Swift 공식 문서: The Basics — Optional Binding](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optional-Binding)
- [Apple: Notification.userInfo](https://developer.apple.com/documentation/foundation/notification/userinfo)
- [Apple: AnyHashable](https://developer.apple.com/documentation/swift/anyhashable)
