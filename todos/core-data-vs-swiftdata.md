# Core Data와 SwiftData — 개념, 구조, 동시성, 마이그레이션과 선택 기준

## 질문이 나온 메모

`chapter-109/index.md`의 “SwiftData vs CoreData” 비교 메모에서 다음 질문이 생겼다.

- 둘은 데이터베이스인가, ORM인가, 영속성 프레임워크인가?
- `ModelContainer`, `ModelContext`는 Core Data의 무엇과 대응하는가?
- SwiftData의 동시성이 왜 더 좋다고 하는가? 실제로 더 빠른가?
- 복잡한 query와 relationship은 Core Data만 가능한가?
- 새 앱에서는 어떤 기준으로 둘 중 하나를 선택해야 하는가?
- 앱 업데이트로 모델이 바뀌면 기존 사용자 데이터는 어떻게 보존하는가?

## 1. 가장 먼저 잡을 mental model

### 데이터베이스 자체보다 넓은 “객체 그래프 관리 + 영속성” 프레임워크

Core Data와 SwiftData는 앱에서 사용하는 객체와 그 관계를 모델링하고, 변경을 추적하며, query하고, 저장소에 보존하는 프레임워크다.

```text
앱의 모델 객체
    │
    ├── identity 관리
    ├── 관계 관리
    ├── 변경 추적
    ├── validation / undo
    ├── query
    └── save
           │
           ▼
       영속 저장소
```

SQLite 저장소를 사용할 수 있지만 “SQLite를 객체 문법으로 감싼 것”이라고만 이해하면 context, identity, faulting, change tracking, migration 같은 핵심을 놓친다. 또한 객체의 프로퍼티를 바꿨다고 항상 즉시 디스크에 SQL 한 줄이 실행되는 구조도 아니다. 먼저 context가 변경을 추적하고 save 경계에서 저장소에 반영한다.

### 같은 개념을 다른 공개 API로 표현한다

완벽한 1:1 대응은 아니지만 학습을 시작할 때 다음 표가 유용하다.

| 역할 | Core Data | SwiftData |
|---|---|---|
| schema/model 정의 | `.xcdatamodeld`, `NSManagedObjectModel` | `@Model` 타입, `Schema` |
| 전체 persistence stack | `NSPersistentContainer` | `ModelContainer` |
| 작업 공간·변경 추적 | `NSManagedObjectContext` | `ModelContext` |
| 저장되는 객체 | `NSManagedObject` subclass | `@Model` class |
| query 조건 | `NSPredicate` | `#Predicate` |
| fetch 설명 | `NSFetchRequest` | `FetchDescriptor` |
| SwiftUI 조회 | `@FetchRequest`, `@SectionedFetchRequest` | `@Query` |
| schema migration | model version, mapping model, migration manager | `VersionedSchema`, `SchemaMigrationPlan`, `MigrationStage` |
| 동시성 도구 | context queue + `perform` | context isolation + `ModelActor` |

SwiftData를 배우면 Core Data의 container–context–model 구조가 사라지는 것이 아니라 Swift 문법과 macro에 맞게 보인다.

## 2. 세 핵심 객체: model, container, context

### Model: 무엇을 저장할지 정의한다

SwiftData에서는 일반 Swift class에 `@Model`을 붙여 schema에 참여시킨다.

```swift
import SwiftData

@Model
final class Note {
    var title: String
    var createdAt: Date

    init(title: String, createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
    }
}
```

Core Data에서는 model editor나 `NSManagedObjectModel`로 entity, attribute, relationship을 정의하고 `NSManagedObject` subclass 또는 generated class를 사용한다.

중요한 점은 model이 단순 DTO가 아니라 persistence schema의 일부라는 것이다. 프로퍼티 타입, optional 여부, uniqueness, relationship과 delete rule의 변경은 기존 저장 데이터와 migration에 영향을 준다.

### Container: schema와 저장소 구성을 소유한다

SwiftData의 `ModelContainer`는 schema와 저장소 configuration을 관리하고 context를 만든다.

```swift
@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)
    }
}
```

이 modifier는 container를 만들고 main `ModelContext`를 SwiftUI environment에 넣는다.

Core Data의 `NSPersistentContainer`는 managed object model을 바탕으로 persistent store coordinator와 context 구성을 묶어 제공한다.

```text
Container
 ├── Schema / Managed Object Model
 ├── Store configuration
 ├── Persistent store
 └── Context 생성·제공
```

container는 보통 앱이나 기능의 긴 수명을 가지며, 매 화면마다 새로 만드는 객체가 아니다. 테스트에서는 별도의 in-memory container를 만들어 production 저장소와 격리할 수 있다.

### Context: 데이터베이스 연결 하나가 아니라 작업 단위다

context는 가져온 객체를 추적하고 insert, update, delete를 모아 save하는 작업 공간이다.

```swift
@Environment(\.modelContext) private var context

let note = Note(title: "Context 이해하기")
context.insert(note)
try context.save()
```

```text
fetch / insert / property 변경 / delete
                 │
                 ▼
              Context
       identity + change tracking
                 │
              save()
                 ▼
                Store
```

같은 container에서도 UI용 context와 background import용 context를 나눌 수 있다. context의 경계는 동시성, 취소, rollback, 저장 시점과 오류 처리의 경계이기도 하다.

## 3. CRUD와 query는 어떻게 이어지는가

### SwiftData의 기본 흐름

```swift
@Query(
    filter: #Predicate<Note> { $0.title != "" },
    sort: \Note.createdAt,
    order: .reverse
)
private var notes: [Note]

@Environment(\.modelContext) private var context
```

- `@Query`: SwiftUI 화면이 query 결과를 구독하고 변경 시 다시 그린다.
- `#Predicate`: Swift compiler가 타입을 검사하는 query 조건이다.
- `FetchDescriptor`: View 밖에서 predicate, sort, fetch limit 등을 구성해 직접 fetch할 때 사용한다.
- `ModelContext`: insert, delete, fetch, save와 change tracking을 담당한다.

```swift
let predicate = #Predicate<Note> { note in
    note.title.contains("Swift")
}

var descriptor = FetchDescriptor<Note>(
    predicate: predicate,
    sortBy: [SortDescriptor(\Note.createdAt, order: .reverse)]
)
descriptor.fetchLimit = 20

let notes = try context.fetch(descriptor)
```

### Core Data의 기본 흐름

```swift
let request = NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
request.predicate = NSPredicate(format: "title CONTAINS %@", "Swift")
request.sortDescriptors = [
    NSSortDescriptor(key: "createdAt", ascending: false)
]
request.fetchLimit = 20

let notes = try context.fetch(request)
```

Core Data는 오랜 기간 축적된 fetch, batch update/delete, fetched results controller, persistent history, store와 migration 관련 API를 세밀하게 제공한다. SwiftData도 query와 batch 관련 기능을 계속 추가하고 있지만 최소 OS에 따라 사용할 수 있는 API가 달라진다.

### “Core Data만 복잡한 query가 가능하다”는 틀린 이분법

SwiftData도 다음을 지원한다.

- typed predicate 조합
- 여러 sort descriptor
- fetch limit과 offset
- relationship 탐색
- 관련 객체 prefetch
- aggregate 성격의 count fetch

다만 `#Predicate`가 임의의 Swift closure를 그대로 실행하는 것은 아니다. 저장소 query로 변환할 수 있는 표현만 지원하므로 복잡한 식은 compiler 오류가 나거나 식을 단순화해야 한다. Core Data도 `NSPredicate`가 지원하는 저장소 표현 범위라는 제약이 있다.

선택 전에 실제 production query 몇 개를 작은 spike로 구현해 보는 것이 추상적인 “복잡함” 분류보다 정확하다.

## 4. Relationship과 delete rule

SwiftData도 model 사이의 관계를 표현할 수 있다.

```swift
@Model
final class Folder {
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Note {
    var title: String
    var folder: Folder?

    init(title: String, folder: Folder? = nil) {
        self.title = title
        self.folder = folder
    }
}
```

- cardinality: to-one, to-many
- optional 여부: 관계가 필수인지 선택인지
- inverse: 반대편에서 같은 관계를 어떻게 보는지
- delete rule: 부모 삭제 시 관련 객체를 어떻게 처리할지

대표적인 delete rule의 의미는 다음과 같다.

| 규칙 | 의미 |
|---|---|
| `.nullify` | 삭제된 객체를 가리키던 관계를 `nil` 또는 관계 제거로 바꾼다. |
| `.cascade` | 관련 객체도 함께 삭제한다. |
| `.deny` | 관계가 남아 있으면 삭제를 막는다. |
| `.noAction` | 프레임워크가 관계를 자동으로 정리하지 않는다. |

복잡성은 관계 개수보다 소유권과 삭제 의미에서 생긴다. “Folder가 삭제되면 Note도 사라져야 하는가?”, “Note는 여러 곳에서 공유되는가?”를 먼저 답하고 delete rule을 정해야 한다.

## 5. Save, autosave, 오류 처리

SwiftUI와 SwiftData를 함께 쓰면 main context의 autosave가 기본으로 활성화될 수 있다. 시스템 이벤트나 주기적인 시점에 저장되므로 간단한 앱은 명시적 `save()`가 없어도 저장되는 것처럼 보인다.

그러나 autosave는 비즈니스 transaction의 성공 경계를 표현하지 않는다. 사용자가 “완료”를 눌렀을 때 저장 성공을 보장하거나 오류를 보여줘야 한다면 명시적으로 저장하고 오류를 처리한다.

```swift
do {
    context.insert(note)
    try context.save()
} catch {
    context.rollback()
    // 사용자에게 저장 실패를 알린다.
}
```

Core Data에서도 context에 변경이 생긴 것과 persistent store에 저장된 것은 다르다. `hasChanges`, `save()`, `rollback()`을 구분해야 한다. parent–child context를 쓸 때 child save는 parent로 올리는 단계이며, 최종 store 저장까지 별도의 parent save가 필요할 수 있다.

## 6. 동시성: “자동으로 빠름”이 아니라 “격리 규칙을 지켜야 함”

### Core Data

`NSManagedObjectContext`는 자신이 지정된 queue에서만 사용해야 한다.

```swift
container.performBackgroundTask { context in
    // 이 context와 여기서 가져온 managed object를 이 범위에서 사용
    try? context.save()
}
```

다른 queue로 managed object 자체를 넘기는 대신 `NSManagedObjectID`를 넘기고 대상 context에서 다시 조회하는 방식이 기본 원칙이다.

### SwiftData

`ModelContext`도 concurrency context 사이에 공유하는 객체가 아니다. 현재 SDK의 public interface에도 context를 concurrency context 사이에 공유할 수 없다고 명시되어 있다.

`@ModelActor`는 특정 `ModelContainer`와 context를 actor에 묶어 접근을 격리한다.

```swift
@ModelActor
actor NoteStore {
    func importNotes(_ inputs: [NoteInput]) throws {
        for input in inputs {
            modelContext.insert(Note(title: input.title))
        }
        try modelContext.save()
    }
}
```

핵심은 다음과 같다.

- actor isolation은 data race를 막는 구조다.
- 기본 `DefaultSerialModelExecutor`는 작업을 직렬화한다.
- actor를 썼다고 query나 disk I/O가 자동으로 Core Data보다 빨라지지는 않는다.
- 긴 import가 UI actor를 막지 않도록 별도 actor/context 경계를 설계한다.
- 경계를 넘길 때는 model 객체를 무작정 전달하기보다 stable identifier나 값 타입 DTO를 사용하는 방식이 안전하다.

성능과 안전성은 서로 다른 질문이다. concurrency API는 안전한 접근 규칙을 제공하고, 성능은 query plan, index, fetch 범위, 객체 수, 저장 빈도와 실제 측정 결과로 판단한다.

## 7. 메모리와 성능

“메모리가 중요하면 Core Data”나 “SwiftData concurrency가 더 빠르다”는 식으로 미리 결론 내리면 안 된다.

### 공통적으로 확인할 것

- 화면에 필요한 데이터만 predicate로 가져오는가?
- fetch limit, paging 또는 batch 처리가 필요한가?
- 큰 binary를 model에 직접 넣고 있지 않은가?
- N+1 관계 접근이 생기지 않는가?
- 정렬·검색에 자주 쓰는 필드에 index가 필요한가?
- 너무 자주 save하거나 한 context에 지나치게 많은 객체를 유지하지 않는가?
- Instruments의 Core Data template, Allocations, Time Profiler로 측정했는가?

Core Data는 faulting, fetch batch size, refresh, reset, batch operation 등 객체 수와 메모리를 세밀하게 조절해 온 API가 성숙하다. SwiftData는 더 높은 수준의 API로 시작하기 쉽지만, 최신 OS에서 index, batch enumeration, history 같은 기능도 확장되고 있다. 따라서 **최소 지원 OS에서 실제로 쓸 수 있는 API**를 확인해야 한다.

## 8. Schema 변경과 migration

앱을 출시한 뒤 model을 바꾸면 새 schema로 새 DB를 만드는 것이 아니라 사용자의 기존 데이터를 새 schema로 옮겨야 한다.

```text
Version 1 store
    │
    │ 앱 업데이트
    ▼
Version 2 schema
    │
    ├── 자동·경량 migration 가능한가?
    └── 값 변환이 필요한 custom migration인가?
```

SwiftData는 `VersionedSchema`와 `SchemaMigrationPlan`을 제공한다.

```swift
// NotesSchemaV2와 migrateV1toV2의 세부 정의는 생략
enum NotesSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Note.self]
    }
}

enum NotesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [NotesSchemaV1.self, NotesSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
}
```

Core Data는 model version과 lightweight migration을 제공하고, 단순 추론으로 처리할 수 없는 변환에는 mapping model이나 custom migration이 필요하다.

중요한 실무 원칙은 같다.

1. 출시한 schema version은 수정하지 않고 새 version을 만든다.
2. 실제 이전 버전 store fixture를 보관한다.
3. 빈 저장소뿐 아니라 기존 데이터가 있는 저장소로 migration test를 한다.
4. uniqueness, relationship, optional→required 변경과 데이터 변환을 특히 주의한다.
5. migration 실패 시 사용자 데이터를 삭제해 해결하지 않는다.

Apple은 기존 Core Data 앱이 SwiftData를 채택하는 공식 가이드도 제공한다. 전체를 한 번에 재작성하기보다 모델과 저장소 호환 조건, 최소 OS, coexistence 범위를 확인해 점진적으로 전환한다.

## 9. CloudKit과 동기화는 persistence와 별도 문제다

두 프레임워크 모두 CloudKit과 결합할 수 있지만 “로컬 저장이 된다”와 “여러 기기에서 충돌 없이 동기화된다”는 다른 수준의 문제다.

확인할 항목은 다음과 같다.

- 어떤 CloudKit database 범위를 사용하는가?
- offline 변경과 conflict를 어떻게 처리하는가?
- relationship과 uniqueness 제약이 동기화 조건을 만족하는가?
- remote change가 UI context에 언제 반영되는가?
- 계정 로그아웃, quota, 네트워크 실패를 어떻게 처리하는가?
- schema 변경을 CloudKit production 환경과 어떻게 조율하는가?

Core Data의 `NSPersistentCloudKitContainer`는 오래된 통합 경로이고, SwiftData의 `ModelConfiguration`도 CloudKit database 구성을 제공한다. 어느 쪽이든 동기화를 켜는 한 줄만 보고 선택하지 말고 실제 offline·충돌 시나리오를 테스트해야 한다.

## 10. 선택 기준

### SwiftData를 먼저 검토하기 좋은 경우

- 새로 만드는 Swift 중심 앱이다.
- 최소 지원 버전이 iOS 17 이상이다.
- SwiftUI의 `@Query`, environment `modelContext`, Observation 통합이 잘 맞는다.
- 필요한 query, relationship, migration과 동기화 기능이 목표 OS에서 지원된다.
- 팀이 macro와 Swift concurrency 중심 모델을 선호한다.

### Core Data를 먼저 검토하기 좋은 경우

- iOS 16 이하를 지원해야 한다.
- 기존 Core Data model·store·migration history가 크고 안정적으로 운영 중이다.
- Objective-C 코드나 `NSManagedObject` 기반 모듈과 통합해야 한다.
- 특정 batch API, fetched results controller, persistent history, store customization 등 검증된 Core Data API에 직접 의존한다.
- 장기간 운영된 진단·migration·성능 튜닝 경험을 그대로 활용해야 한다.

### 선택 기준으로 쓰면 안 되는 문장

```text
데이터가 복잡하다 → 무조건 Core Data
앱이 작다 → 무조건 SwiftData
메모리가 중요하다 → 무조건 Core Data
동시 작업이 있다 → SwiftData가 더 빠르다
```

대신 요구사항 표를 만든다.

| 질문 | 확인 결과 |
|---|---|
| 최소 OS는? | |
| 기존 store와 migration이 있는가? | |
| 필요한 query를 실제로 구현할 수 있는가? | |
| 관계와 delete rule은? | |
| background import 규모는? | |
| batch update/delete/history가 필요한가? | |
| CloudKit 동기화가 필요한가? | |
| Objective-C 연동이 필요한가? | |
| 측정한 시간·메모리 수치는? | |

## 11. 권장 학습 순서

```text
1. 객체 그래프와 영속성
   ↓
2. Model – Container – Context
   ↓
3. insert / fetch / update / delete / save
   ↓
4. Predicate / Sort / FetchDescriptor
   ↓
5. Relationship / inverse / delete rule
   ↓
6. Context 격리와 background 작업
   ↓
7. Schema version과 migration
   ↓
8. 성능 측정, history, CloudKit
```

처음부터 두 프레임워크의 API 이름을 모두 암기하기보다 작은 메모 앱을 SwiftData로 만든 뒤 같은 구조를 Core Data 용어로 매핑하면 차이가 잘 보인다.

## 12. 실습 체크리스트

- [ ] `Note`와 `Folder`를 만들어 to-one, to-many, inverse 관계를 설명한다.
- [ ] in-memory `ModelContainer`를 만들어 insert–fetch–update–delete test를 작성한다.
- [ ] `@Query`와 직접 `ModelContext.fetch(_:)`가 각각 View 구독과 명시적 fetch 중 무엇에 적합한지 비교한다.
- [ ] `#Predicate`에 검색어와 날짜 조건을 넣고 `FetchDescriptor`에 sort와 limit을 적용한다.
- [ ] `.nullify`와 `.cascade`를 각각 적용해 Folder 삭제 결과를 확인한다.
- [ ] autosave에만 맡긴 경우와 `save()` 오류를 직접 처리한 경우를 비교한다.
- [ ] `@ModelActor` 기반 background import를 만들고 UI context와 경계를 그림으로 설명한다.
- [ ] V1 store fixture를 만든 뒤 프로퍼티 추가·이름 변경을 V2로 migration한다.
- [ ] 같은 1만 건 데이터를 대상으로 fetch 범위와 save 횟수를 바꿔 시간·메모리를 측정한다.
- [ ] 최소 OS, 기존 저장소, query, migration, 동시성 요구사항 표를 작성한 뒤 프레임워크를 선택한다.

## 공식 문서와 개념 이해 자료

### 먼저 볼 WWDC 세션

1. [Apple WWDC23: Meet SwiftData](https://developer.apple.com/videos/play/wwdc2023/10187/) — `@Model`, container, context, predicate, fetch의 전체 흐름
2. [Apple WWDC23: Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/) — attribute, relationship, schema modeling
3. [Apple WWDC23: Dive deeper into SwiftData](https://developer.apple.com/videos/play/wwdc2023/10196/) — container, context, save, background 작업

각 영상 페이지에는 transcript와 sample code가 있어 영어 영상을 모두 듣지 않아도 코드 시점별로 따라갈 수 있다.

### SwiftData 공식 문서

- [Apple: SwiftData](https://developer.apple.com/documentation/swiftdata)
- [Apple: ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Apple: ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)
- [Apple: ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor)
- [Apple: FetchDescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor)
- [Apple: SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)

### Core Data 공식 문서

- [Apple: Core Data](https://developer.apple.com/documentation/coredata)
- [Apple: NSPersistentContainer](https://developer.apple.com/documentation/coredata/nspersistentcontainer)
- [Apple: Setting up a Core Data stack](https://developer.apple.com/documentation/coredata/setting-up-a-core-data-stack)
- [Apple: Using Core Data in the background](https://developer.apple.com/documentation/coredata/using-core-data-in-the-background)
- [Apple: Adopting SwiftData for a Core Data app](https://developer.apple.com/documentation/coredata/adopting-swiftdata-for-a-core-data-app)
- [Apple: Mirroring a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/mirroring-a-core-data-store-with-cloudkit)
