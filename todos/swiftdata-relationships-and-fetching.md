# SwiftData relationship과 연관 데이터 조회 — SQL JOIN과의 차이

## 질문이 나온 코드

`chapter-110/chapter-110/ContentView.swift`

```swift
@Query private var groceries: [Grocery]
```

현재 `Grocery`만 조회하고 있는데 Category나 Store처럼 연관된 model을 SQL JOIN처럼 함께 조회하려면 어떻게 해야 하는지가 질문이다.

## 공부할 내용

### 먼저 관계를 model에 선언한다

SQL에서는 foreign key column과 JOIN 조건을 작성하지만 SwiftData에서는 model property로 관계를 표현한다.

```swift
@Model
final class Category {
    var name: String

    @Relationship(inverse: \Grocery.category)
    var groceries: [Grocery] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Grocery {
    var name: String
    var desc: String
    var category: Category?

    init(
        name: String,
        desc: String,
        category: Category? = nil
    ) {
        self.name = name
        self.desc = desc
        self.category = category
    }
}
```

```text
Category 1 ─────── N Grocery
category.groceries  grocery.category
```

- `Grocery.category`: to-one 관계
- `Category.groceries`: to-many 관계
- `inverse`: 두 property가 같은 관계의 반대 방향임을 알린다.

### model을 container schema에 모두 등록한다

```swift
.modelContainer(for: [
    Grocery.self,
    Category.self
])
```

관계로 연결된 model은 같은 container와 호환되는 configuration에 포함되어야 한다.

### SQL JOIN을 직접 작성하지 않는다

SwiftData의 공개 API에서는 다음과 같은 SQL을 직접 작성하지 않는다.

```sql
SELECT grocery.*, category.*
FROM grocery
JOIN category ON grocery.category_id = category.id;
```

대신 가져온 model의 관계 property를 탐색한다.

```swift
List(groceries) { grocery in
    VStack(alignment: .leading) {
        Text(grocery.name)
        Text(grocery.category?.name ?? "Uncategorized")
    }
}
```

framework가 schema relationship을 persistent store 연산으로 변환한다. SQL table과 JOIN은 가능한 저장 구현의 세부사항이고, 앱은 객체 그래프와 typed predicate를 사용한다.

### 연관 model의 값으로 filter한다

```swift
let categoryName = "Fruit"

let descriptor = FetchDescriptor<Grocery>(
    predicate: #Predicate { grocery in
        grocery.category?.name == categoryName
    },
    sortBy: [SortDescriptor(\Grocery.name)]
)

let fruits = try modelContext.fetch(descriptor)
```

이는 Grocery를 가져오되 관계인 Category의 이름이 조건에 맞는 것만 요청한다. 저장소가 지원되는 predicate 표현을 관계 query로 변환한다.

`#Predicate`에서 사용할 수 있는 optional, collection 연산 범위는 OS 버전과 저장소에 따라 달라질 수 있다. 실제 target에서 compile하고 fixture 결과를 확인한다.

이 문서의 예제는 iOS 17 simulator SDK 기준으로 type check를 통과한다. 다만 compile이 된다는 것과 저장소가 그 조건을 store 단계에서 처리한다는 것은 다른 문제이므로, 데이터가 많아지면 실제 fixture로 결과와 시간을 확인한다.

### Category에서 Grocery 목록을 탐색한다

```swift
@Query(sort: \Category.name)
private var categories: [Category]

List(categories) { category in
    Section(category.name) {
        ForEach(category.groceries) { grocery in
            Text(grocery.name)
        }
    }
}
```

간단하지만 category마다 `groceries`를 처음 접근할 때 별도 fetch가 반복된다면 N+1 문제가 될 수 있다.

```text
Category fetch 1회
    + Category A의 groceries fetch
    + Category B의 groceries fetch
    + Category C의 groceries fetch
    + ...
```

작은 목록에서는 문제가 없을 수 있지만 데이터가 커지면 query log와 Instruments로 측정한다.

### Prefetch

여러 row에서 같은 관계에 곧바로 접근할 것을 안다면 `FetchDescriptor.relationshipKeyPathsForPrefetching`을 검토한다.

```swift
var descriptor = FetchDescriptor<Grocery>(
    sortBy: [SortDescriptor(\Grocery.name)]
)
descriptor.relationshipKeyPathsForPrefetching = [\Grocery.category]

let groceries = try modelContext.fetch(descriptor)
```

prefetch는 관계 접근 횟수를 줄일 수 있지만 가져올 데이터와 메모리 사용량을 늘린다. 무조건 모든 관계를 prefetch하지 않고 화면에서 실제로 필요한 관계만 측정해 선택한다.

### 여러 model을 각각 `@Query`하는 것은 JOIN과 다르다

```swift
@Query private var groceries: [Grocery]
@Query private var categories: [Category]
```

이렇게 두 배열을 가져온 뒤 Swift 코드에서 ID를 비교하면 작은 데이터에는 동작할 수 있지만, 저장소가 할 수 있는 filter를 앱 메모리에서 다시 수행하게 된다. 결과 수가 크면 느리고 메모리를 많이 쓸 수 있다.

관계가 실제 domain relationship이라면 model에 relationship을 선언하고 관계 predicate 또는 탐색을 사용한다.

### To-many 조건

“구매하지 않은 Grocery가 하나라도 있는 Category”처럼 to-many collection을 조건으로 사용할 수도 있다.

```swift
let descriptor = FetchDescriptor<Category>(
    predicate: #Predicate { category in
        category.groceries.contains { grocery in
            grocery.isPurchased == false
        }
    }
)
```

이 예제를 쓰려면 `Grocery`에 `isPurchased`를 추가해야 한다. collection predicate 지원 범위는 target OS에서 확인하고, 복잡한 식이 지원되지 않으면 query 방향이나 model을 재설계한다.

### Many-to-many 관계

```swift
@Model
final class Tag {
    var name: String
    var groceries: [Grocery] = []
}

@Model
final class Grocery {
    var name: String
    var tags: [Tag] = []
}
```

양쪽이 배열인 관계로 many-to-many를 표현할 수 있다. 하지만 관계 자체에 `addedAt`, `order`, `memo` 같은 attribute가 필요하면 중간 model을 명시하는 편이 낫다.

```text
Grocery ── GroceryTag ── Tag
             ├ addedAt
             └ order
```

SQL의 join table과 비슷하지만 단순 구현 세부사항이 아니라 domain 의미가 있는 model로 취급한다.

### Delete rule도 조회 설계의 일부다

Category를 삭제했을 때 Grocery까지 삭제할지 관계만 `nil`로 만들지 결정해야 한다.

```swift
@Relationship(
    deleteRule: .nullify,
    inverse: \Grocery.category
)
var groceries: [Grocery] = []
```

- `.nullify`: Grocery는 남고 category 관계가 제거된다.
- `.cascade`: Category와 관련 Grocery를 함께 삭제한다.
- `.deny`: 관련 Grocery가 있으면 Category 삭제를 막는다.

조회 화면에서 “카테고리 없음” 상태가 가능한지도 optional 관계와 delete rule에 따라 달라진다.

### Core Data와의 연결

Core Data에서도 `NSManagedObject` relationship과 key path predicate를 이용해 같은 객체 그래프 관점으로 조회한다. `NSFetchRequest`의 `relationshipKeyPathsForPrefetching`도 같은 N+1 문제를 다루는 도구다.

SwiftData와 Core Data 모두 SQL JOIN 문법을 먼저 설계하기보다 domain relationship, inverse, cardinality, delete rule을 먼저 설계한다.

## 체크리스트

- [ ] `Category`와 `Grocery`에 양방향 relationship과 inverse를 만든다.
- [ ] 두 model을 같은 container schema에 등록한다.
- [ ] Grocery 목록에서 `grocery.category?.name`을 표시한다.
- [ ] Category 이름으로 Grocery를 filter하는 predicate를 작성한다.
- [ ] category별 groceries 접근에서 N+1 여부를 측정한다.
- [ ] `relationshipKeyPathsForPrefetching` 전후 query 시간과 memory를 비교한다.
- [ ] 두 배열을 따로 fetch해 메모리에서 결합하는 방식과 관계 query를 비교한다.
- [ ] `.nullify`와 `.cascade`로 Category 삭제 결과를 확인한다.
- [ ] 속성이 있는 many-to-many 관계를 중간 model로 표현한다.

## 공식 참고 자료

- [Apple: Relationship() macro](https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:))
- [Apple: Schema.Relationship](https://developer.apple.com/documentation/swiftdata/schema/relationship)
- [Apple: FetchDescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor)
- [Apple: FetchDescriptor.relationshipKeyPathsForPrefetching](https://developer.apple.com/documentation/swiftdata/fetchdescriptor/relationshipkeypathsforprefetching)
- [Apple: Predicate](https://developer.apple.com/documentation/foundation/predicate)
- [Apple WWDC23: Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/)
