# Preview의 mock container — 무엇이 주입되고, `static var`는 매번 실행되는가

## 질문이 나온 코드

`chapter-115/chapter-115/ContentView.swift`

```swift
struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query var todos: [Todo]
    ...
}

#Preview {
    ContentView()
        .modelContainer(Todo.mock)
}
```

`chapter-115/chapter-115/Todo.swift`

```swift
extension Todo {

    @MainActor
    static var mock: ModelContainer {
        let container = try! ModelContainer(
            for: Todo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        container.mainContext.insert(Todo(title: "Hello", isCompleted: false))
        container.mainContext.insert(Todo(title: "World", isCompleted: true))
        container.mainContext.insert(Todo(title: "Junhyunny", isCompleted: false))
        return container
    }
}
```

질문은 다음과 같다.

- preview에서 주입한 container의 context가 `@Environment(\.modelContext)`로 들어오는가? 그래서 같은 저장소에 저장되는가?
- 테스트는 어떻게 제어하는가?
- `static var`가 클로저 형태라 매번 호출되는 것 아닌가? 그러면 디스크에 mock 데이터가 계속 쌓이지 않는가?
- `static` 변수라서 괜찮은 것인가?
- `isStoredInMemoryOnly`라서 상관없는 것인가?
- 같은 값이 입력되면 식별자는 무엇이고, 특정 데이터를 업데이트하려면 어떻게 하는가?

## 공부할 내용

### 결론 먼저

| 질문 | 답 |
|---|---|
| preview container의 context가 주입되는가 | **그렇다.** `.modelContainer(_:)`가 환경의 `modelContext`를 그 container의 `mainContext`로 설정한다 |
| `static var { }`가 매번 실행되는가 | **그렇다.** 저장 프로퍼티가 아니라 computed property라서 접근할 때마다 새 container가 만들어진다 |
| `static`이라서 안전한가 | **아니다.** `static`은 "한 번만 실행"을 뜻하지 않는다. `static let`이어야 한 번이다 |
| 디스크에 mock이 쌓이는가 | **쌓이지 않는다.** `isStoredInMemoryOnly: true`이므로 store URL이 `/dev/null`이다 |
| in-memory가 아니었다면 | **쌓인다.** 실제로 접근할 때마다 row가 2건씩 늘어나는 것을 확인했다 |

즉 **"클로저라서 매번 호출된다"는 걱정은 맞고, "그래서 디스크가 더러워진다"는 걱정은 in-memory 설정 덕분에 빗나간다.** 두 사실을 분리해서 이해해야 한다.

### `.modelContainer(_:)`는 무엇을 주입하는가

`_SwiftData_SwiftUI`의 선언을 보면 관계가 분명하다.

```swift
extension View {
    @MainActor public func modelContainer(_ container: ModelContainer) -> some View
    @MainActor public func modelContainer(for modelType: any PersistentModel.Type,
                                          inMemory: Bool = false,
                                          isAutosaveEnabled: Bool = true,
                                          isUndoEnabled: Bool = false,
                                          onSetup: @escaping (Result<ModelContainer, any Error>) -> Void = { _ in }) -> some View
}

extension EnvironmentValues {
    public var modelContext: ModelContext { get set }
}
```

동작은 다음과 같다.

```text
.modelContainer(Todo.mock)
        │
        ├─▶ 환경에 container를 넣는다
        └─▶ 환경의 modelContext를 container.mainContext로 설정한다
                    │
                    ├─▶ @Environment(\.modelContext) var modelContext   ← 이걸 받는다
                    └─▶ @Query var todos: [Todo]                        ← 이 context에서 조회한다
```

그래서 preview에서 `Add` 버튼을 눌러 `modelContext.insert(...)`를 하면 **preview에 주입한 그 in-memory container에 들어간다**. 목록도 같은 context에서 조회되므로 화면이 즉시 갱신된다.

`@Query`가 같은 context를 쓴다는 것은 `Query` 타입이 `modelContext` 프로퍼티를 갖고 있는 것으로도 확인할 수 있다.

```swift
@MainActor public struct Query<Element, Result> : DynamicProperty where Element : PersistentModel {
    @MainActor public var modelContext: ModelContext { get }
    @MainActor public var fetchError: (any Error)? { get }
}
```

앱 실행 시에는 `chapter_115App`의 `.modelContainer(for: Todo.self)`가 같은 자리를 채운다. 그래서 **같은 화면 코드가 preview에서는 mock 저장소를, 앱에서는 실제 저장소를 쓴다**. 화면 코드는 어느 쪽인지 알 필요가 없다. 이것이 environment 주입의 이점이고 [Environment 프로퍼티 래퍼](./environment-property-wrapper.md), [테스트를 위한 의존성 주입](./dependency-injection-for-testing.md)과 같은 구조다.

주입하지 않으면 어떻게 되는가도 알아 둘 필요가 있다. `@Query`나 `modelContext`를 쓰는 화면을 container 없이 preview하면 실행 중 오류가 난다. `#Preview`에 `.modelContainer(...)`가 반드시 필요한 이유다.

### `static var { }`는 매번 실행된다

이 부분이 질문의 핵심이다.

```swift
static var mock: ModelContainer { ... }   // computed property
static let mock: ModelContainer = ...     // stored property
```

- `static var mock: T { ... }`는 **계산 프로퍼티**다. 저장 공간이 없고, 접근할 때마다 본문이 실행된다.
- `static let mock: T = ...`는 **저장 프로퍼티**다. 처음 접근할 때 한 번만 초기화되고 이후 같은 값을 돌려준다. Swift의 전역·정적 저장 프로퍼티는 lazy하게, 그리고 한 번만 초기화되도록 보장된다.

직접 확인한 결과다.

```swift
let a = Todo.mock
let b = Todo.mock
// a === b  →  false
```

```text
in-memory url  = /dev/null
접근 1회차: rows = 2
접근 2회차: rows = 2
접근 3회차: rows = 2
```

`a`와 `b`는 **서로 다른 container**다. 각자 자기 저장소를 갖고 있고, 각자 2건씩 들고 있다. 그래서 row가 2, 4, 6으로 늘지 않는다.

반대로 같은 container를 잡아 두고 계속 쓰면 당연히 누적된다.

```text
같은 container를 들고 insert 한 번 더 → rows = 3
```

이 주제 자체는 [`static var { }`와 `static let = []`](./static-stored-vs-computed-property.md)에 더 자세히 정리되어 있다.

### 디스크에 쌓이는가 — in-memory와 파일 store의 차이

`isStoredInMemoryOnly: true`인 configuration의 URL을 출력하면 이렇다.

```text
url                  = /dev/null
name                 = default
isStoredInMemoryOnly = true
```

`/dev/null`은 쓰기가 버려지는 장치 파일이다. **앱의 Application Support 아래에 store 파일이 생기지 않는다.** container가 해제되면 데이터도 함께 사라진다.

만약 같은 mock을 **파일 store**로 만들었다면 이야기가 완전히 달라진다. 같은 구조에서 URL만 실제 파일로 바꿔 세 번 접근한 결과다.

```swift
static var diskMock: ModelContainer {
    let c = try! ModelContainer(
        for: Todo.self,
        configurations: ModelConfiguration(schema: Schema([Todo.self]), url: storeURL)
    )
    c.mainContext.insert(Todo(title: "Hello"))
    c.mainContext.insert(Todo(title: "World"))
    try? c.mainContext.save()
    return c
}
```

```text
접근 1회차: rows = 2
접근 2회차: rows = 4
접근 3회차: rows = 6
남은 파일: Todos.store, Todos.store-shm, Todos.store-wal
```

정확히 걱정하던 일이 벌어진다. **매번 같은 파일에 mock 데이터가 2건씩 추가된다.** 게다가 SQLite WAL 파일까지 함께 남는다.

정리하면 이렇다.

| 조건 | 매 접근마다 새 container | 데이터 누적 | 디스크 파일 |
|---|---|---|---|
| `isStoredInMemoryOnly: true` (지금 코드) | 만들어진다 | 없음 | 없음 |
| 파일 URL store | 만들어진다 | **있음** | 남음 |
| `static let` + 파일 store | 한 번만 | 첫 실행만 | 남음 |

지금 코드가 괜찮은 이유는 `static`이어서가 아니라 **`isStoredInMemoryOnly: true`이기 때문**이다. 질문의 두 후보 중 뒤쪽이 맞다.

### 그래도 남는 비용

디스크는 괜찮지만 공짜는 아니다.

- 접근할 때마다 container를 새로 만드는 것은 schema 구성과 store 열기를 반복하는 일이다. preview 한두 개에서는 무시할 수 있지만 좋은 습관은 아니다.
- `try!`는 실패 시 즉시 크래시한다. preview 픽스처에서는 흔한 관용이지만, 앱 실행 경로에는 쓰지 않는다.
- 한 preview 안에서 `Todo.mock`을 두 번 쓰면 서로 다른 저장소가 생긴다. 화면 두 개가 데이터를 공유하지 않는다.

한 번만 만들고 싶으면 저장 프로퍼티로 바꾼다.

```swift
extension Todo {

    @MainActor
    static let preview: ModelContainer = {
        let container = try! ModelContainer(
            for: Todo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let samples = [
            Todo(title: "Hello", isCompleted: false),
            Todo(title: "World", isCompleted: true),
            Todo(title: "Junhyunny", isCompleted: false)
        ]
        samples.forEach { container.mainContext.insert($0) }
        return container
    }()
}
```

다만 `static let`이면 **preview 사이에 상태가 공유된다**. preview A에서 항목을 추가하면 preview B에도 보인다. 매번 깨끗한 상태가 필요하면 오히려 지금의 computed 방식이 낫다.

```text
매번 새 컨테이너 (static var { })   → 격리는 좋고, 생성 비용은 반복
한 번만 만들기 (static let = { }())  → 비용은 한 번, 상태는 공유
```

정답이 하나가 아니라 **무엇을 원하는지에 따라 고른다**. in-memory인 한 어느 쪽도 디스크를 더럽히지 않는다.

### 테스트에서는 어떻게 제어하는가

preview와 목표가 다르다. 테스트는 **매 케이스가 완전히 독립**이어야 한다.

```swift
import Testing
import SwiftData

@MainActor
@Test
func 완료로_바꾸면_저장된다() throws {
    let container = try ModelContainer(
        for: Todo.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let todo = Todo(title: "Hello", isCompleted: false)
    context.insert(todo)
    try context.save()

    todo.isCompleted = true
    try context.save()

    let saved = try context.fetch(FetchDescriptor<Todo>())
    #expect(saved.count == 1)
    #expect(saved.first?.isCompleted == true)
}
```

지켜야 할 규칙은 다음과 같다.

- container를 **테스트 함수 안에서 새로 만든다.** 전역 `static let`을 공유하면 케이스 사이에 데이터가 새어 나가 순서에 따라 결과가 달라진다.
- `isStoredInMemoryOnly: true`를 쓴다. 사용자 데이터 위치를 건드리지 않고, 정리 코드도 필요 없다.
- `mainContext`를 쓰려면 테스트도 `@MainActor`여야 한다. 아니면 `ModelContext(container)`로 별도 context를 만든다.
- 화면 코드를 테스트하려면 그 화면에 container를 주입할 수 있어야 한다. 지금처럼 environment로 받는 구조가 그래서 유리하다.

`ModelContainer`, `ModelConfiguration`, preview·test용 container 구성은 [SwiftData container, context, configuration 문서](./swiftdata-container-context-and-configuration.md)에 더 정리되어 있다.

### 같은 값이 들어가면 식별자는 어떻게 되는가

mock에서 `Todo(title: "Hello", ...)`를 여러 번 넣으면 어떻게 되는지도 함께 물었다. 짧게 답하면 이렇다.

- model마다 `persistentModelID`가 자동으로 있고, **값이 같아도 서로 다른 row**다.
- 그래서 mock을 반복 실행해 같은 제목을 넣으면 중복 row가 그대로 쌓인다. in-memory라 매번 초기화될 뿐이다.
- 업데이트는 fetch한 객체의 프로퍼티를 바꾸고 `save()`한다. 식별자는 유지되고 row 수도 늘지 않는다.
- 값 기준 유일성이 필요하면 `@Attribute(.unique)`를 명시해야 한다.

자세한 근거와 실측 결과는 [SwiftData의 식별자 문서](./swiftdata-identity-and-updates.md)에 있다.

### `@MainActor`가 붙은 이유

`mock` 본문에서 `container.mainContext`에 접근하는데, `mainContext`가 `@MainActor` 선언이라 접근하는 쪽도 main actor여야 한다. 지우면 컴파일 오류다. 자세한 배경은 [SwiftData 동시성과 context 격리](./swiftdata-concurrency-and-context-isolation.md)에 정리했다.

## 체크리스트

- [ ] `.modelContainer(_:)`가 `\.modelContext`를 채우는 것을 preview에서 `Add` 버튼으로 확인한다.
- [ ] `#Preview`에서 `.modelContainer(...)`를 지우고 어떤 오류가 나는지 본다.
- [ ] `Todo.mock`을 두 번 받아 `===`로 비교해 서로 다른 container임을 확인한다.
- [ ] in-memory configuration의 `url`을 출력해 `/dev/null`임을 확인한다.
- [ ] 같은 mock을 파일 URL store로 바꿔 접근할 때마다 row가 누적되는지 확인한다.
- [ ] `static let = { }()` 형태로 바꿔 preview 사이 상태 공유가 생기는지 확인한다.
- [ ] `try!`를 `try`로 바꾸고 실패 처리를 어떻게 할지 정리한다.
- [ ] 테스트마다 새 in-memory container를 만드는 테스트 두 개를 작성해 서로 영향이 없는지 확인한다.

## 공식 참고 자료

- [Apple: View.modelContainer(_:)](https://developer.apple.com/documentation/swiftui/view/modelcontainer(_:))
- [Apple: View.modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)](https://developer.apple.com/documentation/swiftui/view/modelcontainer(for:inmemory:isautosaveenabled:isundoenabled:onsetup:))
- [Apple: EnvironmentValues.modelContext](https://developer.apple.com/documentation/swiftui/environmentvalues/modelcontext)
- [Apple: Query](https://developer.apple.com/documentation/swiftdata/query)
- [Apple: ModelConfiguration.isStoredInMemoryOnly](https://developer.apple.com/documentation/swiftdata/modelconfiguration/isstoredinmemoryonly)
- [Apple: ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Apple: Previews in Xcode](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
- [Apple: Swift Testing](https://developer.apple.com/documentation/testing)
- [Swift Book: Properties — Type Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Type-Properties)
