# SwiftData `@Model`은 왜 class이고 `final`은 필수인가

`final` 자체의 전체 문법과 일반적인 장단점은 [`final` 키워드 학습 노트](./final-keyword.md)에 정리되어 있다. 이 문서는 **SwiftData model과 연결되는 부분**에 집중한다.

## 질문이 나온 코드

`chapter-110/chapter-110/Grocery.swift`

```swift
@Model
final class Grocery {
    var name: String
    var desc: String
}
```

질문은 두 가지다.

1. SwiftData model은 반드시 class여야 하는가?
2. 그 class는 반드시 `final`이어야 하는가?

## 공부할 내용

### 결론

- SwiftData의 `@Model`은 **class에 적용한다.** `struct`와 `enum`에는 적용할 수 없다.
- `final`은 **필수가 아니다.** 상속하지 않을 model에 설계 의도를 표현하기 위해 흔히 붙인다.
- iOS 26부터 SwiftData model inheritance가 도입되어, 실제 상속 모델을 설계한다면 base class는 `final`일 수 없다.
- 최소 지원 OS가 iOS 17~18이고 상속이 필요 없다면 `@Model final class`가 가장 단순한 형태다.

### `@Model`을 붙여야 SwiftData model이다

일반 class에 `SwiftData`를 import하고 `@Model` macro를 적용하면 persistence schema에 참여한다.

```swift
import SwiftData

@Model
final class Grocery {
    var name: String
    var desc: String

    init(name: String, desc: String) {
        self.name = name
        self.desc = desc
    }
}
```

`@Model`은 stored property를 persistence schema에 포함시키고, change tracking과 Observation에 필요한 코드를 생성한다.

### 왜 class만 가능한가

SwiftData의 `PersistentModel` 프로토콜은 `AnyObject`를 상속한다.

```swift
public protocol PersistentModel: AnyObject, Observable, Hashable, Identifiable {
    // 축약
}
```

`AnyObject` 제약은 class instance만 이 프로토콜을 준수할 수 있다는 뜻이다. 따라서 다음 코드는 허용되지 않는다.

```swift
@Model
struct Grocery { // 컴파일 오류
    var name: String
}
```

persistent model에는 저장소 안에서 유지되는 identity가 있다. 여러 View나 relationship이 같은 model instance를 가리키고, context가 그 instance의 property 변경을 추적한다. 복사할 때 별도 값이 되는 struct보다 identity와 공유 변경을 가진 reference type이 이 모델에 맞는다.

```text
ModelContext
    │
    ├── Grocery instance A ── identity A
    └── Grocery instance B ── identity B

여러 관계와 View가 A를 참조
      → A의 변경을 context가 추적
```

class를 요구한다는 말은 앱의 모든 domain model도 class여야 한다는 뜻이 아니다. 네트워크 DTO, 화면 상태, command와 value object는 struct로 두고 persistence boundary의 `@Model` 타입만 class로 만드는 설계가 가능하다.

### `final`은 무엇을 추가하는가

```swift
@Model
final class Grocery { }
```

`final`은 SwiftData 기능을 켜는 키워드가 아니다. 이 class를 상속할 수 없게 만들어 “이 model은 subclass 확장점이 아니다”라는 설계 의도를 표현한다.

장점은 다음과 같다.

- 예상하지 않은 subclass와 override를 컴파일 단계에서 막는다.
- model schema가 상속으로 확장되지 않는다는 의도가 선명하다.
- compiler가 dynamic dispatch를 줄이는 최적화를 적용할 여지를 준다.

성능 이점은 가능한 최적화이지 `final` 하나만으로 앱이나 query가 빨라진다는 보장은 아니다. SwiftData 앱에서의 주된 성능 비용은 보통 fetch 범위, index, relationship 접근, save 빈도와 I/O에 있다.

### `final`은 필수가 아니다

`@Model` macro와 `PersistentModel` 프로토콜의 public contract에는 `final` 요구가 없다.

```swift
@Model
class Grocery {
    var name: String

    init(name: String) {
        self.name = name
    }
}
```

이처럼 non-final model을 선언할 수 있다. 다만 “문법상 non-final”과 “모든 OS 버전에서 model inheritance를 지원”은 다른 말이다.

### model inheritance와 OS 버전

Apple은 iOS 26 세대의 SwiftData에 class inheritance 기반 model graph를 추가했다. base model과 subclass를 schema에 포함해 공통 필드와 subtype별 필드를 표현할 수 있다.

```swift
@Model
class GroceryItem {
    var name: String

    init(name: String) {
        self.name = name
    }
}

@Model
final class RefrigeratedItem: GroceryItem {
    var minimumTemperature: Double

    init(name: String, minimumTemperature: Double) {
        self.minimumTemperature = minimumTemperature
        super.init(name: name)
    }
}
```

이 기능을 사용하면 base인 `GroceryItem`은 `final`일 수 없고 leaf subclass에는 `final`을 붙일 수 있다.

deployment target이 iOS 17이나 18이라면 iOS 26의 model inheritance에 의존할 수 없다. 단순히 코드가 현재 Xcode에서 compile되는지만 보지 말고 API availability와 실제 최소 OS를 확인해야 한다.

### 상속보다 composition이 나은 경우

상속을 지원하는 OS에서도 subtype 관계가 명확하지 않다면 relationship과 value composition이 더 단순할 수 있다.

```swift
@Model
final class Grocery {
    var name: String
    var storage: StorageRequirement?
}

@Model
final class StorageRequirement {
    var minimumTemperature: Double?
}
```

다음 질문으로 판단한다.

- 모든 subclass가 base의 의미를 정말 만족하는가?
- base type으로 함께 query해야 하는가?
- subtype 추가가 schema migration에 어떤 영향을 주는가?
- 단순 relationship으로 표현하는 편이 delete rule과 lifecycle을 이해하기 쉬운가?

### 테스트할 때 `final`이 불편하지 않은가

model을 subclass해서 mock으로 바꾸는 테스트 방식은 `final`과 충돌한다. 하지만 persistence test에서는 상속 mock보다 in-memory `ModelContainer`를 사용하는 편이 실제 SwiftData 동작을 더 정확히 검증한다.

```swift
let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: Grocery.self,
    configurations: configuration
)
```

service 교체가 필요하면 model을 상속하기보다 repository나 store protocol을 주입한다.

## 체크리스트

- [ ] `@Model struct Grocery`를 시도해 macro 오류를 읽는다.
- [ ] `PersistentModel`의 `AnyObject` 제약이 무엇을 뜻하는지 설명한다.
- [ ] `final`을 제거해도 기본 `@Model` 선언이 가능한지 확인한다.
- [ ] `final class`를 상속하려 할 때 발생하는 compiler 오류를 확인한다.
- [ ] iOS 26 model inheritance 예제를 iOS 26 target과 더 낮은 target에서 비교한다.
- [ ] 상속과 relationship composition으로 냉장 식품 모델을 각각 설계한다.
- [ ] in-memory `ModelContainer`로 `Grocery` insert와 fetch test를 작성한다.
- [ ] persistence model은 class로 두고 DTO와 화면 상태는 struct로 분리한다.

## 공식 참고 자료

- [Apple: Model() macro](https://developer.apple.com/documentation/swiftdata/model())
- [Apple: PersistentModel](https://developer.apple.com/documentation/swiftdata/persistentmodel)
- [Apple WWDC23: Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/)
- [Apple WWDC25: SwiftData — Dive into inheritance and schema migration](https://developer.apple.com/videos/play/wwdc2025/291/)
- [Swift 공식 문서: Classes and Structures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
- [Swift 공식 문서: Preventing Overrides](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/inheritance/#Preventing-Overrides)
