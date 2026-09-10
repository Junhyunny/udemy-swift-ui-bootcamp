# SwiftData `@Query` — 실행 시점, 조건·정렬과 query 디버깅

## 질문이 나온 코드

`chapter-110/chapter-110/ContentView.swift`

```swift
@Query private var groceries: [Grocery]
```

질문은 다음과 같다.

- `@Query`를 붙이면 자동으로 query가 실행되는가?
- View의 `body`가 계산될 때마다 저장소를 다시 읽는가?
- 조건과 정렬은 어떻게 지정하는가?
- 실제 query와 성능은 어떻게 관찰하는가?

## 공부할 내용

### `@Query`의 역할

`@Query`는 SwiftUI environment의 `ModelContext`를 이용해 SwiftData model을 가져오고, 관련 변경을 관찰해 View를 갱신하는 dynamic property다.

```text
ModelContainer
    └── ModelContext (environment)
            │
          @Query
            │ fetch + observe
            ▼
       [Grocery]
            │
            ▼
        SwiftUI View
```

따라서 “자동으로 query를 보낸다”는 설명은 대체로 맞지만 두 가지를 보정해야 한다.

1. 서버에 network request를 보내는 기능이 아니라 연결된 persistent store에서 model을 fetch한다.
2. `body` 평가 한 번마다 SQL이 반드시 한 번 실행된다고 보장되는 API가 아니다. SwiftData가 context 상태와 저장소 변경을 바탕으로 fetch와 결과 갱신을 관리한다.

View는 query 결과를 선언하고, framework가 적절한 시점에 결과를 공급한다. 정확한 disk 접근 횟수는 공개 API 계약이 아니므로 `print(body)`만 보고 판단하지 않는다.

### 조건 없는 기본 query

```swift
@Query private var groceries: [Grocery]
```

이 선언은 현재 context에서 `Grocery` 전체를 대상으로 한다. 데이터가 많아지면 화면에 필요한 범위만 가져오도록 predicate, sort 또는 별도의 fetch/paging 설계를 검토한다.

### 정렬 지정

```swift
@Query(sort: \Grocery.name)
private var groceries: [Grocery]
```

여러 정렬 기준이나 내림차순이 필요하면 `SortDescriptor` 배열을 사용한다.

```swift
@Query(sort: [
    SortDescriptor(\Grocery.name, order: .forward),
    SortDescriptor(\Grocery.desc, order: .reverse)
])
private var groceries: [Grocery]
```

정렬 결과가 항상 안정적이어야 한다면 동일한 `name`을 가진 row를 구분할 두 번째 기준을 둔다.

### 조회 조건 지정

```swift
@Query(
    filter: #Predicate<Grocery> { grocery in
        grocery.name != ""
    },
    sort: \Grocery.name
)
private var groceries: [Grocery]
```

`#Predicate`는 일반 closure처럼 보이지만 저장소 query로 변환할 수 있는 표현만 사용할 수 있다. 지원되지 않는 함수 호출이나 지나치게 복잡한 식은 macro compile 오류 또는 저장소 변환 문제를 일으킬 수 있다.

### 화면에서 바뀌는 조건

검색어처럼 runtime 값으로 query 구성을 바꿔야 한다면 View initializer에서 backing property인 `_groceries`를 구성할 수 있다.

```swift
struct GroceryList: View {
    @Query private var groceries: [Grocery]

    init(searchText: String) {
        let text = searchText
        _groceries = Query(
            filter: #Predicate<Grocery> { grocery in
                text.isEmpty || grocery.name.localizedStandardContains(text)
            },
            sort: [SortDescriptor(\Grocery.name)]
        )
    }

    var body: some View {
        List(groceries) { grocery in
            Text(grocery.name)
        }
    }
}
```

지원 OS에서 predicate가 해당 문자열 연산을 저장소 query로 변환할 수 있는지 실제 데이터로 확인한다. 복잡한 동적 query, paging 또는 View 밖의 fetch라면 `FetchDescriptor`와 `ModelContext.fetch(_:)`가 더 명시적이다.

```swift
var descriptor = FetchDescriptor<Grocery>(
    predicate: #Predicate { $0.name != "" },
    sortBy: [SortDescriptor(\Grocery.name)]
)
descriptor.fetchLimit = 100

let groceries = try modelContext.fetch(descriptor)
```

### `@Query`와 직접 fetch의 선택

| 상황 | 적합한 방식 |
|---|---|
| View가 결과를 계속 표시하고 변경에 반응 | `@Query` |
| 버튼 동작에서 한 번만 조회 | `ModelContext.fetch` |
| ViewModel·actor·service 안에서 조회 | `FetchDescriptor` + context |
| count만 필요 | `fetchCount` |
| 대량 처리 | batch fetch 또는 `enumerate` 검토 |

### `debugDescription`은 query log가 아니다

`modelContext.debugDescription`은 객체의 설명 문자열일 뿐이다. “어떤 SQL이 몇 ms 걸렸는가”를 보장해서 보여 주는 query profiler가 아니다.

query를 관찰할 때는 목적을 나눈다.

1. **정확성**: predicate, sort와 결과를 test에서 검증한다.
2. **호출 범위**: fetch 전후에 signpost를 남겨 기능 단위 시간을 측정한다.
3. **메모리·시간**: Instruments의 Time Profiler, Allocations와 Core Data 관련 도구를 사용한다.
4. **저장소 진단**: 개발 환경에서 Core Data SQL debug launch argument를 제한적으로 사용한다.

Xcode Scheme의 Run → Arguments에 다음 launch argument를 추가하면 Core Data SQL 진단 로그를 볼 수 있는 환경이 있다.

```text
-com.apple.CoreData.SQLDebug 1
```

숫자를 높이면 로그가 많아질 수 있다. 이 출력은 구현 세부사항을 포함한 개발용 진단이며 SwiftData의 영구적인 공개 API 계약이 아니다. 개인정보가 포함될 수 있으므로 production logging으로 사용하지 않는다.

### 성능을 확인하는 실험

동일한 fixture로 다음을 각각 측정한다.

```text
전체 fetch
predicate fetch
sort만 적용
predicate + sort
index 적용 전후
fetchLimit 100 적용 전후
relationship prefetch 전후
```

query 횟수만 줄이는 것이 목표는 아니다. 한 번의 거대한 query와 materialization이 여러 작은 query보다 더 느리고 많은 메모리를 사용할 수도 있다. elapsed time, peak memory, UI responsiveness를 함께 본다.

## 체크리스트

- [ ] 빈 `@Query`가 어느 container와 context를 사용하는지 설명한다.
- [ ] `body` 평가 횟수와 저장소 query 횟수가 같은 개념이 아님을 설명한다.
- [ ] 이름 오름차순과 설명 내림차순을 함께 적용한다.
- [ ] `#Predicate`로 빈 이름을 제외한다.
- [ ] 검색어를 받는 initializer에서 `_groceries = Query(...)`를 구성한다.
- [ ] 같은 조건을 `FetchDescriptor`로 작성하고 `@Query`와 용도를 비교한다.
- [ ] SQL debug 출력을 개발 환경에서 확인하고 production API가 아님을 설명한다.
- [ ] Instruments로 전체 fetch와 limit fetch의 시간·메모리를 비교한다.

## 공식 참고 자료

- [Apple: Query](https://developer.apple.com/documentation/swiftdata/query)
- [Apple: FetchDescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor)
- [Apple: ModelContext.fetch(_:)](https://developer.apple.com/documentation/swiftdata/modelcontext/fetch(_:))
- [Apple: Predicate](https://developer.apple.com/documentation/foundation/predicate)
- [Apple: SortDescriptor](https://developer.apple.com/documentation/foundation/sortdescriptor)
- [Apple: Core Data performance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/Performance.html)
