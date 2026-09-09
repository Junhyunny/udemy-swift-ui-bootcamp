# 타입에 붙는 `!` — 암시적 언래핑 옵셔널

옵셔널 바인딩은 [별도 문서](./if-conditions-and-optional-binding.md)에, API 모델의 옵셔널은 [여기](./optional-in-api-models.md)에 정리했다. 이 문서는 **`Type!` 선언**을 다룬다.

## 질문이 나온 코드

`chapter-94/chapter-94/ViewModels/TimerViewModel.swift`

```swift
// TODO, ! 키워드는 뭐야? 타입에 ? 이거는 옵셔널인거 알고 있는데 타입에 ! 가 붙는거는 처음 본다.
@Published var leftTime: Date!
```

## 공부할 내용

### 정체 — 암시적 언래핑 옵셔널

**`Date!`도 옵셔널이다.** `Date?`와 같은 타입이지만 **쓸 때 언래핑을 생략할 수 있다.**

Swift 공식 문서의 설명이다.

> Sometimes it's clear from a program's structure that an optional will *always* have a value, after that value is first set. In these cases, it's useful to remove the need to check and unwrap the optional's value every time it's accessed.
>
> These kinds of optionals are defined as *implicitly unwrapped optionals*. You write an implicitly unwrapped optional by placing an exclamation point (`String!`) rather than a question mark (`String?`) after the type.

**IUO**(Implicitly Unwrapped Optional)라 부른다.

**`!`의 위치가 중요하다.**

> Rather than placing an exclamation point after the optional's name when you use it, **you place an exclamation point after the optional's type when you declare it**.

```swift
var a: Date?        // 옵셔널 — 쓸 때 언래핑 필요
var b: Date!        // 암시적 언래핑 옵셔널 — 쓸 때 그냥 쓴다

print(a!.timeIntervalSince1970)    // ? 는 사용 시점에 !
print(b.timeIntervalSince1970)     // ! 는 선언 시점에 붙였으므로 생략
```

**선언에 붙이는 `!`와 사용할 때 붙이는 `!`는 다른 것**이다.

### 세 가지 비교

| 선언 | `nil` 가능 | 사용법 | `nil`일 때 접근 |
| --- | --- | --- | --- |
| `Date` | **불가** | `date` | — |
| `Date?` | 가능 | `date?.x` 또는 `date!.x` | 안전 (`?`) / 크래시 (`!`) |
| `Date!` | **가능** | `date.x` | **크래시** |

**핵심 위험**은 마지막 줄이다. `nil`인 상태에서 접근하면 **강제 언래핑과 똑같이 크래시한다.** 문법이 비옵셔널처럼 보여서 그 위험이 감춰진다.

```swift
var leftTime: Date!            // nil로 시작
let diff = Date().timeIntervalSince(leftTime)   // ⚠️ nil이면 크래시
```

### 이 코드에 실제 위험이 있다

`chapter_94App.swift`를 보면 이렇다.

```swift
if newValue == .active && viewModel.leftTime != nil {
    let diffInTime = Date().timeIntervalSince(viewModel.leftTime)
    //                                        ↑ IUO를 그냥 넘긴다
}
```

**`!= nil` 검사를 앞에서 해서 지금은 안전하다.** 하지만 이 검사를 빠뜨리거나 다른 곳에서 접근하면 크래시한다.

`timeIntervalSince`의 시그니처가 비옵셔널을 요구한다.

```swift
func timeIntervalSince(_ date: Date) -> TimeInterval
```

`Date!`가 자동으로 `Date`로 언래핑되어 통과하는 것이다. **컴파일러가 경고하지 않으므로 위험이 보이지 않는다.**

`resetView()`에서 `nil`로 되돌리는 것도 확인할 만하다.

```swift
func resetView() {
    // ...
    leftTime = nil          // 다시 nil이 된다
}
```

**즉 이 값은 실제로 `nil`이 되는 시점이 있다.** 공식 문서의 권고와 어긋난다.

> **Don't use an implicitly unwrapped optional when there's a possibility of a variable becoming `nil` at a later point.** Always use a normal optional type if you need to check for a `nil` value during the lifetime of a variable.

**이 경우는 `Date?`가 맞다.**

```swift
@Published var leftTime: Date?
```

호출부는 옵셔널 바인딩으로 처리한다.

```swift
if newValue == .active, let leftTime = viewModel.leftTime {
    let diffInTime = Date().timeIntervalSince(leftTime)
    // ...
}
```

[`if` 조건 결합](./if-conditions-and-optional-binding.md)에서 다룬 `,` 연결이고, **`!= nil` 검사와 값 사용을 한 번에** 처리한다. 검사를 빠뜨릴 여지가 없어진다.

### IUO가 정당한 경우

**Apple이 인정하는 용도가 있다.**

> Implicitly unwrapped optionals are useful when an optional's value is confirmed to exist immediately after the optional is first defined and can definitely be assumed to exist at every point thereafter. **The primary use of implicitly unwrapped optionals in Swift is during class initialization.**

**① 두 객체가 서로를 참조하는 초기화**

```swift
class Country {
    let name: String
    var capitalCity: City!        // init에서 아직 만들 수 없다

    init(name: String, capitalName: String) {
        self.name = name
        self.capitalCity = City(name: capitalName, country: self)
    }
}

class City {
    let name: String
    unowned let country: Country

    init(name: String, country: Country) {
        self.name = name
        self.country = country
    }
}
```

`City`가 `Country`를 필요로 하고 `Country`가 `City`를 필요로 하는 순환이다. IUO로 초기화 순서 문제를 푼다. [ARC 문서](./swift-memory-model.md)에서 다룬 `unowned`와 함께 쓰이는 패턴이다.

**② `@IBOutlet` — UIKit의 관례**

```swift
@IBOutlet weak var titleLabel: UILabel!
```

스토리보드가 로드된 뒤에 연결되므로 `init` 시점에는 `nil`이다. 하지만 뷰가 표시될 때는 항상 있다. **UIKit에서 가장 흔한 IUO 사용처다.**

**③ Objective-C API 브리징**

nullability 표기가 없는 Objective-C API는 Swift에서 IUO로 들어온다. [NS 접두사 문서](./ns-prefix-foundation-classes.md)에서 다룬 마찰 중 하나다.

**④ 테스트의 `setUp`**

```swift
final class MyTests: XCTestCase {
    var sut: MyService!        // setUp에서 만든다

    override func setUp() {
        sut = MyService()
    }
}
```

`setUp`이 항상 먼저 호출되므로 안전하다는 전제다. 다만 최근에는 옵셔널이나 `setUpWithError`를 쓰는 경우도 늘었다.

### SwiftUI에서는 거의 쓸 이유가 없다

`@State`, `@Published` 같은 프로퍼티는 **초기값을 갖는 것이 자연스럽다.**

```swift
@Published var time: Int = 0                    // ✅ 기본값
@Published var selectedTime: Int = 0            // ✅
@Published var leftTime: Date!                  // ⚠️ 왜 IUO인가?
```

같은 클래스의 다른 프로퍼티들은 모두 기본값을 갖는데 `leftTime`만 IUO다. **"값이 없는 상태"가 의미를 갖는 값이므로 `Date?`가 정확한 표현이다.**

- 타이머가 백그라운드로 간 적이 없다 → `nil`
- 백그라운드로 간 시각이 있다 → `Date`

**옵셔널이 이 두 상태를 타입으로 표현한다.** IUO는 그 구분을 흐린다.

### 판단 기준

```text
값이 나중에 nil이 될 수 있는가?
  예 → Date?  (일반 옵셔널)          ← 이 예제가 여기 해당
  아니오 → ②

초기화 직후 반드시 설정되고 이후 항상 존재하는가?
  예 → Date!  (IUO)  — 초기화 순환, @IBOutlet, 테스트 setUp
  아니오 → Date?
```

**한 문장으로 줄이면 이렇다. "`nil`이 될 수 있으면 `?`, 초기화 직후 확정되고 끝까지 유지되면 `!`."**

### 정리

```text
Type! = 암시적 언래핑 옵셔널 (IUO)
  Type?와 같은 옵셔널이지만 쓸 때 언래핑을 생략한다
  ! 위치가 다르다 — 선언 시점(타입 뒤) vs 사용 시점(값 뒤)

위험
  nil일 때 접근하면 강제 언래핑처럼 크래시
  비옵셔널처럼 보여서 위험이 감춰진다

정당한 용도
  초기화 순환 (Country ↔ City)
  @IBOutlet
  Objective-C 브리징
  테스트 setUp

이 코드는 부적합
  resetView()에서 nil로 되돌리므로 "나중에 nil이 될 수 있다"
  Apple 문서가 이 경우 일반 옵셔널을 쓰라고 명시한다
  → Date?로 바꾸고 if let으로 처리
```

## 학습 체크리스트

- [ ] `leftTime`이 `nil`인 상태에서 `timeIntervalSince(leftTime)`를 호출해 크래시를 재현한다.
- [ ] `chapter_94App`의 `!= nil` 검사를 지우고 크래시가 나는지 확인한다.
- [ ] `Date!`를 `Date?`로 바꾸고 어떤 컴파일 에러가 나는지 본다.
- [ ] `if newValue == .active, let leftTime = viewModel.leftTime`으로 고쳐 본다.
- [ ] `print(type(of: leftTime))`으로 실제 타입을 확인한다 (`Optional<Date>`).
- [ ] `leftTime == nil` 비교가 되는지 확인한다 (옵셔널이므로 가능하다).
- [ ] `leftTime?.timeIntervalSince1970`처럼 `?`를 붙여도 되는지 확인한다.
- [ ] `Country` ↔ `City` 초기화 순환 예제를 직접 작성해 IUO가 필요한 이유를 체감한다.
- [ ] 테스트 클래스에서 `var sut: MyService!` 패턴을 써 본다.
- [ ] `Date!`와 `Date?`를 함수 파라미터에 넘길 때의 차이를 확인한다.

## 공식 참고 자료

- [Swift 공식 문서: The Basics — Implicitly Unwrapped Optionals](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Implicitly-Unwrapped-Optionals)
- [Swift 공식 문서: The Basics — Optionals](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals)
- [Swift 공식 문서: The Basics — Optional Binding](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optional-Binding)
- [Swift 공식 문서: ARC — Unowned References and Implicitly Unwrapped Optional Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Unowned-References-and-Implicitly-Unwrapped-Optional-Properties)
- [Swift 공식 문서: Types — Optional Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Optional-Type)
- [Swift 공식 문서: Types — Implicitly Unwrapped Optional Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Implicitly-Unwrapped-Optional-Type)
- [Apple: Optional](https://developer.apple.com/documentation/swift/optional)
- [Apple: Date.timeIntervalSince(_:)](https://developer.apple.com/documentation/foundation/date/timeintervalsince(_:))
