# `NavigationLink`의 `value`와 `navigationDestination`의 `String.self`

메타타입과 `.self`의 언어 차원 의미는 [별도 문서](./metatype-and-self.md)에 정리했다. 이 문서는 **네비게이션에서 그것이 어떻게 쓰이는가**를 다룬다.

## 질문이 나온 코드

`chapter-57/chapter-57/ContentView.swift`

```swift
NavigationLink(value: "Mastering iOS and UIKit") {
    Text("Mastering iOS and UIKit")
}
NavigationLink("Mastering SwiftUI", value: Color.orange)
```

```swift
.navigationDestination(
    for: String.self,
    destination: { title in
        Text(title)
        // ...
    }
)
.navigationDestination(for: Color.self) { value in
    Text("DevTechie")
        .foregroundStyle(value)
}
```

## 공부할 내용

### 질문 확인: `value`로 넘긴 값이 `destination` 콜백으로 오는가

**맞다.** 다만 중간에 한 단계가 더 있다. 직접 전달되는 것이 아니라 **`path`를 거친다.**

```text
① 사용자가 NavigationLink를 탭
        ↓
② value로 지정한 값이 path에 append 된다
        ↓
③ NavigationStack이 path의 각 값을 보고
   "이 타입을 처리하는 navigationDestination이 있나?" 확인
        ↓
④ 타입이 일치하는 destination 클로저를 찾아
   그 값을 인자로 넘겨 호출
        ↓
⑤ 반환된 뷰가 화면에 표시된다
```

②가 중요하다. 링크를 탭하는 것과 화면이 그려지는 것 사이에 `path`라는 상태가 놓여 있다. 그래서 **링크를 탭하지 않고 코드로 `path.append(...)`를 해도 똑같이 화면이 이동한다.** [path 문서](./navigation-path-and-typed-array.md)에서 다룬 프로그래밍 방식 네비게이션이 이 구조 덕분에 가능하다.

### `String.self`가 왜 필요한가 — 시그니처를 보면 답이 나온다

```swift
nonisolated func navigationDestination<D, C>(
    for data: D.Type,
    @ViewBuilder destination: @escaping (D) -> C
) -> some View where D : Hashable, C : View
```

`for` 파라미터의 타입이 **`D.Type`** 이다. 값이 아니라 **타입 자체**를 받는다.

```swift
.navigationDestination(for: String.self) { ... }
//                          ↑
//                     String 타입 그 자체
```

`String.self`는 `String`이라는 타입을 값으로 꺼낸 것이다. Swift 공식 문서의 설명이 그대로다.

> You can use the postfix `self` expression to access a type as a value. For example, `SomeClass.self` returns `SomeClass` itself, not an instance of `SomeClass`.

즉 `"안녕"` 같은 **문자열 하나**가 아니라 **`String`이라는 타입 전체**를 가리킨다.

```swift
.navigationDestination(for: String.self)     // ✅ 타입
.navigationDestination(for: "hello")         // ❌ 값 — 컴파일 에러
```

### 왜 값이 아니라 타입을 받도록 설계했나

이유가 세 가지다.

**① 등록이지 조회가 아니다**

`navigationDestination`은 "이 값을 보여 줘"가 아니라 **"이 타입이 오면 이렇게 그려라"** 는 규칙 등록이다. 어떤 값이 올지는 미리 알 수 없으므로 값을 받을 수 없다.

**② 타입으로 매칭한다**

Apple 문서가 명시한다.

> To create a stack that can present more than one kind of view, you can add multiple `navigationDestination(for:destination:)` modifiers inside the stack's view hierarchy, with each modifier presenting a different data type. **The stack matches navigation links with navigation destinations based on their respective data types.**

**타입이 곧 라우팅 키**다. `path`에 `String`이 들어오면 `for: String.self` 쪽으로, `Color`가 들어오면 `for: Color.self` 쪽으로 간다. 예제에 `navigationDestination`이 두 개 있는 이유가 이것이다.

```text
path: ["Mastering iOS and UIKit", Color.orange]
         ↓ String                   ↓ Color
   for: String.self          for: Color.self
```

**③ 제네릭 `D`를 결정한다**

`D.Type`을 넘기는 순간 `D`가 확정되고, `destination` 클로저의 파라미터 타입도 따라 정해진다.

```swift
.navigationDestination(for: String.self) { title in
    // title은 String으로 추론된다 — 타입을 쓸 필요가 없다
}
```

`for: Color.self`를 넘겼다면 클로저의 `value`는 `Color`가 된다. 예제에서 `value.foregroundStyle(value)`처럼 `Color`로 바로 쓸 수 있는 이유다.

이 패턴은 SwiftUI 곳곳에 있다. [`preference(key:)`](./preference-key-and-onpreferencechange.md)의 `SizePreferenceKey.self`, `onGeometryChange(for: CGSize.self)`, `Codable`의 `decode(User.self, forKey:)`가 모두 같은 발상이다. **"어떤 타입인지"가 곧 정보인 자리**다.

### 두 가지 `NavigationLink` 형태

예제에 두 스타일이 나온다. 둘 다 같은 일을 한다.

```swift
// label 클로저를 쓰는 형태
NavigationLink(value: "Mastering iOS and UIKit") {
    Text("Mastering iOS and UIKit")
}

// 문자열 편의 이니셜라이저
NavigationLink("Mastering SwiftUI", value: Color.orange)
```

> For a link composed only of text, you can use one of the convenience initializers that takes a string and creates a `Text` view for you.

**두 번째 형태에서 헷갈리기 쉬운 지점이 있다.** 첫 인자 `"Mastering SwiftUI"`는 **화면에 보이는 라벨**이고, `value: Color.orange`가 **넘어가는 값**이다. 라벨과 값이 다른 타입이어도 무관하다.

그래서 이 링크를 탭하면 `Color.orange`가 `path`에 들어가고, `for: Color.self` destination이 실행되어 주황색 텍스트가 나온다. 라벨의 문자열은 아무 데도 전달되지 않는다.

### 값 기반과 목적지 직접 지정의 차이

`NavigationLink`에는 목적지를 직접 주는 형태도 있다.

```swift
// 값 기반 — navigationDestination이 필요
NavigationLink("Detail", value: course)

// 목적지 직접 지정 — navigationDestination 불필요
NavigationLink("Detail") {
    CourseDetail(course: course)
}
```

| | 값 기반 | 목적지 직접 |
| --- | --- | --- |
| `navigationDestination` | 필요 | 불필요 |
| 목적지 생성 시점 | **탭할 때** | **링크를 만들 때** |
| 목록 100개일 때 | 목적지 0개 생성 | 목적지 100개 생성 |
| `path`로 제어 | 가능 | 불가능 |
| 딥링크 | 자연스러움 | 어려움 |

목록이 길면 성능 차이가 크다. [`NavigationView`와의 비교 문서](./navigation-stack-vs-navigation-view.md)에서 다룬 개선점이 이 부분이다.

### 주의점

**① `navigationDestination`을 lazy 컨테이너 안에 넣지 않는다**

> Do not put a navigation destination modifier inside a "lazy" container, like `List` or `LazyVStack`. These containers create child views only when needed to render on screen. Add the navigation destination modifier outside these containers so that the navigation stack can always see the destination.

예제는 `List` **바깥**에 붙어 있어 올바르다.

```swift
List {
    NavigationLink(value: ...) { ... }
}
.navigationDestination(for: String.self) { ... }   // ✅ List 밖
```

`List` 안에 넣으면 스크롤로 그 행이 화면 밖으로 나간 순간 목적지를 찾지 못해 이동이 실패한다.

**② 타입마다 destination이 있어야 한다**

`path`에 들어온 타입을 처리하는 `navigationDestination`이 없으면 화면이 이동하지 않는다. 조용히 실패하므로 디버깅이 어렵다. 예제에서 `for: Color.self`를 지우면 주황색 링크가 반응하지 않게 된다.

**③ 같은 타입에 destination을 여러 번 등록하면 마지막 것이 이긴다**

의도치 않게 중복 등록하면 예상과 다른 화면이 나올 수 있다.

**④ `Hashable`이 필요하다**

`where D : Hashable` 제약이다. `String`과 `Color`는 이미 만족한다. 직접 만든 타입은 준수를 선언해야 한다. [enum과 Hashable](./enum-hashable-conformance.md) 참조.

### 이 예제에서 눈여겨볼 것

`destination` 클로저 안에 **또 다른 `NavigationLink`** 가 있다.

```swift
.navigationDestination(for: String.self, destination: { title in
    Text(title)
    NavigationLink(
        "Mastering Machine Learning in iOS",
        value: "Mastering Machine Learning in iOS"
    )
    Button("Pop to root") {
        path = NavigationPath()
    }
})
```

목적지 화면에서 다시 같은 타입(`String`)의 링크를 누르면 **같은 destination이 재사용**되어 화면이 계속 쌓인다. `path`가 `["A", "B", "C"]`처럼 늘어나는 것을 `path.count`로 확인할 수 있다.

"Pop to root" 버튼은 `path`를 비워 루트로 한 번에 돌아간다. 값 기반 네비게이션이라 가능한 조작이다.

한 가지 덧붙이면, `destination` 클로저가 뷰를 **세 개** 반환하고 있다. `@ViewBuilder`라 컴파일은 되지만 암시적으로 그룹화되어 배치가 의도와 다를 수 있다. `VStack`으로 감싸는 편이 명확하다.

## 학습 체크리스트

- [ ] `for: String.self`를 `for: "hello"`로 바꿔 컴파일 에러를 확인한다.
- [ ] `destination` 클로저의 파라미터에 명시적 타입을 붙여 `String`으로 추론됐음을 확인한다.
- [ ] `for: Color.self` destination을 지우고 주황색 링크가 반응하지 않는 것을 본다.
- [ ] `path.count`를 화면에 표시하고 링크를 탭할 때마다 늘어나는지 확인한다.
- [ ] `NavigationLink("라벨", value: Color.orange)`에서 라벨과 값이 무관함을 확인한다.
- [ ] 링크를 탭하지 않고 코드로 `path.append("직접 추가")`를 실행해 화면이 이동하는지 본다.
- [ ] `navigationDestination`을 `List` 안으로 옮기고 스크롤 후 탭했을 때 문제가 생기는지 확인한다.
- [ ] 같은 타입에 `navigationDestination`을 두 번 등록하고 어느 쪽이 실행되는지 본다.
- [ ] `Hashable`이 아닌 타입을 `value:`에 넘겨 컴파일 에러를 확인한다.
- [ ] `destination` 클로저의 세 뷰를 `VStack`으로 감싸고 배치가 달라지는지 비교한다.
- [ ] 목적지 화면에서 같은 타입 링크를 여러 번 눌러 스택이 계속 쌓이는 것을 확인한다.
- [ ] `NavigationLink(value:)`와 `NavigationLink { destination }` 두 형태를 같은 목록에 넣고 비교한다.

## 공식 참고 자료

- [Apple: NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [Apple: view.navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: NavigationPath](https://developer.apple.com/documentation/swiftui/navigationpath)
- [Swift 공식 문서: Types — Metatype Type](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/types/#Metatype-Type)
- [Swift 공식 문서: Expressions — Self Expression](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Self-Expression)
- [Apple: Hashable](https://developer.apple.com/documentation/swift/hashable)
- [Apple: Navigation](https://developer.apple.com/documentation/swiftui/navigation)
