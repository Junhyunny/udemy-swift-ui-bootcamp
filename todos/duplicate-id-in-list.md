# `List`에서 `id`가 중복되면 어떻게 되는가

`Hashable`과 해시 충돌은 [별도 문서](./hashable-id-and-collisions.md)에, `ForEach`의 `id` 지정은 [여기](./foreach-id-and-identity-keypath.md)에 정리했다. 이 문서는 **id 중복 시의 실제 동작**을 다룬다.

## 질문이 나온 코드

`chapter-69/chapter-69/CourseHome.swift`

```swift
List(Course.sample) { course in
    // id 파라미터가 없다
}
```

`chapter-69/chapter-69/Course.swift`

```swift
struct Course: Identifiable {
    let id = UUID().uuidString
    // ...
}
```

## 공부할 내용

### 질문 확인: `Identifiable`이면 `id`가 필요 없다

**맞다.** Apple 문서가 명시한다.

> Use `ForEach` to provide views based on a `RandomAccessCollection` of some data type. **Either the collection's elements must conform to `Identifiable` or you need to provide an `id` parameter** to the `ForEach` initializer.

`List`도 같은 규칙을 따른다. 둘 중 하나만 만족하면 된다.

```swift
List(Course.sample) { course in ... }              // Identifiable이면 이대로
List(names, id: \.self) { name in ... }            // 아니면 id를 지정
```

### `id`는 무엇에 쓰이나 — 신원(identity)

**중요한 것은 `id`가 "고유 번호"가 아니라 "신원"이라는 점이다.**

SwiftUI는 뷰를 다시 그릴 때마다 **"이 행이 아까 그 행인가, 새로 생긴 행인가"** 를 판단해야 한다. 그 판단 기준이 `id`다.

```text
갱신 전  [id:A, id:B, id:C]
갱신 후  [id:A, id:C]

SwiftUI의 해석: B가 삭제됐다 → B 행만 제거 애니메이션
```

`id`가 없다면 전체를 다시 그려야 한다. `id` 덕분에 **바뀐 것만 갱신**할 수 있다.

`id`로 결정되는 것들이 이렇다.

- 행 뷰의 **재사용 여부**
- 삽입·삭제·이동 **애니메이션**
- `@State` 같은 **행 내부 상태의 유지**
- 스크롤 위치 보존

### id가 중복되면 — 크래시는 아니다

**컴파일 에러도, 런타임 크래시도 아니다.** 대신 **동작이 어긋난다.**

Xcode 콘솔에 경고가 나온다.

```
ForEach<Array<Course>, String, ...>: the ID xxx occurs multiple times
within the collection, this will give undefined results!
```

**"undefined results"** 라는 표현이 핵심이다. 정의되지 않은 동작이므로 어떤 증상이 나올지 보장되지 않는다.

**실제로 관찰되는 증상들**

| 증상 | 이유 |
| --- | --- |
| 행이 화면에서 사라지거나 겹친다 | 같은 신원으로 판단해 하나로 합침 |
| 삭제했는데 엉뚱한 행이 지워진다 | id로 대상을 찾는데 중복이라 첫 번째만 잡힘 |
| 애니메이션이 이상하게 튄다 | 어느 행이 이동했는지 판단 실패 |
| 행의 `@State`가 다른 행으로 옮겨간다 | 신원이 같으니 상태를 공유 |
| 스크롤 위치가 튄다 | 재사용 판단 오류 |
| 선택(selection)이 여러 행에 걸린다 | 선택도 id로 관리 |

**가장 위험한 것은 삭제 로직이다.** 이 프로젝트의 `CartView`가 그런 코드를 갖고 있다.

```swift
ForEach(cart.courses) { course in
    Text(course.title)
}
.onDelete { idSet in cart.deleteCourse(idSet: idSet) }
```

id가 중복되면 사용자가 지운 것과 다른 항목이 지워질 수 있다.

### 이 프로젝트에는 다른 문제가 있다

id 중복보다 먼저 짚어야 할 것이 있다.

```swift
struct Course: Identifiable {
    let id = UUID().uuidString      // 인스턴스마다 새 UUID
}

extension Course {
    static var sample: [Course] {   // ← 계산 프로퍼티
        [ Course(...), ... ]
    }
}
```

**`static var`가 계산 프로퍼티라 `Course.sample`을 읽을 때마다 배열이 새로 만들어지고, 모든 `id`가 새 UUID가 된다.**

id가 중복되는 것이 아니라 **매번 달라지는** 것이다. 증상은 이렇다.

```text
body 재평가
   ↓
Course.sample 다시 호출 → 새 UUID 6개
   ↓
SwiftUI: "기존 행이 전부 사라지고 새 행이 6개 생겼다"
   ↓
전체 행을 다시 만든다 (재사용 안 됨)
```

**결과적으로 나타나는 것들**

- 행 재사용이 되지 않아 스크롤이 무거워진다
- 삽입·삭제 애니메이션이 어긋난다
- 행 안의 `@State`가 유지되지 않는다
- `NavigationLink`로 전달한 `course`와 목록의 `course`가 서로 다른 값이 된다

[static var vs static let 문서](./static-stored-vs-computed-property.md)에서 chapter-57의 같은 문제를 다뤘다. 해결도 같다.

```swift
extension Course {
    static let sample: [Course] = [      // let으로 바꾼다
        Course(...),
        // ...
    ]
}
```

한 번만 생성되므로 `id`가 고정된다.

### 근본적인 개선 — `id`를 의미 있는 값으로

`UUID()`를 기본값으로 두는 패턴 자체가 이 문제를 유발한다. **데이터에 이미 고유한 값이 있다면 그것을 `id`로 쓰는 편이 안전하다.**

```swift
struct Course: Identifiable {
    var id: String { title }        // 계산 프로퍼티 — 제목이 곧 신원
    var title: String
    // ...
}
```

Apple 문서의 예제도 이 방식이다.

```swift
private struct NamedFont: Identifiable {
    let name: String
    let font: Font
    var id: String { name }         // ← 저장 프로퍼티가 아니다
}
```

**이 방식의 장점**

- `static var`든 `static let`이든 신원이 안정적이다
- 서버에서 다시 받아도 같은 데이터면 같은 `id`
- 저장 프로퍼티가 하나 줄어든다
- [`Codable`에서 `CodingKeys` 문제](./codable-and-codingkey.md)도 사라진다

**단, 그 값이 실제로 고유해야 한다.** 제목이 중복될 수 있는 데이터라면 부적절하다. 서버 PK가 있다면 그것이 최선이다.

```swift
struct Course: Identifiable {
    let id: Int         // 서버가 주는 고유 ID
    var title: String
}
```

### 중복을 실제로 만들어 보면

학습 목적으로 재현해 볼 수 있다.

```swift
struct Item: Identifiable {
    let id: String
    let name: String
}

let items = [
    Item(id: "same", name: "첫 번째"),
    Item(id: "same", name: "두 번째"),      // 중복
    Item(id: "other", name: "세 번째"),
]

List(items) { item in
    Text(item.name)
}
```

콘솔에 경고가 뜨고, 행이 제대로 표시되지 않는 것을 볼 수 있다.

### `id: \.self`를 쓸 때의 함정

`Identifiable`이 아닌 타입에는 `id`를 지정하는데, `\.self`가 흔히 쓰인다.

```swift
List(["A", "B", "A"], id: \.self) { name in
    Text(name)
}
```

**값 자체가 id가 되므로 값이 중복되면 id도 중복된다.** 위 코드는 `"A"`가 두 번 있어 문제가 생긴다.

[ForEach의 id와 key path 문서](./foreach-id-and-identity-keypath.md)에서 다룬 내용이다. 중복 가능성이 있는 컬렉션에는 `\.self`를 쓰지 않는다.

**인덱스를 쓰는 방법**도 있지만 주의가 필요하다.

```swift
ForEach(Array(items.enumerated()), id: \.offset) { index, item in
    Text(item.name)
}
```

인덱스는 항상 고유하지만, **항목이 삽입·삭제되면 인덱스가 밀려 신원이 바뀐다.** 목록이 변하지 않는 경우에만 안전하다.

### 확인하는 방법

**① 콘솔 경고를 본다**

`the ID xxx occurs multiple times` 경고가 나오면 중복이다.

**② 직접 검사한다**

```swift
let ids = Course.sample.map(\.id)
assert(Set(ids).count == ids.count, "id 중복!")
```

`Set`으로 만들었을 때 개수가 줄면 중복이 있다는 뜻이다.

**③ id가 안정적인지 확인한다**

```swift
print(Course.sample[0].id)
print(Course.sample[0].id)      // 같은 값이 나와야 정상
```

이 프로젝트에서 실행하면 **다른 값**이 나온다.

### 정리

```text
Identifiable이면 List/ForEach에 id 파라미터가 불필요하다  ✅ 인식이 맞다

id는 "고유 번호"가 아니라 "신원"
  행 재사용, 애니메이션, 상태 유지, 스크롤 위치를 결정

중복되면
  크래시는 아니다 — 콘솔 경고 + "undefined results"
  행이 겹치거나 사라짐, 삭제가 엉뚱한 대상에, 상태가 뒤섞임

이 프로젝트의 문제는 중복이 아니라 "매번 달라짐"
  static var(계산 프로퍼티) + UUID() 조합
  → static let으로 바꾸거나
  → id를 의미 있는 값으로 (var id: String { title })
```

## 학습 체크리스트

- [ ] `print(Course.sample[0].id)`를 두 번 실행해 값이 다른 것을 확인한다.
- [ ] `static var sample`을 `static let`으로 바꾸고 같아지는지 확인한다.
- [ ] `id`를 `var id: String { title }`로 바꿔 보고 신원이 안정되는지 확인한다.
- [ ] 같은 `id`를 가진 항목 두 개로 `List`를 만들어 콘솔 경고를 확인한다.
- [ ] 그 상태에서 행이 어떻게 표시되는지 관찰한다.
- [ ] `List(["A", "B", "A"], id: \.self)`를 만들어 중복 문제를 재현한다.
- [ ] `Set(ids).count == ids.count`로 중복을 검사하는 코드를 작성한다.
- [ ] `onDelete`가 있는 목록에서 id를 중복시키고 엉뚱한 행이 지워지는지 본다.
- [ ] 행에 `@State`를 넣고 id가 바뀔 때 상태가 초기화되는 것을 확인한다.
- [ ] `ForEach(Array(items.enumerated()), id: \.offset)` 방식의 위험을 설명한다.
- [ ] Apple 문서의 `NamedFont` 예제처럼 계산 프로퍼티 `id`를 만들어 본다.
- [ ] `List`를 스크롤하며 행이 재사용되는지 `onAppear` 로그로 확인한다.

## 공식 참고 자료

- [Apple: ForEach](https://developer.apple.com/documentation/swiftui/foreach)
- [Apple: List](https://developer.apple.com/documentation/swiftui/list)
- [Apple: Identifiable](https://developer.apple.com/documentation/swift/identifiable)
- [Apple: Identifiable.id](https://developer.apple.com/documentation/swift/identifiable/id)
- [Apple: view.id(_:)](https://developer.apple.com/documentation/swiftui/view/id(_:))
- [Apple: ForEach.init(_:content:)](https://developer.apple.com/documentation/swiftui/foreach/init(_:content:))
- [Apple: ForEach.init(_:id:content:)](https://developer.apple.com/documentation/swiftui/foreach/init(_:id:content:))
- [Apple: UUID](https://developer.apple.com/documentation/foundation/uuid)
- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [Swift 공식 문서: Properties — Type Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Type-Properties)
