# `PreviewModifier` — preview에 container가 주입되는 원리와 shared context

## 질문이 나온 코드

`chapter-117/chapter-117/FriendModelPreviewModifier.swift`

```swift
struct FriendModelPreviewModifier: PreviewModifier {
    typealias Context = ModelContainer

    static func makeSharedContext() async throws -> ModelContainer {
        FriendModel.preview
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content
            .modelContainer(context)
    }
}
```

`chapter-117/chapter-117/ContentView.swift`

```swift
#Preview(traits: .modifier(FriendModelPreviewModifier())) {
    ContentView()
}
```

질문은 다음과 같다.

- 이 프로토콜은 무슨 기능을 제공하는가?
- modifier를 설정하면 내부 container가 여기서 설정한 container로 연결되는가?
- 원리가 무엇이고 어떻게 주입되는가?
- 컴포넌트를 렌더링할 때 필요한 context가 그때 실행되는가?

> 이름 정정: 프로토콜 이름은 `ModelPreviewModifier`가 아니라 **`PreviewModifier`**다. SwiftData 전용이 아니라 **SwiftUI의 일반 preview 환경 구성용 프로토콜**이고, 여기서는 그 Context 타입으로 `ModelContainer`를 골라 쓴 것뿐이다.

## 공부할 내용

### 결론 먼저

- `PreviewModifier`는 **preview가 실행될 환경을 정의하는 프로토콜**이다. SwiftUI가 제공하며 iOS 18 / macOS 15부터 쓸 수 있다.
- container가 "연결"되는 것은 마법이 아니다. `body`에서 우리가 직접 `.modelContainer(context)`를 붙인다. 그 modifier가 environment를 채우고, `@Query`와 `@Environment(\.modelContext)`가 그 environment를 읽는다.
- `makeSharedContext()`의 결과는 **캐시되어 같은 modifier 타입을 쓰는 모든 preview에서 재사용**된다. preview를 그릴 때마다 새로 만들지 않는다.
- 이 점이 chapter-115의 `static var mock`과 결정적으로 다르다.

### 프로토콜이 제공하는 것

SDK 선언은 이렇다.

```swift
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@MainActor public protocol PreviewModifier {
    associatedtype Context = Void
    associatedtype Body: View
    typealias Content = PreviewModifierContent

    @MainActor static func makeSharedContext() async throws -> Self.Context
    @ViewBuilder @MainActor func body(content: Self.Content, context: Self.Context) -> Self.Body
}

extension PreviewModifier where Self.Context == () {
    @MainActor public static func makeSharedContext() async throws -> Self.Context
}
```

한 줄씩 보면 프로토콜이 무엇을 해 주는지 드러난다.

| 요소 | 의미 |
|---|---|
| `associatedtype Context = Void` | preview에 넘길 **준비물 타입**. 기본은 `Void`이고 여기서는 `ModelContainer`로 지정했다 |
| `makeSharedContext()` | 준비물을 **한 번 만드는** 자리. `async throws`라서 비동기 준비와 오류 던지기가 가능하다 |
| `body(content:context:)` | 준비물을 **실제 view 계층에 적용**하는 자리 |
| `Content = PreviewModifierContent` | `#Preview` 블록이 만든 화면을 가리키는 **타입 지워진 자리 표시자** |
| `@MainActor` | 프로토콜 전체가 main actor 격리다 |
| `Context == ()`일 때 기본 구현 | 준비물이 필요 없으면 `makeSharedContext()`를 안 써도 된다 |

Apple 문서의 설명도 같다.

> Conforming types can define shared contexts that will be cached by the preview system, then reused across participating previews.

> The context returned here will be cached and passed into the `body` method for every preview that applies a modifier of this type.

`typealias Context = ModelContainer`는 프로토콜 요구사항이 아니라 **associated type을 무엇으로 쓸지 우리가 고른 것**이다. `makeSharedContext()`의 반환 타입만으로도 추론되므로 생략할 수도 있지만, 명시하면 읽기 쉽다.

`PreviewModifierContent`도 봐 두면 좋다.

```swift
public struct PreviewModifierContent: View {
    public typealias Body = Never
}
```

`Body = Never`다. 우리가 열어 볼 수 있는 view가 아니라 **"여기에 preview 본문이 들어간다"는 자리**를 뜻하는 값이다. `ViewModifier`의 `Content`와 같은 역할이다. 그래서 `body` 안에서 `content`를 조작하지 않고 **그대로 두고 modifier만 붙인다**.

### `#Preview(traits:)`는 무엇을 만드는가

`#Preview`는 매크로다.

```swift
@freestanding(declaration)
public macro Preview(_ name: String? = nil,
                     traits: PreviewTrait<Preview.ViewTraits>,
                     _ additionalTraits: PreviewTrait<Preview.ViewTraits>...,
                     @ViewBuilder body: @escaping @MainActor () -> any View)
    = #externalMacro(module: "PreviewsMacros", type: "SwiftUIView")
```

실제 확장 결과를 `-dump-macro-expansions`로 뽑으면 이렇다.

```swift
struct $s13PreviewExpand...15PreviewRegistryfMu_: DeveloperToolsSupport.PreviewRegistry {
    static var fileID: String { "PreviewExpand/PreviewExpand.swift" }
    static var line: Int { 46 }
    static var column: Int { 1 }

    static func makePreview() throws -> DeveloperToolsSupport.Preview {
        DeveloperToolsSupport.Preview(traits: .modifier(FriendModelPreviewModifier())) {
            func __b_buildView(@ViewBuilder body: () -> any View) -> any View { body() }
            return __b_buildView {
                ContentView()
            }
        }
    }
}
```

정리하면 이렇다.

- `#Preview`는 **`PreviewRegistry`를 준수하는 타입 하나를 선언**한다. 파일과 줄 위치까지 담고 있어서 Xcode가 캔버스에 어느 preview인지 표시할 수 있다.
- 우리가 쓴 `traits:`와 view 본문은 `Preview(traits:) { ... }` 호출로 그대로 옮겨진다.
- 즉 `.modifier(FriendModelPreviewModifier())`는 **preview 정의에 붙는 trait 값**이고, 이 값을 preview 시스템이 읽어서 처리한다.

매크로 확장 자체에 대한 배경은 [Swift macro와 빌드 파이프라인](./swift-macros-and-build-pipeline.md)에 정리했다.

`.modifier` trait의 선언은 SwiftUI에 있다.

```swift
extension DeveloperToolsSupport.PreviewTrait where T == Preview.ViewTraits {
    @MainActor public static func modifier(_ modifier: some PreviewModifier) -> PreviewTrait<T>
}
```

### 주입 경로

질문의 "어떻게 주입되는거지"를 한 흐름으로 그리면 이렇다.

```text
#Preview(traits: .modifier(FriendModelPreviewModifier())) { ContentView() }
        │
        ├─ 매크로가 PreviewRegistry 타입 생성
        │
        ▼
preview 시스템이 makePreview() 호출 → trait에서 modifier를 꺼낸다
        │
        ▼
FriendModelPreviewModifier.makeSharedContext()   ← 한 번 실행, 결과는 캐시
        │  반환값: FriendModel.preview (in-memory ModelContainer)
        ▼
modifier.body(content: <preview 본문>, context: <캐시된 container>)
        │
        └─▶ content.modelContainer(context)
                    │
                    ├─▶ environment에 container 저장
                    └─▶ environment의 modelContext = container.mainContext
                                │
                                ▼
                        ContentView의 @Query private var friends: [FriendModel]
                        (같은 context에서 조회 → 4건이 보인다)
```

핵심은 **연결해 주는 주체가 프로토콜이 아니라 우리가 쓴 한 줄**이라는 점이다.

```swift
func body(content: Content, context: ModelContainer) -> some View {
    content
        .modelContainer(context)   // ← 이 줄이 실제 주입
}
```

이 줄을 지우면 preview는 container를 못 받는다. `PreviewModifier`가 해 주는 일은 **container를 만들 자리와 붙일 자리를 제공하고, 만든 결과를 캐시해 재사용하는 것**까지다.

`.modelContainer(_:)`가 environment의 `modelContext`까지 채운다는 근거와 `@Query`가 그 context를 쓰는 구조는 [Preview의 mock container 문서](./swiftdata-preview-mock-container.md)에 정리했다.

### 렌더링할 때 실행되는가

질문 그대로 나눠 답하면 이렇다.

| 대상 | 실행 시점 | 횟수 |
|---|---|---|
| `makeSharedContext()` | preview 시스템이 그 modifier 타입을 처음 필요로 할 때 | **한 번**, 이후 캐시된 값 재사용 |
| `body(content:context:)` | preview를 구성해 렌더링할 때 | preview마다, 다시 그릴 때마다 |

그래서 "컴포넌트를 렌더링할 때 context가 실행되는가"는 **절반만 맞다**. 화면을 그릴 때 실행되는 것은 `body`이고, context를 만드는 `makeSharedContext()`는 그보다 앞서 한 번만 실행된다.

`async throws`인 이유도 여기서 나온다. preview를 그리기 전에 준비 작업을 기다릴 수 있어야 하고, 준비에 실패하면 캔버스에 오류로 표시되어야 하기 때문이다. 그래서 다음처럼 비동기 준비도 가능하다.

```swift
static func makeSharedContext() async throws -> ModelContainer {
    let container = try ModelContainer(
        for: FriendModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let friends = try await loadSampleFriends()   // 비동기 준비도 가능
    friends.forEach { container.mainContext.insert($0) }
    return container
}
```

지금 코드는 `FriendModel.preview`를 그대로 돌려주므로 `async`도 `throws`도 실제로 쓰지 않는다. 프로토콜 요구사항이라 시그니처만 맞춘 형태다.

### chapter-115 방식과 무엇이 다른가

같은 in-memory container를 만드는데도 두 방식의 성질이 다르다.

```swift
// chapter-115
#Preview {
    ContentView()
        .modelContainer(Todo.mock)          // static var → 접근할 때마다 새 container
}

// chapter-117
#Preview(traits: .modifier(FriendModelPreviewModifier())) {
    ContentView()                            // makeSharedContext() → 캐시되어 재사용
}
```

| 항목 | `.modelContainer(Todo.mock)` | `.modifier(...)` |
|---|---|---|
| container 생성 | 접근할 때마다 새로 | 한 번 만들고 캐시 |
| preview 여러 개일 때 | 각자 다른 저장소 | **같은 저장소 공유** |
| 준비 작업 | 동기만 | `async throws` 가능 |
| 재사용 | preview마다 modifier 줄을 반복 | 타입 하나로 재사용 |
| 필요 OS | iOS 17 | **iOS 18 / macOS 15** |

주의할 점도 뒤집힌다.

- chapter-115 방식은 매번 새 container라 **preview끼리 격리**되지만 생성 비용이 반복된다.
- chapter-117 방식은 캐시라 효율적이지만 **preview들이 상태를 공유**한다. 한 preview에서 데이터를 추가하면 같은 modifier를 쓰는 다른 preview에도 보일 수 있다.

어느 쪽이 옳다기보다 **격리를 원하는지 공유를 원하는지**로 고른다. `static var`와 `static let`의 차이와 같은 구도이며, 자세한 실측은 [`static var { }`와 `static let = []`](./static-stored-vs-computed-property.md)에 있다.

### modifier 합성

trait은 여러 개 붙일 수 있다.

```swift
#Preview(traits: .modifier(FriendModelPreviewModifier()), .modifier(DarkThemeModifier())) {
    ContentView()
}
```

Apple 문서의 설명은 이렇다.

> Composed modifiers will be applied to the preview in order: the first modifier will apply to the body of the preview, the second modifier to the body of the first modifier, and so on.

즉 **먼저 쓴 modifier가 안쪽**이고 뒤에 쓴 modifier가 그것을 감싼다. 데이터 주입과 테마 적용처럼 관심사를 나눠 조합할 수 있다.

### 함께 알아 둘 것

- `@Previewable`을 쓰면 preview 본문 안에서 `@Query`나 `@State`를 직접 선언할 수 있다. Apple 예제도 `@Previewable @Query var snacks: [Snack]` 형태를 쓴다.
- `makeSharedContext()`가 던진 오류는 캔버스에 preview 실패로 표시된다. 그래서 `try!`보다 `throws`를 그대로 흘리는 편이 진단에 유리하다. 지금 코드의 `FriendModel.preview`는 내부에서 `try!`를 쓰고 있어 실패 시 크래시가 된다.
- 이 모든 것은 **preview 전용 경로**다. 앱 실행 시에는 `chapter_117App`에 `.modelContainer(...)`가 없으므로, 그대로 실행하면 `@Query`가 쓸 context가 없다. preview만 되는 상태와 앱이 도는 상태는 별개로 확인해야 한다.
- 최소 지원 OS가 iOS 17이면 `PreviewModifier`를 쓸 수 없다. 그때는 chapter-115처럼 `.modelContainer(...)`를 직접 붙인다.

## 체크리스트

- [ ] `PreviewModifier` 선언에서 `Context`, `Content`, 두 요구사항을 각각 설명한다.
- [ ] `body`의 `.modelContainer(context)` 줄을 지우고 preview가 어떻게 되는지 확인한다.
- [ ] `#Preview`를 Expand Macro로 열어 `PreviewRegistry` 타입이 생기는 것을 확인한다.
- [ ] 같은 modifier를 쓰는 preview를 두 개 만들어 데이터가 공유되는지 확인한다.
- [ ] `makeSharedContext()`에 `print`를 넣어 몇 번 실행되는지 확인한다.
- [ ] `Context`를 `Void`로 두는 modifier를 하나 만들어 기본 구현을 활용한다.
- [ ] modifier 두 개를 합성해 적용 순서를 확인한다.
- [ ] chapter-115의 `.modelContainer(Todo.mock)` 방식과 장단점을 표로 비교한다.
- [ ] `chapter_117App`에 container가 없을 때 앱 실행이 어떻게 되는지 확인한다.

## 공식 참고 자료

- [Apple: PreviewModifier](https://developer.apple.com/documentation/swiftui/previewmodifier)
- [Apple: PreviewModifier.makeSharedContext()](https://developer.apple.com/documentation/swiftui/previewmodifier/makesharedcontext())
- [Apple: PreviewModifier.body(content:context:)](https://developer.apple.com/documentation/swiftui/previewmodifier/body(content:context:))
- [Apple: PreviewModifierContent](https://developer.apple.com/documentation/swiftui/previewmodifiercontent)
- [Apple: PreviewTrait.modifier(_:)](https://developer.apple.com/documentation/developertoolssupport/previewtrait/modifier(_:))
- [Apple: Preview macro](https://developer.apple.com/documentation/swiftui/preview(_:body:))
- [Apple: Previewable() macro](https://developer.apple.com/documentation/swiftui/previewable())
- [Apple: Previews in Xcode](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
- [Apple: View.modelContainer(_:)](https://developer.apple.com/documentation/swiftui/view/modelcontainer(_:))
- [Apple WWDC24: What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2024/10144/)
