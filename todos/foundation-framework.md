# `Foundation` 모듈에는 무엇이 들어 있나

`NS` 접두사의 유래는 [별도 문서](./ns-prefix-foundation-classes.md)에 정리했다. 이 문서는 **Foundation 프레임워크의 구성**을 다룬다.

## 질문이 나온 코드

`chapter-69/chapter-69/Course.swift`

```swift
import Foundation

struct Course: Identifiable {
    let id = UUID().uuidString
    var title: String
    var publishedDate: Date
    // ...
}
```

## 공부할 내용

### 무엇을 하는 프레임워크인가

> The Foundation framework provides a **base layer of functionality** for apps and frameworks, including data storage and persistence, text processing, date and time calculations, sorting and filtering, and networking. The classes, protocols, and data types defined by Foundation are used throughout the macOS, iOS, watchOS, and tvOS SDKs.

**UI가 아닌 모든 기본 기능의 토대**다. Swift 표준 라이브러리가 언어 차원의 기본(`Int`, `Array`, `String`)을 제공한다면, Foundation은 **앱을 만드는 데 필요한 실용 기능**을 제공한다.

```text
SwiftUI / UIKit      화면
      ↓
Foundation           날짜, 파일, 네트워크, 데이터  ← 여기
      ↓
Swift 표준 라이브러리   Int, String, Array, 프로토콜
```

### 무엇이 들어 있나 — 공식 분류

Apple 문서의 목차를 따라가면 이렇다.

**① Fundamentals — 기본 값 타입**

| 영역 | 주요 타입 |
| --- | --- |
| Numbers, Data, and Basic Values | `Data`, `UUID`, `NSNumber`, `Decimal` |
| Strings and Text | `String` 확장, `NSAttributedString`, `NSRegularExpression`, `Scanner` |
| Collections | `NSCache`, `IndexSet`, `NSOrderedSet` |
| **Dates and Times** | **`Date`, `Calendar`, `TimeZone`, `DateComponents`** |
| Units and Measurement | `Measurement`, `UnitLength`, `UnitMass` |
| **Data Formatting** | **`DateFormatter`, `NumberFormatter`, `FormatStyle`** |
| Filters and Sorting | `NSPredicate`, `SortDescriptor` |

**② App Support**

`Timer`, `Bundle`, `NotificationCenter`, `UserDefaults`, `NSError`, `Progress`, `Operation`, `OperationQueue`

**③ Files and Data Persistence**

`FileManager`, `URL`, `JSONEncoder`/`JSONDecoder`, `PropertyListEncoder`, `NSKeyedArchiver`

**④ Networking**

`URLSession`, `URLRequest`, `URLResponse`, `URLComponents`, `URLCache`

**⑤ Low-Level Utilities**

`Thread`, `Process`, `Pipe`, `Stream`, `NSLock`, XPC

### 이 파일이 Foundation을 import하는 이유

`Course.swift`에서 실제로 쓰는 것은 둘이다.

```swift
let id = UUID().uuidString       // ← UUID가 Foundation
var publishedDate: Date          // ← Date가 Foundation
```

**`UUID`와 `Date` 모두 Swift 표준 라이브러리가 아니라 Foundation 소속**이다. 그래서 `import Foundation`이 필요하다.

`String`, `Double`, `Identifiable`은 표준 라이브러리라 import 없이도 쓸 수 있다.

### `import SwiftUI`만 있으면 되지 않나

**대부분의 경우 맞다.** SwiftUI가 Foundation을 재수출(re-export)하므로, `import SwiftUI`만 써도 `Date`와 `UUID`를 쓸 수 있다.

같은 프로젝트의 다른 파일들이 그 증거다.

```swift
// CourseCardView.swift
import SwiftUI                   // Foundation import 없이

Text(course.publishedDate.formatted(date: .abbreviated, time: .omitted))
```

`Date`의 `formatted`를 쓰는데도 `import Foundation`이 없다.

**그럼에도 `Course.swift`에서 Foundation을 명시하는 것은 좋은 선택이다.**

- **이 파일은 UI 코드가 아니다.** 순수 데이터 모델이므로 SwiftUI에 의존할 이유가 없다
- **의존성이 정확히 드러난다.** 나중에 이 모델을 다른 플랫폼이나 서버 코드에서 재사용하기 쉬워진다
- **재수출은 보장이 아니다.** 프레임워크 구현 세부사항에 의존하지 않는 편이 안전하다

**반대로 `Category.swift`는 import가 하나도 없다.**

```swift
enum Category: String {
    case swiftUI = "SwiftUI"
    // ...
}
```

`String`과 `enum`만 쓰므로 표준 라이브러리로 충분하다. 필요 없는 import를 넣지 않은 것이 맞다.

### 자주 쓰게 되는 Foundation 기능

이 프로젝트에서 실제로 쓰이거나 쓰일 만한 것들이다.

**날짜와 포매팅**

```swift
var publishedDate: Date
course.publishedDate.formatted(date: .abbreviated, time: .omitted)
```

`Date`는 **시점(point in time)** 을 나타내는 값이다. 표시 형식은 `Calendar`, `TimeZone`, `Locale`에 따라 달라지므로 별도로 계산한다. [`@Environment`의 `\.locale`, `\.calendar`](./environment-property-wrapper.md)가 이것과 연결된다.

**숫자 포매팅**

이 프로젝트의 `DoubleExtension.swift`가 그 예다.

```swift
// 가격 표시 같은 곳
price.formatted(.currency(code: "USD"))
```

`FormatStyle` API가 구형 `NumberFormatter`를 대체한다.

**고유 식별자**

```swift
let id = UUID().uuidString
```

`UUID`는 충돌 가능성이 사실상 없는 128비트 식별자다. 다만 **호출할 때마다 새 값이 생성**되므로 주의가 필요하다. [static 프로퍼티 문서](./static-stored-vs-computed-property.md)에서 다룬 함정이고, 이 프로젝트도 같은 구조다.

```swift
static var sample: [Course] {      // 계산 프로퍼티 — 매번 새 배열
    [ Course(...), ... ]           // 매번 새 UUID
}
```

[id 중복 문서](./duplicate-id-in-list.md)에서 이어서 다룬다.

**JSON 인코딩·디코딩**

[Codable 문서](./codable-and-codingkey.md)에서 다룬 `JSONDecoder`도 Foundation이다.

**네트워킹**

`URLSession`, `URLRequest` 모두 Foundation이다. [chapter-61의 네트워킹 코드](./swift-generics.md)가 이것을 썼다.

### Swift 표준 라이브러리와의 경계

헷갈리기 쉬운 구분이다.

| 표준 라이브러리 | Foundation |
| --- | --- |
| `Int`, `Double`, `Bool` | `Decimal`, `NSNumber` |
| `String`, `Character` | `NSAttributedString`, `NSRegularExpression` |
| `Array`, `Dictionary`, `Set` | `NSCache`, `IndexSet` |
| `Optional`, `Result` | `NSError` |
| `Codable` 프로토콜 | `JSONEncoder` (구현체) |
| — | **`Date`, `UUID`, `URL`, `Data`** |

**`Codable`은 표준 라이브러리, `JSONEncoder`는 Foundation**이라는 점이 흥미롭다. 프로토콜은 언어 차원에 두고 구체 구현은 프레임워크에 둔 구조다.

### 플랫폼 이야기

Foundation은 원래 Objective-C 프레임워크였고, 지금은 **swift-corelibs-foundation**으로 Linux에서도 쓸 수 있다. 서버 사이드 Swift(Vapor 등)가 Foundation을 쓰는 이유다.

다만 플랫폼별로 구현이 완전히 동일하지는 않다. 최근에는 Swift로 다시 작성한 **swift-foundation**이 진행되어 성능과 일관성이 개선되고 있다.

`import Foundation`을 명시하는 것이 이런 이식성 측면에서도 의미가 있다.

### 정리

```text
Foundation = UI가 아닌 기본 기능의 토대

주요 영역
  기본 값       Data, UUID, Decimal
  날짜·시간     Date, Calendar, TimeZone
  포매팅        FormatStyle, DateFormatter
  파일·저장     FileManager, URL, JSONEncoder
  네트워킹      URLSession, URLRequest
  앱 지원       Timer, Bundle, NotificationCenter, UserDefaults

이 파일이 import하는 이유
  UUID와 Date가 Foundation 소속

SwiftUI가 재수출하므로 생략해도 동작하지만
  데이터 모델 파일에서는 명시하는 편이 낫다
```

## 학습 체크리스트

- [ ] `Course.swift`에서 `import Foundation`을 지우고 어떤 에러가 나는지 확인한다.
- [ ] `import SwiftUI`로 바꿔도 컴파일되는지 확인한다 (재수출).
- [ ] `Category.swift`에 import가 없어도 되는 이유를 설명한다.
- [ ] `UUID()`를 두 번 호출해 서로 다른 값이 나오는 것을 확인한다.
- [ ] `Date()`를 출력하고 `formatted()`로 형식을 바꿔 본다.
- [ ] `formatted(date:time:)`의 여러 조합을 시험한다.
- [ ] `Locale`을 바꿔 같은 `Date`가 다르게 표시되는지 확인한다.
- [ ] `price.formatted(.currency(code: "USD"))`로 통화 형식을 적용해 본다.
- [ ] `Decimal`과 `Double`의 차이를 금액 계산 관점에서 알아본다.
- [ ] `Bundle.main`으로 앱 정보를 읽어 본다.
- [ ] `UserDefaults`에 값을 저장하고 읽어 본다.
- [ ] 표준 라이브러리 타입과 Foundation 타입을 각각 5개씩 구분해 나열한다.

## 공식 참고 자료

- [Apple: Foundation](https://developer.apple.com/documentation/foundation)
- [Apple: Numbers, Data, and Basic Values](https://developer.apple.com/documentation/foundation/numbers-data-and-basic-values)
- [Apple: Dates and Times](https://developer.apple.com/documentation/foundation/dates-and-times)
- [Apple: Data Formatting](https://developer.apple.com/documentation/foundation/data-formatting)
- [Apple: Strings and Text](https://developer.apple.com/documentation/foundation/strings-and-text)
- [Apple: File System](https://developer.apple.com/documentation/foundation/file-system)
- [Apple: URL Loading System](https://developer.apple.com/documentation/foundation/url-loading-system)
- [Apple: Archives and Serialization](https://developer.apple.com/documentation/foundation/archives-and-serialization)
- [Apple: Date](https://developer.apple.com/documentation/foundation/date)
- [Apple: UUID](https://developer.apple.com/documentation/foundation/uuid)
- [Apple: FormatStyle](https://developer.apple.com/documentation/foundation/formatstyle)
- [Apple: Swift Standard Library](https://developer.apple.com/documentation/swift/swift-standard-library)
- [swift-corelibs-foundation (GitHub)](https://github.com/swiftlang/swift-corelibs-foundation)
- [swift-foundation (GitHub)](https://github.com/swiftlang/swift-foundation)
