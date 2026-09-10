# SwiftData의 식별자 — `PersistentIdentifier`, 중복 데이터와 업데이트

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

model에 `id`나 primary key를 선언하지 않았다. 질문은 다음과 같다.

- 식별자 키가 없는데 같은 데이터인지 아닌지 어떻게 판단하는가?
- 업데이트는 어떻게 하는가?
- 업데이트했는데 값이 똑같은 row가 이미 있으면 하나가 사라지는가?
- 영속성과 식별성은 각각 어떻게 처리되는가?

## 공부할 내용

### 결론 먼저

- 우리가 선언하지 않았을 뿐, 모든 `@Model`에는 **`persistentModelID`라는 식별자가 자동으로 있다**.
- 식별은 **값이 아니라 이 식별자**로 한다. 값이 완전히 같아도 서로 다른 row다.
- 업데이트는 `UPDATE` 문을 쓰는 게 아니라 **fetch한 객체의 프로퍼티를 바꾸고 save**한다.
- 값이 같다고 row가 합쳐지거나 사라지지 않는다. 합치고 싶으면 **`@Attribute(.unique)`를 명시**해야 한다.

### 자동으로 생기는 식별자

`@Model`을 붙이면 `PersistentModel`을 준수하게 되고, 다음이 따라온다.

```swift
public var persistentModelID: SwiftData.PersistentIdentifier { get }
public var id: SwiftData.PersistentIdentifier { get }   // Identifiable 준수
public static func == (lhs: Self, rhs: Self) -> Bool
public func hash(into hasher: inout Hasher)
```

그래서 `List(todos)`처럼 `Identifiable`을 요구하는 API에 `Todo`를 그대로 넘길 수 있다. `id`를 직접 선언하지 않아도 되는 이유가 이것이다.

`PersistentIdentifier`의 구조는 다음과 같다.

```swift
public struct PersistentIdentifier: Hashable, Identifiable, Equatable, Comparable, Codable, Sendable {
    public let id: PersistentIdentifier.ID
    public var entityName: String { get }        // 예: "Todo"
    public var storeIdentifier: String? { get }  // 어느 store의 데이터인지
}
```

```text
persistentModelID
    = 어느 store의 (storeIdentifier)
      어떤 entity인지 (entityName)
      그 안에서 어떤 row인지 (id)
```

**어떤 저장소의 어떤 row인가**를 가리키는 좌표이지, 사용자에게 보여 줄 업무용 키가 아니다. 주문 번호나 사번처럼 도메인에서 의미 있는 키가 필요하면 그것은 별도 프로퍼티로 직접 만든다.

### 값이 같으면 같은 데이터인가 — 아니다

직접 확인한 결과다.

```swift
let t1 = Todo(title: "같은값", isCompleted: false)
let t2 = Todo(title: "같은값", isCompleted: false)
context.insert(t1)
context.insert(t2)
try context.save()
```

```text
row 수                       = 2
t1.persistentModelID == t2   = false
t1 == t2                     = false
t1.persistentModelID.entityName = "Todo"
```

SwiftData는 값을 비교하지 않는다. **insert한 객체 하나가 row 하나**다. 같은 값을 두 번 넣으면 중복 row가 두 개 생긴다.

`==`도 값 비교가 아니라 식별자 비교다. `Todo`는 class이므로 애초에 값 타입 의미의 동등성이 아니다. 이 부분은 [`struct`와 `class`](./struct-vs-class.md), [`@Model`은 왜 class인가](./swiftdata-model-class-and-final.md)와 이어진다.

### 임시 식별자와 영구 식별자

`insert` 직후와 `save` 이후의 식별자는 다르다.

```swift
let fresh = Todo(title: "임시", isCompleted: false)
context.insert(fresh)
let before = fresh.persistentModelID
try context.save()
// before == fresh.persistentModelID  →  false
```

- `insert` 직후에는 저장소에 자리가 없으므로 **임시(temporary) 식별자**를 갖는다.
- `save` 후 실제 row가 만들어지면 **영구 식별자**로 바뀐다.

그래서 다음을 주의한다.

- `save` 전에 얻은 식별자를 화면 상태나 다른 저장소에 오래 보관하지 않는다.
- 식별자를 `SceneStorage`나 deep link로 넘겨야 하면 반드시 **save 이후**의 값을 쓴다.
- SwiftUI에는 `@SceneStorage`가 `PersistentIdentifier`를 직접 받는 초기화가 준비되어 있다.

### 업데이트하는 방법

SQL처럼 `UPDATE ... WHERE ...`를 작성하지 않는다. **가져온 객체를 그냥 수정한다.**

```swift
let descriptor = FetchDescriptor<Todo>(
    predicate: #Predicate { $0.title == "같은값" }
)
guard let todo = try context.fetch(descriptor).first else { return }

todo.isCompleted = true      // 이 시점에 context가 변경을 추적한다
try context.save()           // 저장소에 반영된다
```

확인한 결과는 다음과 같다.

```text
프로퍼티 변경 후 context.hasChanges = true
save 후 persistentModelID           = 변경 전과 동일
save 후 row 수                      = 그대로 (새 row가 생기지 않음)
```

즉 **업데이트는 식별자를 유지한 채 값만 바꾼다**. 값이 같은 row가 이미 있어도 하나가 사라지지 않는다. 질문의 "하나는 사라지는건가"에 대한 답은 **아니오**다.

이게 가능한 이유는 [매크로 확장 결과](./swift-macros-and-build-pipeline.md)에 있다. `var title: String`이 저장소를 읽고 쓰는 accessor로 바뀌기 때문에, 프로퍼티 대입이 곧 저장소 변경 추적이 된다.

```swift
set {
    _$observationRegistrar.withMutation(of: self, keyPath: \.title) {
        self.setValue(forKey: \.title, to: newValue)
    }
}
```

### 진짜 중복을 막고 싶다면 — `@Attribute(.unique)`

값 기준으로 유일성을 원하면 명시해야 한다.

```swift
@Model
final class UniqueTodo {
    @Attribute(.unique) var title: String
    var isCompleted: Bool

    init(title: String, isCompleted: Bool) {
        self.title = title
        self.isCompleted = isCompleted
    }
}
```

같은 `title`로 두 번 insert한 결과다.

```swift
context.insert(UniqueTodo(title: "U", isCompleted: false))
try context.save()
context.insert(UniqueTodo(title: "U", isCompleted: true))
try context.save()
```

```text
row 수      = 1
isCompleted = [true]
```

두 번째 insert가 오류가 되지도 않고, row가 두 개가 되지도 않는다. **기존 row를 찾아 값을 갱신하는 upsert**로 동작한다. 여기서는 `isCompleted`가 `false`에서 `true`로 덮였다.

그래서 `.unique`는 다음 성격을 갖는다.

- 서버에서 내려온 데이터를 반복 동기화할 때 유용하다. 같은 키면 갱신된다.
- 반대로 **의도치 않은 덮어쓰기**도 쉽게 일어난다. 부분 갱신을 원했는데 전체가 덮일 수 있다.
- 유일 키로 쓸 값은 정말 변하지 않는 값이어야 한다. 사용자가 바꿀 수 있는 제목 같은 값은 위험하다.

iOS 18부터는 여러 프로퍼티를 묶은 compound uniqueness와 `#Index`도 있다. 목표 OS에서 사용 가능한지 먼저 확인한다.

### 특정 데이터를 찾아 업데이트하는 세 가지 방법

| 상황 | 방법 |
|---|---|
| 화면에서 사용자가 고른 항목 | 그 객체를 그대로 수정 (`@Query` 결과의 요소) |
| 식별자만 알고 있음 | `context.model(for: id)` 또는 `context.registeredModel(for: id)` |
| 조건으로 찾아야 함 | `FetchDescriptor` + `#Predicate`로 fetch 후 수정 |

```swift
// 식별자로 되찾기
if let todo: Todo = context.registeredModel(for: someID) {
    todo.isCompleted = true
}
```

`model(for:)`는 필요하면 저장소에서 가져오고, `registeredModel(for:)`는 이미 그 context에 올라와 있는 객체만 돌려준다.

### 식별자는 스레드를 건너도 안전하다

`PersistentIdentifier`는 `Sendable`이지만 `Todo` 같은 model 객체는 아니다. 매크로 확장 결과에 이 규칙이 그대로 적혀 있다.

```swift
@available(*, unavailable, message: "PersistentModels are not Sendable, consider utilizing a ModelActor or use Todo's persistentModelID instead")
extension Todo: Sendable {}
```

```text
actor / context 경계를 넘길 때
    model 객체를 넘긴다        → 금지
    persistentModelID를 넘긴다 → 권장, 받는 쪽에서 다시 조회
```

자세한 내용은 [SwiftData 동시성과 context 격리](./swiftdata-concurrency-and-context-isolation.md)에서 다룬다.

### 영속성과 식별성을 나눠서 보기

| 질문 | 담당 |
|---|---|
| 이 데이터가 앱을 껐다 켜도 남는가 | store 종류 (in-memory인지 파일인지) |
| 두 객체가 같은 데이터인가 | `persistentModelID` |
| 같은 값이 두 번 저장되는 걸 막는가 | `@Attribute(.unique)` 선언 여부 |
| 변경이 언제 반영되는가 | `save()` 또는 autosave |
| 화면이 언제 갱신되는가 | Observation + `@Query` |

이 다섯 개는 서로 다른 문제다. "식별자가 없으니 중복이 알아서 정리되겠지"처럼 묶어서 생각하면 어긋난다.

## 체크리스트

- [ ] `Todo`에 `id`를 선언하지 않았는데 `List`에 넘길 수 있는 이유를 설명한다.
- [ ] 같은 값으로 두 번 insert한 뒤 row 수와 `persistentModelID`를 출력해 확인한다.
- [ ] `insert` 직후와 `save` 직후의 `persistentModelID`가 다른 것을 확인한다.
- [ ] fetch → 프로퍼티 변경 → save로 업데이트하고 row 수가 늘지 않는지 확인한다.
- [ ] `@Attribute(.unique)`를 붙인 뒤 같은 키로 두 번 insert해 upsert 동작을 확인한다.
- [ ] `.unique`로 인해 원치 않게 값이 덮이는 경우를 하나 만들어 본다.
- [ ] `context.registeredModel(for:)`로 식별자에서 객체를 되찾는다.
- [ ] 도메인 키(예: 서버 id)와 `persistentModelID`를 각각 언제 쓰는지 정리한다.

## 공식 참고 자료

- [Apple: PersistentIdentifier](https://developer.apple.com/documentation/swiftdata/persistentidentifier)
- [Apple: PersistentModel](https://developer.apple.com/documentation/swiftdata/persistentmodel)
- [Apple: PersistentModel.persistentModelID](https://developer.apple.com/documentation/swiftdata/persistentmodel/persistentmodelid)
- [Apple: Attribute() macro](https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:))
- [Apple: Schema.Attribute.Option.unique](https://developer.apple.com/documentation/swiftdata/schema/attribute/option/unique)
- [Apple: ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)
- [Apple: Preserving your app's model data across launches](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
- [Apple WWDC23: Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/)
