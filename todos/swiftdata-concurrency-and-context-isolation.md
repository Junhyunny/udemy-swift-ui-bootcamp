# SwiftData 동시성 — 메인 스레드, 동일 context, 데이터 충돌과 `@MainActor`

## 질문이 나온 코드

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
        return container
    }
}
```

강사가 이 코드를 쓰기 전에 "동일 context, 메인 스레드, 데이터 충돌, 동시성 이슈"를 설명했다. 질문은 다음과 같다.

- 이렇게 안 하면 데이터 충돌이나 문제가 생기는가?
- iOS는 여러 스레드가 동시에 하나의 저장소에 접근해 충돌이 날 수 있는 구조인가?
- 스레드 구조, 동시성 이슈, 데이터 충돌, 메인 스레드, 동일 context는 각각 무엇인가?
- 메서드 위의 `@MainActor`는 무슨 의미인가?

iOS 스레드 모델과 `@MainActor`의 일반 개념은 [`MainActor`는 왜 필요한가 — iOS의 스레드 모델](./main-actor-and-ios-threading.md)에 정리되어 있다. 이 문서는 **SwiftData에 한정된 규칙**을 다룬다.

## 공부할 내용

### 결론 먼저

- iOS는 실제로 여러 스레드가 동시에 도는 구조가 맞다. 그래서 규칙이 필요하다.
- SwiftData의 규칙은 단순하다. **container는 공유해도 되고, context와 model 객체는 공유하면 안 된다.**
- 이 코드의 `@MainActor`는 **`container.mainContext`가 main actor에 격리되어 있기 때문에** 필요하다. 없으면 컴파일이 되지 않는다.
- 충돌 위험의 본질은 "여러 스레드가 같은 SQLite 파일을 동시에 건드린다"가 아니라 **"같은 객체를 서로 다른 실행 문맥에서 만진다"**이다.

### 무엇이 공유 가능한가

SDK 선언이 규칙을 그대로 말해 준다.

```swift
public class ModelContainer : Equatable, @unchecked Sendable { ... }

@MainActor public var mainContext: ModelContext { get }   // ModelContainer의 프로퍼티

@available(*, unavailable, message: "PersistentModels are not Sendable, consider utilizing a ModelActor or use Todo's persistentModelID instead")
extension Todo: Sendable {}
```

| 대상 | 공유 | 근거 |
|---|---|---|
| `ModelContainer` | 가능 | `@unchecked Sendable`, 앱 전체에서 하나를 공유하는 것이 기본 |
| `mainContext` | main actor 전용 | 선언 자체가 `@MainActor` |
| 직접 만든 `ModelContext` | 만든 실행 문맥 안에서만 | 작업 단위 객체 |
| `@Model` 객체 (`Todo`) | **불가** | `Sendable` 준수가 명시적으로 사용 불가 처리됨 |
| `PersistentIdentifier` | 가능 | `Sendable` |

```text
ModelContainer  ← 하나, 공유 가능
      │
      ├── mainContext (main actor 전용)      → UI가 쓰는 작업 공간
      └── ModelContext(container) (별도)      → background 작업 공간
```

### `@MainActor`가 이 코드에 필요한 이유

`mock` 안에서 `container.mainContext`에 접근한다. 그런데 `mainContext`는 `@MainActor`로 선언되어 있다. 따라서 이 프로퍼티를 동기적으로 쓰려면 **접근하는 쪽도 main actor에 있어야 한다**.

```swift
@MainActor                    // ← 이게 없으면
static var mock: ModelContainer {
    ...
    container.mainContext.insert(...)   // ← 여기서 컴파일 오류
}
```

`@MainActor`를 지우면 "main actor-isolated property 'mainContext' can not be referenced from a nonisolated context" 계열의 **컴파일 오류**가 난다. 런타임에 몰래 깨지는 게 아니라 컴파일러가 막는다.

즉 이 `@MainActor`는 성능이나 안전을 위한 관례적 장식이 아니라 **타입 시스템이 요구하는 필수 표기**다.

`@MainActor`가 하는 일을 두 층으로 나누면 이렇다.

| 층 | 하는 일 |
|---|---|
| 컴파일 타임 | 이 선언이 main actor 격리임을 기록하고, 다른 격리 문맥에서 `await` 없이 접근하면 오류 |
| 런타임 | 다른 문맥에서 호출하면 main actor executor로 hop 후 실행 |

`@MainActor`가 매크로가 아니라 attribute인 이유는 [Swift macro와 빌드 파이프라인](./swift-macros-and-build-pipeline.md)에 정리했다.

### iOS는 정말 여러 스레드가 동시에 도는가

그렇다.

```text
Main thread            UI 이벤트, 레이아웃, 렌더링 커밋
URLSession delegate    네트워크 응답 처리
Task / TaskGroup       Swift concurrency 협동 스레드 풀
DispatchQueue.global   백그라운드 작업
Notification / Timer   등록한 큐에서 실행
```

앱 하나 안에서 이 스레드들이 실제로 동시에 돈다. 그러므로 "저장소는 하나인데 아무 데서나 접근하면 문제가 생기는 구조인가"라는 질문의 답은 **그렇다**이다. 다만 위험의 지점을 정확히 볼 필요가 있다.

### 무엇이 실제 위험인가

SQLite 파일 자체는 여러 연결이 접근할 수 있게 설계되어 있다. SwiftData가 만드는 store 옆에 `-wal`, `-shm` 파일이 함께 생기는 것도 그 때문이다.

```text
Todos.store        본체
Todos.store-wal    write-ahead log
Todos.store-shm    공유 메모리 인덱스
```

실제 위험은 파일 계층이 아니라 **그 위의 객체 계층**에 있다.

| 위험 | 설명 |
|---|---|
| 객체 경합 | 같은 `Todo` 인스턴스를 두 스레드가 동시에 읽고 쓰면 내부 상태가 깨진다 |
| context 경합 | 하나의 `ModelContext`를 여러 스레드가 동시에 쓰면 변경 추적이 깨진다 |
| UI 갱신 위치 | model 변경이 SwiftUI 갱신을 유발하므로 main이 아닌 곳에서 UI 상태를 흔들 수 있다 |
| 갱신 유실 | 서로 다른 context가 같은 row를 각자 수정한 뒤 순서대로 save하면 나중 save가 앞의 변경을 덮을 수 있다 |

앞의 세 개는 **컴파일러가 막아 주는 영역**이다. `Todo`가 `Sendable`이 아니고 `mainContext`가 `@MainActor`이므로, 잘못된 코드는 대개 빌드가 되지 않는다. Swift 6 언어 모드에서는 특히 엄격하다.

네 번째는 컴파일러가 막지 못한다. **설계로 풀어야 하는 문제**다.

### 같은 context, 다른 context

`ModelContext`는 "작업 공간"이다. 같은 container에서 만든 context 두 개는 같은 저장소를 보지만 **각자의 변경 목록을 따로 갖는다**.

```text
context A: todo.isCompleted = true    (아직 save 안 함)
context B: 같은 row를 fetch           → 아직 false로 보인다
context A: save()                     → 저장소는 true
context B: 자기 값으로 save()          → true가 다시 덮일 수 있다
```

그래서 원칙은 이렇게 정리된다.

- **한 화면의 흐름은 하나의 context 안에서** 끝낸다. 이게 "동일 context"의 의미다.
- 백그라운드 작업은 **자기 context를 따로** 만들고, 끝난 뒤 저장한다.
- context 사이에는 객체가 아니라 `persistentModelID`를 넘긴다.

context가 지금 무엇을 들고 있는지는 다음으로 확인할 수 있다.

```swift
context.hasChanges
context.insertedModelsArray
context.changedModelsArray
context.deletedModelsArray
context.rollback()          // 저장하지 않은 변경 버리기
try context.transaction { } // 여러 변경을 한 단위로 묶기
```

SwiftData는 Core Data의 merge policy 같은 공개 충돌 해결 정책을 노출하지 않는다. 따라서 **같은 row를 여러 곳에서 동시에 고치는 설계를 애초에 피하는 편**이 안전하다. 갱신 순서가 중요하면 서버 타임스탬프나 버전 필드처럼 도메인 규칙을 직접 둔다.

### 백그라운드 작업은 `@ModelActor`로

대량 import처럼 오래 걸리는 작업을 main context에서 하면 화면이 멈춘다.

```swift
@ModelActor
actor TodoImporter {
    func importTitles(_ titles: [String]) throws {
        for title in titles {
            modelContext.insert(Todo(title: title, isCompleted: false))
        }
        try modelContext.save()
    }
}

// 사용하는 쪽
let importer = TodoImporter(modelContainer: container)
try await importer.importTitles(titles)
```

`@ModelActor` 매크로가 `modelContainer`, `modelExecutor`, `init(modelContainer:)`를 만들어 준다. 이 actor 안의 `modelContext`는 **그 actor의 executor에 묶인 전용 context**다.

결과를 UI로 가져올 때는 model 객체가 아니라 식별자나 값 타입을 넘긴다.

```text
background actor          main actor
  Todo 객체        ──✗──▶   (Sendable 아님)
  persistentModelID ──✓──▶  context.model(for:)로 다시 조회
  구조체 DTO        ──✓──▶  화면 표시 전용
```

### 그래서 예제 코드는 문제가 있는가

`Todo.mock`은 preview 전용이고, main actor에서 in-memory container를 만들고 mainContext에만 접근한다. **동시성 관점에서는 올바른 코드**다.

다만 별개의 문제가 하나 있다.

```swift
let container = try! ModelContainer(...)
```

`try!`는 실패하면 즉시 크래시한다. preview나 test 픽스처에서는 흔히 쓰지만, 앱 실행 경로에는 쓰지 않는다. 그리고 이 `mock`이 computed property라서 접근할 때마다 새 container가 만들어진다는 점은 [Preview의 mock container 문서](./swiftdata-preview-mock-container.md)에서 따로 다룬다.

### 정리 표

| 개념 | 한 줄 정의 | 이 코드에서 |
|---|---|---|
| 메인 스레드 | UI를 그리고 이벤트를 처리하는 단일 스레드 | `mainContext`가 여기에 묶여 있다 |
| main actor | 메인 스레드 실행을 타입 시스템으로 보장하는 global actor | `@MainActor static var mock` |
| context | 변경을 추적하는 작업 공간 | `container.mainContext` |
| 동일 context | 한 흐름의 읽기·수정·저장을 한 작업 공간에서 처리 | insert 두 번이 같은 mainContext |
| 동시성 이슈 | 여러 실행 문맥이 같은 상태를 동시에 만짐 | model 객체·context 공유 금지로 방지 |
| 데이터 충돌 | 서로 다른 context의 변경이 서로를 덮음 | 별도 context 설계에서 주의 |

## 체크리스트

- [ ] `@MainActor`를 지우고 어떤 컴파일 오류가 나는지 직접 확인한다.
- [ ] `mainContext` 선언에 붙은 `@MainActor`를 SDK interface에서 찾아 읽는다.
- [ ] `Todo`를 `Task.detached` 안으로 넘겨 보고 컴파일 오류 메시지를 확인한다.
- [ ] `persistentModelID`를 넘긴 뒤 `context.model(for:)`로 되찾는 코드를 작성한다.
- [ ] `@ModelActor`로 import actor를 만들고 main context와 경계를 그림으로 설명한다.
- [ ] 같은 row를 두 context에서 수정한 뒤 순서대로 save해 갱신이 덮이는지 확인한다.
- [ ] `hasChanges`, `rollback()`, `transaction(block:)`의 동작을 각각 확인한다.
- [ ] store 옆의 `-wal`, `-shm` 파일을 직접 확인한다.

## 공식 참고 자료

- [Apple: ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)
- [Apple: ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Apple: ModelContainer.mainContext](https://developer.apple.com/documentation/swiftdata/modelcontainer/maincontext)
- [Apple: ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor)
- [Apple: ModelActor() macro](https://developer.apple.com/documentation/swiftdata/modelactor())
- [Apple: ModelExecutor](https://developer.apple.com/documentation/swiftdata/modelexecutor)
- [Apple: Updating an app to use strict concurrency](https://developer.apple.com/documentation/swift/updating-an-app-to-use-strict-concurrency)
- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Swift Book: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple WWDC24: Track model changes with SwiftData history](https://developer.apple.com/videos/play/wwdc2024/10075/)
- [SQLite: Write-Ahead Logging](https://www.sqlite.org/wal.html)
