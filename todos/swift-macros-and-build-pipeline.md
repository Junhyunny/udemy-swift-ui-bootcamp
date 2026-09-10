# Swift macro는 언제 코드가 추가되는가 — 빌드 파이프라인과 Java 비교

## 질문이 나온 코드

`chapter-115/chapter-115/Todo.swift`

```swift
@Model
final class Todo {
    var title: String
    var isCompleted: Bool

    init(title: String, isCompleted: Bool) {
        self.title = title
        self.isCompleted = isCompleted
    }
}
```

Xcode에서 `@Model`을 우클릭해 **Expand Macro**를 누르면 작성하지 않은 코드가 보인다. 질문은 다음과 같다.

- 이 애너테이션을 붙이면 빌드할 때 코드가 추가된다는 뜻인가?
- 어느 시점에 추가되는가?
- Java는 컴파일 시점에 바이트코드에 코드가 들어가는데 Swift도 같은 방식인가?
- Swift에도 컴파일, 링킹 같은 단계가 있는가? 최종 결과물은 무엇인가?
- `@MainActor`는 Expand Macro 버튼이 없는데 이건 런타임에 바뀌는 구조인가?

## 공부할 내용

### 결론 먼저

- `@Model`은 애너테이션이 아니라 **Swift macro**다. **컴파일 중에 source 수준에서 코드가 추가**되고, 그 결과가 그대로 함께 컴파일된다.
- 확장 결과는 실행 파일 안에 일반 Swift 코드와 똑같이 들어간다. 런타임에 "매크로를 해석하는" 단계는 없다.
- Java의 annotation processing과 목적은 비슷하지만, 결과물이 bytecode/JVM이 아니라 **기계어 Mach-O**라는 점이 다르다.
- `@MainActor`는 매크로가 아니라 **언어에 내장된 attribute**다. 그래서 확장 버튼이 없다.

### `@Model`의 정체 — 매크로 선언 보기

SDK의 `SwiftData.swiftinterface`에는 `@Model`이 이렇게 선언되어 있다.

```swift
@attached(member, conformances: Observable, PersistentModel, Sendable, names: named(_$backingData), ...)
@attached(memberAttribute)
@attached(extension, conformances: Observable, PersistentModel, Sendable)
public macro Model() = #externalMacro(module: "SwiftDataMacros", type: "PersistentModelMacro")
```

읽는 방법은 다음과 같다.

- `macro Model()`: 함수도 타입도 아닌 **macro 선언**이다.
- `@attached(member)`: 붙인 타입 **안에 멤버를 추가**한다.
- `@attached(memberAttribute)`: 각 **멤버에 attribute를 덧붙인다**.
- `@attached(extension)`: **extension과 protocol 준수를 추가**한다.
- `#externalMacro(module:type:)`: 확장 로직이 컴파일러 본체가 아니라 **별도 macro 구현 모듈**(`SwiftDataMacros`)에 있다.

즉 매크로는 "컴파일러가 이미 아는 예약어"가 아니라, **컴파일러가 빌드 중에 실행하는 별도 프로그램**이다.

### 실제 확장 결과

`swiftc -Xfrontend -dump-macro-expansions`로 확인한 `Todo`의 확장 결과 일부다.

```swift
@Transient
private var _$backingData: any SwiftData.BackingData<Todo> = Todo.createBackingData()

public var persistentBackingData: any SwiftData.BackingData<Todo> {
    get { return _$backingData }
    set { _$backingData = newValue }
}

class var schemaMetadata: [SwiftData.Schema.PropertyMetadata] {
  return [
    SwiftData.Schema.PropertyMetadata(name: "title", keypath: \Todo.title, defaultValue: nil, metadata: nil),
    SwiftData.Schema.PropertyMetadata(name: "isCompleted", keypath: \Todo.isCompleted, defaultValue: nil, metadata: nil)
  ]
}

@Transient private let _$observationRegistrar = Observation.ObservationRegistrar()
```

`title` 프로퍼티에는 accessor가 새로 붙는다.

```swift
{
    @storageRestrictions(accesses: _$backingData, initializes: _title)
    init(initialValue) {
        _$backingData.setValue(forKey: \.title, to: initialValue)
        _title = _SwiftDataNoType()
    }
    get {
        _$observationRegistrar.access(self, keyPath: \.title)
        return self.getValue(forKey: \.title)
    }
    set {
        _$observationRegistrar.withMutation(of: self, keyPath: \.title) {
            self.setValue(forKey: \.title, to: newValue)
        }
    }
}
```

그리고 extension이 추가된다.

```swift
extension Todo: SwiftData.PersistentModel {}
extension Todo: Observation.Observable {}

@available(*, unavailable, message: "PersistentModels are not Sendable, consider utilizing a ModelActor or use Todo's persistentModelID instead")
extension Todo: Sendable {}
```

여기서 얻는 사실이 많다.

- `var title: String`은 더 이상 단순 저장 프로퍼티가 아니다. **저장소를 읽고 쓰는 computed property**로 바뀐다.
- 그래서 `Todo`는 값을 자기 메모리에 들고 있는 게 아니라 `_$backingData`를 통해 **저장소의 값을 대리 접근**한다.
- Observation registrar가 함께 들어가므로 SwiftUI가 변경을 감지할 수 있다.
- `Sendable`을 **일부러 사용 불가로 표시**한다. 이 한 줄이 SwiftData 동시성 규칙의 근거다. [SwiftData 동시성 문서](./swiftdata-concurrency-and-context-isolation.md)에서 이어서 다룬다.

직접 확인하려면 다음과 같이 한다.

```bash
xcrun swiftc -typecheck \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios17.0-simulator \
  -Xfrontend -dump-macro-expansions Todo.swift
```

Xcode에서는 매크로 이름을 우클릭하고 **Expand Macro**를 선택하면 같은 결과를 볼 수 있다.

### 어느 시점에 추가되는가

```text
소스 파일
   ↓ 파싱 (구문 트리 생성)
매크로 확장  ← 여기서 @Model이 실행된다 (컴파일 중)
   ↓
타입 검사 (확장된 코드까지 함께 검사)
   ↓
SIL 생성과 최적화
   ↓
LLVM IR
   ↓
기계어 오브젝트 파일(.o)
   ↓ 링킹
실행 파일(Mach-O) → .app 번들
```

핵심은 **매크로 확장이 타입 검사보다 앞선다**는 점이다.

- 매크로는 구문 트리(syntax tree)를 입력으로 받아 구문 트리를 돌려준다. 타입 정보를 보고 동작하지 않는다.
- 확장 결과는 일반 소스와 동일하게 타입 검사를 받는다. 그래서 확장된 코드에 오류가 있으면 **컴파일 오류**로 잡힌다.
- 확장은 항상 **덧붙이기**만 한다. 우리가 쓴 코드를 지우거나 바꾸지 않는다.
- 매크로 구현은 컴파일러와 **분리된 프로세스**로 실행된다. 그래서 매크로가 앱의 파일이나 네트워크에 임의로 접근하는 형태로 동작하지 않는다.

빌드가 끝나면 매크로는 사라진다. 실행 파일에는 "확장된 결과"만 남는다.

### 최종 결과물

| 단계 | 산출물 |
|---|---|
| 컴파일 | `.o` 오브젝트 파일 (기계어) |
| 링킹 | Mach-O 실행 파일 |
| 패키징 | `.app` 번들 (실행 파일 + `Info.plist` + Assets.car + 리소스) |
| 배포 | `.ipa` (`.app`을 담은 아카이브), App Store 배포 시 서명·씬닝 적용 |

Swift는 **AOT(ahead-of-time) 컴파일**이다. 배포되는 것은 기기의 CPU가 바로 실행하는 기계어다. 중간 바이트코드를 기기에서 다시 번역하지 않는다.

### Java와 비교

| 항목 | Swift | Java |
|---|---|---|
| 표기 | `@Model` (macro), `@MainActor` (attribute) | `@Entity` (annotation) |
| 코드 생성 시점 | 컴파일 중 매크로 확장 (타입 검사 전) | 컴파일 중 annotation processing (APT) |
| 생성 단위 | **소스 구문 트리** | 새 `.java` 소스 (APT) 또는 AST 조작 (Lombok) |
| 컴파일 결과 | 기계어 `.o` → Mach-O | `.class` 바이트코드 |
| 실행 방식 | OS가 기계어 직접 실행 (AOT) | JVM이 바이트코드 로드 후 JIT |
| 링킹 | 링커가 실행 파일 생성 | 링킹 단계 없음, 실행 시 클래스 로더가 해석 |
| 런타임에 표기가 남는가 | **남지 않는다** | `RetentionPolicy.RUNTIME`이면 **남고 리플렉션으로 조회 가능** |
| 런타임 동적 처리 | 매크로 기반으로는 불가 | 프록시, 리플렉션, 바이트코드 조작 가능 |

가장 큰 차이는 마지막 두 줄이다.

```text
Java: 애너테이션이 .class에 남을 수 있음
      → 런타임에 리플렉션으로 읽고 프록시를 만들 수 있음
      → Spring의 런타임 DI/AOP가 성립

Swift: 매크로는 컴파일이 끝나면 흔적이 없음
      → 런타임 조회 대상이 아님
      → 필요한 정보는 확장 시점에 "코드로" 심어 둠
```

그래서 `@Model`은 `schemaMetadata`처럼 **런타임에 필요한 정보를 미리 코드로 생성해 둔다**. Java라면 런타임 리플렉션으로 읽었을 정보를 Swift는 컴파일 시점에 확정한다.

Lombok과의 비교도 유용하다. Lombok은 컴파일 중 AST를 조작해 `getter`/`setter`를 넣고, 사용자는 그 결과를 소스에서 볼 수 없다. Swift 매크로는 **확장 결과를 공식 도구로 확인할 수 있고 디버거로도 들어갈 수 있다**는 점이 다르다.

### `@MainActor`는 매크로가 아니다

`@MainActor`에 Expand Macro 버튼이 없는 이유는 단순하다. **매크로가 아니라 언어에 내장된 attribute**이기 때문이다.

```swift
@globalActor
public actor MainActor { ... }
```

`@MainActor`는 `MainActor`라는 global actor에 그 선언을 **격리(isolation)시킨다**는 표시다. 컴파일러가 직접 처리하며, 확장할 소스가 없다.

동작 방식은 두 층으로 나뉜다.

| 층 | 하는 일 |
|---|---|
| 컴파일 타임 | 이 선언이 main actor에 격리됨을 타입 시스템에 기록하고, 다른 격리 문맥에서 `await` 없이 접근하면 **컴파일 오류** |
| 런타임 | 다른 실행 문맥에서 호출하면 main actor의 executor로 **hop**해서 실행 |

그래서 질문의 "런타임에 뭔가 바뀌는 구조인가"는 절반만 맞다. **검사는 컴파일 타임에, 실제 스레드 전환은 런타임에** 일어난다. 코드가 새로 생성되지는 않는다.

정리하면 Swift에서 `@`로 시작하는 표기는 최소 세 종류다.

| 종류 | 예 | 코드가 생성되는가 | Expand Macro |
|---|---|---|---|
| Macro | `@Model`, `@Observable`, `@ModelActor` | 생성된다 | 있다 |
| Attribute | `@MainActor`, `@available`, `@escaping`, `@objc` | 생성되지 않는다 | 없다 |
| Property wrapper | `@State`, `@Environment`, `@Query` | 컴파일러가 정해진 형태로 변환한다 | 없다 |

property wrapper는 매크로가 아니지만 컴파일러가 저장 프로퍼티와 `wrappedValue` 접근으로 바꿔 주므로 "코드가 생기는 것처럼" 보인다. [프로퍼티 래퍼의 `$` 사용 기준](./property-wrapper-dollar-sign.md)과 함께 보면 구분이 쉽다.

### 빌드 시간과 실무 주의점

- 매크로 구현은 별도 프로세스로 실행되므로 **빌드 시간에 영향을 준다**. 매크로를 많이 쓰는 모듈은 증분 빌드가 느려질 수 있다.
- 처음 빌드할 때 Xcode가 매크로 패키지 신뢰 여부를 묻는다. Swift Package 형태의 매크로는 **소스에서 빌드되어 실행**되기 때문이다.
- 확장된 코드에서 오류가 나면 오류 위치가 확장 결과를 가리킨다. Expand Macro로 실제 코드를 보고 읽는 습관이 필요하다.
- 확장 결과에 있는 `_$backingData`, `_$observationRegistrar` 같은 이름은 **공개 API가 아니다**. 직접 호출하지 않는다.

## 체크리스트

- [ ] `@Model`의 `@attached(...)` 선언을 SDK interface에서 직접 찾아 읽는다.
- [ ] Xcode Expand Macro와 `-dump-macro-expansions` 결과가 같은지 비교한다.
- [ ] 확장된 `title` accessor를 보고 저장 프로퍼티가 아님을 설명한다.
- [ ] 매크로 확장이 타입 검사보다 먼저 일어난다는 것을 오류 메시지로 확인한다.
- [ ] `.app` 번들 내부를 열어 실행 파일과 리소스를 확인한다.
- [ ] Java annotation과 Swift macro의 런타임 잔존 여부 차이를 한 문단으로 설명한다.
- [ ] `@MainActor`에 Expand Macro가 없는 이유를 attribute와 macro 구분으로 설명한다.
- [ ] `@State`, `@Query` 같은 property wrapper가 세 번째 범주임을 구분한다.

## 공식 참고 자료

- [Apple: Macros (Swift 문서)](https://developer.apple.com/documentation/swift/applying-macros)
- [Swift Book: Macros](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- [Swift Evolution SE-0382: Expression Macros](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0382-expression-macros.md)
- [Swift Evolution SE-0389: Attached Macros](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md)
- [Swift Evolution SE-0316: Global Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md)
- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Apple: SwiftData Model() macro](https://developer.apple.com/documentation/swiftdata/model())
- [Apple WWDC23: Expand on Swift macros](https://developer.apple.com/videos/play/wwdc2023/10167/)
- [Apple WWDC23: Write Swift macros](https://developer.apple.com/videos/play/wwdc2023/10166/)
- [Apple: Bundle Structure](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html)
