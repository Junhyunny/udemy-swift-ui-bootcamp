# `static var { }`와 `static let = []` — 무엇이 다르고 언제 문제가 되는가

`static` 타입 프로퍼티의 기본 개념과 `.init` 축약은 [별도 문서](./static-type-properties-and-implicit-init.md)에 정리했다. 이 문서는 **두 선언 방식의 차이와 실제 사고**를 다룬다.

## 질문이 나온 코드

`chapter-57/chapter-57/ContentView.swift`

```swift
struct DevTechieCourse: Identifiable, Hashable {
    let id = UUID()
    let title: String
}

extension DevTechieCourse {
    static var exampleData: [DevTechieCourse] {
        return [
            .init(title: "Mastering SwiftUI"),
            .init(title: "Build Disney Plus clone in SwiftUI"),
            .init(title: "Build Viedeo Player App in SwiftUI"),
        ]
    }
}
```

## 공부할 내용

### 결론 먼저

- `{ }` 블록은 클로저가 아니라 **계산 프로퍼티(computed property)** 다. 접근할 때마다 **매번 새로 실행**된다.
- `= [...]`는 **저장 프로퍼티(stored property)** 다. **첫 접근 때 한 번만** 초기화되고 그 값이 유지된다.
- **이 코드에서는 계산 프로퍼티가 실제 버그를 만든다.** `let id = UUID()` 때문이다.
- 결론부터 말하면 이 경우 `static let`이 맞다.

### 두 방식의 문법적 차이

```swift
// ① 계산 타입 프로퍼티 — 매번 실행
static var exampleData: [DevTechieCourse] {
    return [ .init(title: "..."), ... ]
}

// ② 저장 타입 프로퍼티 — 한 번만 초기화
static let exampleData: [DevTechieCourse] = [
    .init(title: "..."), ...
]
```

Swift 공식 문서의 구분이 명확하다.

> Stored type properties can be variables or constants. **Computed type properties are always declared as variable properties**, in the same way as computed instance properties.

계산 프로퍼티가 `let`이 될 수 없어 `var`를 쓴다. 그래서 **`static var` + `{ }`를 보면 "매번 계산된다"** 고 읽어야 한다. 값이 바뀌는 변수라서 `var`인 게 아니다.

### 저장 프로퍼티는 lazy하고 스레드 안전하다

이것이 저장 방식의 중요한 성질이다.

> **Stored type properties are lazily initialized on their first access.** They're guaranteed to be initialized only once, **even when accessed by multiple threads simultaneously**, and they don't need to be marked with the `lazy` modifier.

세 가지를 보장한다.

- **처음 접근할 때** 초기화된다 (앱 시작 시가 아니다)
- **정확히 한 번만** 초기화된다
- **여러 스레드가 동시에 접근해도** 안전하다

`lazy` 키워드가 필요 없다는 점도 명시되어 있다.

### 이 코드에서 벌어지는 실제 문제

여기가 핵심이다. `DevTechieCourse`의 정의를 다시 보자.

```swift
struct DevTechieCourse: Identifiable, Hashable {
    let id = UUID()          // ← 인스턴스마다 새 UUID
    let title: String
}
```

`UUID()`는 호출될 때마다 **새로운 고유 값**을 만든다. 그리고 `exampleData`는 계산 프로퍼티라 **접근할 때마다 배열을 새로 만든다.** 두 사실이 겹치면 이렇게 된다.

```swift
let a = DevTechieCourse.exampleData
let b = DevTechieCourse.exampleData

a[0].title == b[0].title    // true  — 제목은 같다
a[0].id == b[0].id          // false — id가 다르다!
a[0] == b[0]                // false — 따라서 같지 않다
```

`Hashable` 자동 합성은 **모든 저장 프로퍼티**를 사용한다. `id`가 다르면 다른 값으로 취급된다. [Hashable과 신원 문제](./hashable-id-and-collisions.md)에서 다룬 상황과 같다.

**이것이 SwiftUI에서 세 가지 문제를 만든다.**

**① `List`가 행을 계속 새로 만든다**

```swift
List(DevTechieCourse.exampleData) { course in
    NavigationLink(course.title, value: course)
}
```

`body`가 재평가될 때마다 `exampleData`가 다시 호출되고, 모든 행의 `id`가 바뀐다. SwiftUI는 `Identifiable`의 `id`로 행의 신원을 판단하므로 **"기존 행이 사라지고 새 행이 생겼다"** 고 해석한다. 결과적으로 행 재사용이 안 되고, 애니메이션과 스크롤 위치도 어긋날 수 있다.

**② `path`에 넣은 값과 매칭되지 않는다**

```swift
@State private var path: [DevTechieCourse] = [
    DevTechieCourse.exampleData[0],    // ← 이때 만들어진 UUID
    DevTechieCourse.exampleData[1],    // ← 또 다른 호출, 또 다른 UUID
]
```

두 줄이 **각각 `exampleData`를 호출**한다. 서로 다른 배열에서 값을 하나씩 꺼내는 셈이다. 나중에 `List`가 그리는 값과도 `id`가 다르므로 비교가 실패한다.

**③ 선택 상태나 비교가 어긋난다**

```swift
if selectedCourse == DevTechieCourse.exampleData[0] { ... }   // 항상 false
```

### `static let`으로 바꾸면

```swift
extension DevTechieCourse {
    static let exampleData: [DevTechieCourse] = [
        .init(title: "Mastering SwiftUI"),
        .init(title: "Build Disney Plus clone in SwiftUI"),
        .init(title: "Build Viedeo Player App in SwiftUI"),
    ]
}
```

첫 접근 때 한 번만 만들어지고 그 배열이 계속 재사용된다. `id`가 고정되므로 위 세 문제가 모두 사라진다.

```swift
DevTechieCourse.exampleData[0].id == DevTechieCourse.exampleData[0].id   // true
```

### 각 방식의 장단점

**계산 프로퍼티 `static var { }`**

| | |
| --- | --- |
| 장점 | 항상 새 인스턴스를 준다 — 호출자가 마음대로 변형해도 원본에 영향 없음 |
| | 호출 시점의 상태를 반영할 수 있다 (현재 시각, 설정값 등) |
| | 메모리를 계속 점유하지 않는다 |
| | 값 타입이 아닌 참조 타입을 다룰 때 공유 사고를 막는다 |
| 단점 | **매번 생성 비용**이 든다 |
| | **`UUID()`, `Date()`처럼 매번 달라지는 값이 있으면 신원이 흔들린다** |
| | `==` 비교가 예상과 다르게 동작할 수 있다 |
| | SwiftUI의 `id` 기반 최적화가 무력화된다 |

**저장 프로퍼티 `static let = [...]`**

| | |
| --- | --- |
| 장점 | **한 번만 생성** — 비용이 없다 |
| | **신원이 고정**되어 비교·`Identifiable`이 안정적 |
| | lazy 초기화 + 스레드 안전이 보장된다 |
| | 의도가 명확하다 — "고정된 상수" |
| 단점 | 메모리를 계속 점유한다 (큰 데이터라면 고려) |
| | 초기화 시점의 값으로 **고정**된다 |
| | **`class`나 참조 타입을 담으면 공유 상태가 된다** |
| | `static var`(저장)로 만들면 전역 가변 상태가 되어 위험하다 |

### 언제 무엇을 쓰나

```text
매번 다른 값이어야 하는가?
│
├─ 예 (현재 시각, 랜덤, 새 인스턴스가 필요)
│    └─ static var { } 계산 프로퍼티
│
└─ 아니오 (고정된 샘플·상수)
     │
     ├─ 값 타입(struct/enum)이고 불변
     │    └─ static let = [...]          ← 이 예제의 정답
     │
     └─ 참조 타입(class)
          └─ 공유해도 되는지 신중히 판단
             공유하면 안 되면 계산 프로퍼티나 팩토리 메서드
```

**구체적인 판단 기준 몇 가지**

- **미리보기·테스트용 샘플 데이터** → `static let`. 신원이 고정되어야 `List`와 `NavigationPath`가 제대로 동작한다
- **매번 초기 상태가 필요한 객체** → 계산 프로퍼티 또는 팩토리 메서드
- **현재 시각·랜덤 값이 들어가는 것** → 계산 프로퍼티. `static let`으로 하면 앱 실행 내내 같은 값에 고정된다
- **`class` 인스턴스** → `static let`이면 모두가 같은 객체를 공유한다. 의도한 것인지 확인

### 함정 하나 — `Date()`와 `static let`

반대 방향의 실수도 있다.

```swift
static let now = Date()          // ⚠️ 첫 접근 시각에 영원히 고정
static var now: Date { Date() }  // ✅ 매번 현재 시각
```

`static let`은 한 번만 초기화되므로, 시간에 의존하는 값을 담으면 앱이 실행되는 내내 그 값에 묶인다.

### 함정 둘 — `static var` 저장 프로퍼티는 전역 가변 상태다

```swift
static var counter = 0     // ⚠️ 어디서든 바꿀 수 있는 전역 변수
```

이건 계산 프로퍼티가 아니라 **저장 프로퍼티인데 `var`**인 경우다. 여러 스레드가 동시에 쓰면 데이터 경쟁이 생긴다. Swift 6의 동시성 검사에서 경고나 에러가 난다. 상태 공유가 필요하면 actor나 `@Observable` 클래스를 쓴다.

`static` 세 조합을 구분해 두면 좋다.

| 선언 | 성격 | 안전성 |
| --- | --- | --- |
| `static let x = ...` | 저장, 불변 | 안전 |
| `static var x: T { ... }` | **계산**, 매번 실행 | 안전 (부수효과 없다면) |
| `static var x = ...` | 저장, **가변** | **위험** — 전역 가변 상태 |

### 팩토리 메서드라는 선택지

"매번 새 인스턴스"가 필요하면서 의도를 분명히 하고 싶다면 메서드가 낫다.

```swift
extension DevTechieCourse {
    static let exampleData: [DevTechieCourse] = [ ... ]   // 고정 샘플

    static func makeSample() -> [DevTechieCourse] {       // 매번 새로
        [ .init(title: "..."), ... ]
    }
}
```

프로퍼티는 "값을 읽는다"는 인상을 주지만 메서드는 "무언가 만든다"는 의도가 드러난다. 계산 프로퍼티가 비싼 작업을 한다면 메서드로 바꾸는 편이 읽는 사람에게 친절하다.

### 이 예제에 적용하면

```swift
extension DevTechieCourse {
    static let exampleData: [DevTechieCourse] = [
        .init(title: "Mastering SwiftUI"),
        .init(title: "Build Disney Plus clone in SwiftUI"),
        .init(title: "Build Viedeo Player App in SwiftUI"),
    ]
}
```

`static let` 하나로 바꾸면 `List`의 행 신원, `path`와의 매칭, 값 비교가 모두 안정된다.

**더 근본적인 개선**도 생각해 볼 수 있다. `id`를 `UUID()`가 아니라 의미 있는 값으로 두는 것이다.

```swift
struct DevTechieCourse: Identifiable, Hashable {
    var id: String { title }     // title이 곧 신원
    let title: String
}
```

이러면 `exampleData`가 계산 프로퍼티여도 신원이 흔들리지 않는다. 다만 제목이 중복되면 안 되므로 데이터 성격에 따라 판단해야 한다. [Hashable과 신원 문서](./hashable-id-and-collisions.md)에서 다룬 논점이다.

## 학습 체크리스트

- [ ] `DevTechieCourse.exampleData[0].id`를 두 번 출력해 값이 다른 것을 확인한다.
- [ ] `static let`으로 바꾸고 같은 실험에서 값이 같아지는지 확인한다.
- [ ] `exampleData[0] == exampleData[0]`의 결과를 두 방식에서 비교한다.
- [ ] 계산 프로퍼티 안에 `print`를 넣어 몇 번 호출되는지 센다.
- [ ] `static let`으로 바꾼 뒤 `print`가 한 번만 찍히는지 확인한다.
- [ ] `path` 초기값의 두 원소가 서로 다른 배열에서 온 것임을 `id`로 확인한다.
- [ ] `List`의 행에 `onAppear { print("행 생성") }`을 넣고 두 방식의 호출 횟수를 비교한다.
- [ ] `static let now = Date()`를 만들고 시간이 고정되는 것을 확인한다.
- [ ] `id`를 `var id: String { title }`로 바꾸고 계산 프로퍼티여도 안정적인지 본다.
- [ ] `static var counter = 0`을 만들고 Swift 6 동시성 경고가 나오는지 확인한다.
- [ ] `makeSample()` 팩토리 메서드를 만들어 의도가 더 분명해지는지 비교한다.
- [ ] 계산 프로퍼티가 `let`으로 선언될 수 없음을 직접 시도해 확인한다.

## 공식 참고 자료

- [Swift 공식 문서: Properties — Type Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Type-Properties)
- [Swift 공식 문서: Properties — Stored Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Stored-Properties)
- [Swift 공식 문서: Properties — Computed Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Computed-Properties)
- [Swift 공식 문서: Properties — Lazy Stored Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Lazy-Stored-Properties)
- [Swift 공식 문서: Protocols — Adopting a Protocol Using a Synthesized Implementation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/#Adopting-a-Protocol-Using-a-Synthesized-Implementation)
- [Apple: Identifiable](https://developer.apple.com/documentation/swift/identifiable)
- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [Apple: UUID](https://developer.apple.com/documentation/foundation/uuid)
- [Apple: List](https://developer.apple.com/documentation/swiftui/list)
