# SwiftData `ModelContainer`, `ModelContext`, configuration과 in-memory 저장소

## 질문이 나온 코드

`chapter-110/chapter-110/ContentView.swift`

```swift
@Environment(\.modelContext) var modelContext

Text(modelContext.container.configurations.debugDescription)
```

`chapter-110/chapter-110/chapter_110App.swift`

```swift
.modelContainer(for: Grocery.self)
```

질문은 다음과 같다.

- `ModelContext`와 `ModelContainer`는 왜 구분하는가?
- `configurations`는 무엇인가?
- model이 여러 개면 modifier를 여러 번 붙이는가?
- `inMemory`가 true일 때와 false일 때 무엇이 달라지는가?

## 공부할 내용

### 역할을 한 그림으로 보기

```text
ModelContainer
 ├── Schema: Grocery, Category, Store
 ├── ModelConfiguration A
 │     └── persistent store URL / CloudKit / read-write 설정
 ├── ModelConfiguration B
 │     └── 다른 store 설정
 └── ModelContext
       ├── fetch한 model identity 관리
       ├── insert / update / delete 추적
       ├── undo / rollback
       └── save
```

- **Container**: 어떤 model schema를 어떤 store 구성으로 운영할지 정하는 장수 객체다.
- **Configuration**: container 안의 특정 store가 사용할 schema 일부, URL, in-memory 여부, CloudKit 같은 저장 옵션이다.
- **Context**: 그 container를 대상으로 실제 fetch와 변경 작업을 수행하는 작업 공간이다.

### 왜 container와 context를 나누는가

앱의 schema와 store 위치는 오래 유지되지만 작업 단위와 concurrency 경계는 여러 개일 수 있다.

```text
하나의 ModelContainer
      │
      ├── main ModelContext       UI 조회·편집
      ├── import ModelContext     대량 import
      └── test/temporary context  독립 작업
```

container가 “어디에 어떤 구조로 저장할지”를 담당하고 context가 “지금 어떤 변경 묶음을 읽고 저장할지”를 담당하므로, 같은 store를 두고도 UI와 background 작업을 분리할 수 있다.

`modelContext.container`는 context가 어느 container에 연결됐는지 되돌아가는 참조다. `modelContext.debugDescription`과 `modelContext.container.configurations.debugDescription`이 다른 것은 각각 **작업 공간 객체**와 **저장 설정 목록**을 설명하기 때문이다.

### `debugDescription`을 화면에 표시하지 않기

`debugDescription`은 사람이 잠깐 진단하기 위한 문자열이며 앱 UI나 로직이 해석하는 안정적인 데이터 형식이 아니다.

```swift
for configuration in modelContext.container.configurations {
    print(configuration.name)
    print(configuration.url)
    print(configuration.isStoredInMemoryOnly)
}
```

필요한 정보는 공개 property로 읽고, 문자열 포맷에 의존하지 않는다.

### model이 여러 개면 한 schema로 함께 전달한다

관계가 있거나 같은 기능에 속한 model은 일반적으로 하나의 container schema에 함께 넣는다.

```swift
@Model final class Grocery { }
@Model final class Category { }
@Model final class Store { }
```

```swift
WindowGroup {
    ContentView()
}
.modelContainer(for: [
    Grocery.self,
    Category.self,
    Store.self
])
```

model마다 `.modelContainer` modifier를 반복해서 붙이는 방식은 보통 원하는 구성이 아니다. modifier는 하위 View environment에 하나의 main context를 제공하므로, 연속해서 붙이면 environment 경계와 container가 달라져 model 사이의 relationship을 같은 store에서 관리하기 어렵다.

### 여러 configuration이 필요한 경우

하나의 container에 여러 configuration을 명시적으로 만들 수도 있다.

```swift
let localConfiguration = ModelConfiguration(
    "Local",
    schema: Schema([Grocery.self])
)

let sharedConfiguration = ModelConfiguration(
    "Shared",
    schema: Schema([Category.self, Store.self])
)

let container = try ModelContainer(
    for: Grocery.self, Category.self, Store.self,
    configurations: localConfiguration, sharedConfiguration
)
```

실제 분리 가능 여부는 model relationship과 configuration schema가 겹치지 않는지 확인해야 한다. 단순 앱에서는 하나의 configuration이 이해하고 운영하기 쉽다. 저장 위치, CloudKit database 또는 읽기·쓰기 정책을 분리해야 할 명확한 요구가 있을 때 여러 configuration을 검토한다.

### 기본 persistent container

```swift
.modelContainer(for: Grocery.self)
```

기본값은 메모리 전용이 아니라 persistent store다. 앱을 종료하고 다시 실행해도 save된 데이터가 남는다.

```swift
.modelContainer(
    for: Grocery.self,
    inMemory: false
)
```

`false`가 기본이므로 보통 생략한다.

### in-memory container

```swift
.modelContainer(
    for: Grocery.self,
    inMemory: true
)
```

데이터가 disk의 production store에 영속되지 않고 container 수명 동안만 유지된다. 앱 process나 해당 container가 사라지면 데이터도 사라진다.

적합한 용도는 다음과 같다.

- unit test
- Xcode Preview
- sample/demo mode
- 임시 계산이나 사용자가 저장을 명시하기 전 draft

실제 사용자 데이터 저장에는 적합하지 않다.

### Preview에는 별도 container를 주입한다

현재 `ContentView`와 `CreateNewGroceryView` Preview는 environment에 model container가 없으면 실행 중 오류가 날 수 있다.

```swift
#Preview {
    ContentView()
        .modelContainer(
            for: Grocery.self,
            inMemory: true
        )
}
```

fixture까지 넣으려면 container를 직접 만든다.

```swift
@MainActor
func previewContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
        isStoredInMemoryOnly: true
    )
    let container = try ModelContainer(
        for: Grocery.self,
        configurations: configuration
    )

    container.mainContext.insert(
        Grocery(name: "Apple", desc: "Fruit")
    )
    return container
}
```

### Test에서는 매 test마다 격리한다

```swift
@Test
func insertsGrocery() throws {
    let configuration = ModelConfiguration(
        isStoredInMemoryOnly: true
    )
    let container = try ModelContainer(
        for: Grocery.self,
        configurations: configuration
    )
    let context = ModelContext(container)

    context.insert(Grocery(name: "Milk", desc: "Dairy"))
    try context.save()

    let count = try context.fetchCount(FetchDescriptor<Grocery>())
    #expect(count == 1)
}
```

in-memory라고 해서 persistence 로직이 사라지는 것은 아니다. insert, change tracking, query와 save 흐름은 검증하되 실제 file I/O와 migration 검증에는 별도의 disk store fixture가 필요하다.

### Context와 concurrency

main context는 UI 작업에 편리하지만 대량 import를 오래 실행하면 UI가 멈출 수 있다. 별도 context 또는 `@ModelActor`로 작업을 격리한다.

```text
ModelContainer는 공유 가능한 구성의 중심
ModelContext는 concurrency context 사이에 공유하지 않음
Model instance 전달도 경계를 신중히 관리
```

container가 같다는 사실이 context를 아무 thread에서나 써도 된다는 뜻은 아니다.

## 체크리스트

- [ ] container, configuration, context의 역할을 한 문장씩 설명한다.
- [ ] `debugDescription` 대신 configuration의 공개 property를 출력한다.
- [ ] `Grocery`, `Category`를 하나의 `.modelContainer(for: [...])`에 등록한다.
- [ ] model마다 modifier를 반복했을 때 environment가 어떻게 달라지는지 확인한다.
- [ ] persistent store에서 앱 재실행 후 데이터가 남는지 확인한다.
- [ ] `inMemory: true`에서 앱을 재실행해 데이터가 사라지는지 확인한다.
- [ ] Preview에 in-memory container와 fixture를 주입한다.
- [ ] unit test마다 새 in-memory container를 만들어 test 격리를 확인한다.
- [ ] migration test에는 왜 disk store fixture가 필요한지 설명한다.

## 공식 참고 자료

- [Apple: ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Apple: ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)
- [Apple: ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration)
- [Apple: View.modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)](https://developer.apple.com/documentation/swiftui/view/modelcontainer(for:inmemory:isautosaveenabled:isundoenabled:onsetup:))
- [Apple WWDC23: Dive deeper into SwiftData](https://developer.apple.com/videos/play/wwdc2023/10196/)
