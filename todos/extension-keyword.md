# `extension` 키워드는 무엇이고 언제 쓰는가

Swift의 타입·상속 체계 전반은 [Swift의 타입 체계와 상속 구조](./swift-type-system-and-inheritance.md)에 정리돼 있다. 이 문서는 `extension` 하나에 집중한다.

## 질문이 나온 코드

`chapter-34/chapter-34/ContentView.swift`의 `extension DTCourse { static var sample: [DTCourse] { ... } }`

`chapter-47/chapter-47/ContentView.swift`는 `View` 프로토콜 자체를 확장한다.

```swift
extension View {
    func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
        modifier(MeasuringSizeModifier())
            .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
}
```

이 확장은 전역으로 적용되는가? 다른 파일에서도 보이는가? 그러면 파일은 어떻게 관리해야 하는가?

## 공부할 내용

### 기존 타입에 기능을 덧붙이는 문법이다

> "Extensions add new functionality to an existing class, structure, enumeration, or protocol type. This includes the ability to extend types for which you don't have access to the original source code (known as retroactive modeling)."

원본 선언을 건드리지 않고 나중에 기능을 추가한다. **소스 코드가 없는 타입에도 쓸 수 있다는 것**이 핵심이다. `String`, `Int`, `Date` 같은 표준 라이브러리 타입에 내 메서드를 붙일 수 있는 이유가 이것이다.

```swift
extension SomeType {
    // 여기에 새 기능
}

extension SomeType: SomeProtocol {
    // 프로토콜 준수도 나중에 추가할 수 있다
}
```

Objective-C의 category와 비슷하지만 이름이 없다.

### 무엇을 추가할 수 있나

- computed instance property, computed **type** property
- 인스턴스 메서드, 타입 메서드
- 초기화 메서드
- subscript
- 중첩 타입
- 프로토콜 준수

### 무엇을 할 수 없나 — 여기가 중요하다

> "Extensions can add new computed properties, but they can't add stored properties, or add property observers to existing properties."

**저장 프로퍼티를 추가할 수 없다.** 그래서 `extension`에 쓰는 프로퍼티는 항상 계산 프로퍼티다. 지금 코드의 `static var sample`도 `{ ... }` 블록을 가진 계산 프로퍼티다.

> "Extensions can add new functionality to a type, but they can't override existing functionality."

**기존 기능을 재정의할 수도 없다.** 상속의 `override`와 다른 점이다.

클래스라면 제약이 하나 더 있다.

> "Extensions can add new convenience initializers to a class, but they can't add new designated initializers or deinitializers to a class."

### 언제 쓰나

**1. 코드를 성격별로 나눌 때** — 가장 흔한 용도다. 타입 본체에는 저장 프로퍼티만 두고, 프로토콜 준수나 헬퍼는 `extension`으로 분리하면 본체가 짧아진다.

```swift
struct DTCourse { /* 저장 프로퍼티만 */ }
extension DTCourse: Codable { }
extension DTCourse { static var sample: [DTCourse] { ... } }
```

지금 코드가 정확히 이 방식이다. `DTCourse`의 데이터 정의와 "미리보기용 샘플 데이터"를 분리해 두었다.

**2. 남의 타입에 기능을 붙일 때** — `extension Date { var koreanFormatted: String { ... } }` 처럼.

**3. 프로토콜에 기본 구현을 줄 때** — protocol extension. Swift에 추상 클래스가 없는 이유이기도 하다.

**4. 조건부로 기능을 줄 때** — `extension Array where Element: Numeric { ... }` 처럼 제약을 걸 수 있다.

### 알아 둘 성질

> "If you define an extension to add new functionality to an existing type, the new functionality will be available on all existing instances of that type, even if they were created before the extension was defined."

extension은 컴파일 시점에 타입에 합쳐지므로, 언제 정의했든 모든 인스턴스가 쓸 수 있다.

주의할 점은 **남용**이다. 표준 타입에 이름이 흔한 메서드를 붙이면 다른 라이브러리와 충돌할 수 있고, 아무 데나 흩어 두면 어디에 정의됐는지 찾기 어려워진다. 파일 단위로 묶고 이름을 구체적으로 짓는 편이 좋다.

### 적용 범위 — 전역인가, 파일 안인가

**결론: 파일 경계와는 아무 상관이 없다. 결정하는 것은 접근 수준(access level)이다.**

Swift의 `extension`은 파일 스코프가 아니다. 어느 파일에 썼든 접근 수준이 허용하는 범위 전체에서 보인다.

`extension`이 붙는 멤버의 기본 접근 수준 규칙은 이렇다.

> You can extend a class, structure, or enumeration in any access context in which the class, structure, or enumeration is available. Any type members added in an extension have the same default access level as type members declared in the original type being extended. If you extend a public or internal type, any new type members you add have a default access level of internal.

`View`는 SwiftUI의 `public` 프로토콜이므로, 예제의 `measureSzie`는 명시적 수준이 없어 **`internal`** 이 된다. Swift에서 `internal`은 **같은 모듈 전체**를 뜻한다.

따라서 이 예제의 결론은 다음과 같다.

- `ContentView.swift`에 썼지만 **앱 타깃 안의 모든 파일**에서 `.measureSzie { }`를 쓸 수 있다.
- `import`나 별도 선언이 필요 없다. 같은 모듈이면 자동으로 보인다.
- `View`를 확장했으므로 **모든 SwiftUI 뷰**에 이 메서드가 생긴다. `Text`, `Image`, `VStack`, 직접 만든 뷰 전부.
- 다른 모듈(별도 프레임워크, 라이브러리)에서는 보이지 않는다. 거기까지 열려면 `public`이 필요하다.

접근 수준으로 범위를 조절할 수 있다.

```swift
public extension View { ... }     // 다른 모듈에서도 사용 가능
extension View { ... }            // 모듈 전체 (기본값, internal)
fileprivate extension View { ... } // 이 파일 안에서만
private extension View { ... }     // 선언된 스코프 안에서만
```

extension 자체에 수식어를 붙이면 그 안의 모든 멤버에 기본값으로 적용된다.

> Alternatively, you can mark an extension with an explicit access-level modifier (for example, `private`) to set a new default access level for all members defined within the extension. This new default can still be overridden within the extension for individual type members.

한 가지 예외가 있다. **프로토콜 준수를 추가하는 extension에는 접근 수준을 명시할 수 없다.**

> You can't provide an explicit access-level modifier for an extension if you're using that extension to add protocol conformance. Instead, the protocol's own access level is used to provide the default access level for each protocol requirement implementation within the extension.

```swift
private extension DTCourse: Codable { }   // ⚠️ 불가
extension DTCourse: Codable { }           // ✅
```

### 전역으로 보인다는 것의 위험

`extension View`처럼 넓은 타입을 확장하면 **모듈 안의 모든 뷰가 그 메서드를 갖게 된다.** 편리한 만큼 부작용도 있다.

- **이름 충돌.** 같은 모듈이나 의존 라이브러리에 같은 이름이 있으면 모호해진다. 표준 타입일수록 위험이 크다.
- **자동완성 오염.** 뷰에 점을 찍을 때마다 후보에 끼어든다. 유틸리티가 수십 개 쌓이면 체감된다.
- **출처 추적의 어려움.** `.measureSzie`를 처음 본 사람이 이게 SwiftUI 기본 API인지 우리 코드인지 구분하기 어렵다.
- **오타가 그대로 API가 된다.** 예제의 `measureSzie`는 `measureSize`의 오타인데, 이미 모듈 전체에 노출된 이름이다.

### 파일 관리 — 실무에서 쓰는 방식

**1. `타입명+기능.swift` 규칙**

Apple 생태계에서 널리 쓰는 관례다. Objective-C category 시절부터 이어져 왔다.

```text
Extensions/
├── View+MeasureSize.swift        ← 이 예제의 measureSize
├── View+CardStyle.swift
├── String+Validation.swift
├── Date+Formatting.swift
└── DTCourse+Sample.swift
```

파일 이름만 보고 "무엇을, 어떤 목적으로 확장했는지" 알 수 있다.

**2. 관련된 것끼리 한 파일에**

이 예제는 `SizePreferenceKey` + `MeasuringSizeModifier` + `extension View` 세 조각이 하나의 기능을 이룬다. 흩어 놓으면 오히려 읽기 어렵다. `View+MeasureSize.swift` 한 파일에 셋을 함께 두는 편이 낫다.

```swift
// View+MeasureSize.swift
private struct SizePreferenceKey: PreferenceKey { ... }   // 외부에 감춤
private struct MeasuringSizeModifier: ViewModifier { ... } // 외부에 감춤

extension View {
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View { ... }
}
```

**구현 세부는 `private`으로 감추고 진입점만 노출**하는 것이 좋은 설계다. `SizePreferenceKey`는 이 기능의 내부 구현일 뿐, 바깥에서 쓸 이유가 없다.

**3. 프로토콜 준수는 준수마다 분리**

```swift
// DTCourse.swift            — 저장 프로퍼티만
// DTCourse+Codable.swift    — Codable 준수
// DTCourse+Sample.swift     — 미리보기용 샘플
```

**4. 범위를 최소로 잡는다**

한 파일에서만 쓰는 헬퍼라면 `fileprivate extension`으로 두어 모듈 전역 오염을 막는다.

**5. 이름을 구체적으로 짓는다**

`View`에 `.style()`, `.setup()` 같은 일반적인 이름을 붙이지 않는다. `.cardStyle()`, `.measureSize(perform:)`처럼 의도가 드러나는 이름을 쓴다. Swift API Design Guidelines의 명료성 원칙이 그대로 적용된다.

**6. 확장 대상을 좁힐 수 있는지 본다**

정말 모든 뷰에 필요한가를 따진다. 특정 조건에서만 의미 있다면 제약을 걸 수 있다.

```swift
extension View where Self: Equatable { ... }
extension Array where Element: Numeric { ... }
```

## 학습 체크리스트

- [ ] `extension DTCourse`에 저장 프로퍼티를 추가해 보고 오류 메시지를 읽는다.
- [ ] `extension`에 계산 프로퍼티를 추가해 정상 동작하는지 확인한다.
- [ ] `DTCourse`의 `Identifiable` 준수를 본체에서 떼어 `extension DTCourse: Identifiable`로 옮겨 본다.
- [ ] `extension String { var isBlank: Bool { ... } }`처럼 표준 타입을 확장해 본다.
- [ ] `extension Array where Element == DTCourse { ... }`로 조건부 확장을 만든다.
- [ ] `extension`에 인스턴스 메서드를 추가하고 `mutating`이 필요한 경우를 확인한다.
- [ ] 프로토콜 하나를 만들고 `extension`으로 기본 구현을 제공해 본다.
- [ ] `extension`을 별도 파일(`DTCourse+Sample.swift`)로 분리해도 동작하는지 확인한다.
- [ ] `measureSzie`를 다른 파일의 뷰에서 호출해 모듈 전체에 보이는 것을 확인한다.
- [ ] `extension View`를 `fileprivate extension View`로 바꿔 다른 파일에서 호출이 막히는 것을 확인한다.
- [ ] `SizePreferenceKey`와 `MeasuringSizeModifier`에 `private`을 붙여도 동작하는지 확인한다.
- [ ] `private extension DTCourse: Codable { }`을 시도해 프로토콜 준수에는 수식어를 못 붙이는 것을 확인한다.
- [ ] `Text`가 아닌 임의의 커스텀 뷰에도 `.measureSzie`가 자동완성에 뜨는지 본다.
- [ ] `View+MeasureSize.swift` 파일로 세 조각을 옮기고 여전히 동작하는지 확인한다.
- [ ] `measureSzie` 오타를 `measureSize`로 고치고 영향 범위를 확인한다.

## 참고 자료

- [The Swift Programming Language: Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/extensions/)
- [The Swift Programming Language: Protocols — Protocol Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
- [The Swift Programming Language: Generics — Extending a Generic Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/generics/)
- [The Swift Programming Language: Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
- [The Swift Programming Language: Declarations — Extension Declaration](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/)
- [The Swift Programming Language: Access Control](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/)
- [The Swift Programming Language: Access Control — Extensions](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/#Extensions)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Apple: ViewModifier — extension을 쓰는 관용적 방식](https://developer.apple.com/documentation/swiftui/viewmodifier)
