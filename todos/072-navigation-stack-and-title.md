# `NavigationStack`의 역할과 `navigationTitle`을 붙이는 위치

## 질문이 나온 코드

`chapter-29/chapter-29/ContentView.swift`의 두 `NavigationStack`과 그 안쪽 `List`에 붙은 `.navigationTitle(...)`

## 공부할 내용

### `NavigationStack`은 타이틀 설정용이 아니라 화면을 쌓는 컨테이너다

> "A view that displays a root view and enables you to present additional views over the root view."
>
> "Use a navigation stack to present a stack of views over a root view. People can add views to the top of the stack by clicking or tapping a `NavigationLink`, and remove views using built-in, platform-appropriate controls, like a Back button or a swipe gesture. The stack always displays the most recently added view that hasn't been removed, and doesn't allow the root view to be removed."

본래 용도는 **화면 전환(push/pop)** 이다. 지금 코드에는 `NavigationLink`가 없어서 타이틀 바만 보이지만, 그건 스택이 하는 일의 일부일 뿐이다. 제 역할을 하려면 보통 이렇게 쓴다.

```swift
NavigationStack {
    List(courses) { course in
        NavigationLink(course.title, value: course)
    }
    .navigationDestination(for: Courses.self) { course in
        CourseDetail(course: course)
    }
    .navigationTitle("Junhyunny's Courses")
}
```

`navigationDestination(for:)`으로 "이 데이터 타입이 오면 이 화면을 띄운다"를 등록하고, `NavigationLink(value:)`가 그 데이터를 밀어 넣는다.

스택 상태를 코드로 다루고 싶으면 `path`를 넘긴다.

> "By default, a navigation stack manages state to keep track of the views on the stack. However, your code can share control of the state by initializing the stack with a binding to a collection of data values that you create."

```swift
@State private var presentedCourses: [Courses] = []
NavigationStack(path: $presentedCourses) { ... }
```

이 배열을 읽으면 현재 어디까지 들어와 있는지 알 수 있고, 배열을 바꾸면 화면이 따라 바뀐다. 딥링크나 상태 복원에 쓴다.

### 타이틀은 "스택"이 아니라 "지금 보이는 화면"에 속한다

이게 두 번째 질문의 답이다.

> "On iOS and watchOS, when a view is navigated to inside of a navigation stack, the navigation bar displays **that view's title**."

내비게이션 바는 스택이 그리지만, 거기 표시할 문자열은 **그 순간 스택 맨 위에 있는 화면**이 제공한다. 그래서 `navigationTitle`은 컨테이너가 아니라 **콘텐츠 쪽에** 붙인다. 지금 코드에서 `List`에 붙인 것이 맞는 위치다.

이렇게 설계된 이유는 화면을 여러 개 쌓아 보면 분명해진다. 목록에서 상세로 들어가면 타이틀이 바뀌어야 하는데, 타이틀이 스택에 붙어 있다면 화면마다 다른 제목을 줄 방법이 없다. 각 화면이 자기 제목을 들고 있어야 push/pop에 따라 자연스럽게 교체된다.

```swift
NavigationStack {
    List { ... }
        .navigationTitle("목록")        // 루트 화면의 제목
        .navigationDestination(for: Courses.self) { course in
            CourseDetail(course: course)
                .navigationTitle(course.title)   // 상세 화면의 제목
        }
}
```

`NavigationStack` 자체에 `.navigationTitle`을 붙이면 그 스택을 **감싸고 있는 바깥 내비게이션 문맥**에 제목을 알리는 의미가 된다. 지금처럼 스택이 최상위라면 바깥 문맥이 없으므로 화면에 아무것도 나타나지 않는다.

### 지금 코드에서 눈여겨볼 점

`body`에 `NavigationStack`이 **두 개 나란히** 있다. `body`는 암묵적으로 `VStack`처럼 묶이므로 화면이 위아래로 절반씩 나뉘고 타이틀 바도 두 개 생긴다. 두 방식(`List($courses, editActions:)`와 `List { ForEach ... .onDelete }`)을 비교하려는 의도로 보이지만, 실제 앱에서는 **한 화면에 스택 하나**가 정상이다.

## 학습 체크리스트

- [ ] `.navigationTitle`을 `List`에서 `NavigationStack`으로 옮겨 보고 타이틀이 사라지는 것을 확인한다.
- [ ] `NavigationStack`을 통째로 지우면 타이틀 바가 어떻게 되는지 본다.
- [ ] `NavigationLink`와 `navigationDestination(for:)`을 추가해 상세 화면으로 이동하는 예제를 만든다.
- [ ] 상세 화면에도 `navigationTitle`을 주고, 이동할 때 타이틀이 교체되는지 확인한다.
- [ ] `navigationTitle`을 상세 화면에서 빼면 무엇이 표시되는지 관찰한다.
- [ ] `NavigationStack(path:)`에 `@State` 배열을 연결하고, 버튼으로 배열을 조작해 화면이 바뀌는지 실험한다.
- [ ] 두 개의 `NavigationStack`을 하나로 합쳐 정상적인 화면 구성으로 바꿔 본다.
- [ ] `.navigationBarTitleDisplayMode(.inline)`을 적용해 표시 방식이 달라지는 것을 확인한다.

## 참고 자료

- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: Configure your app's navigation titles](https://developer.apple.com/documentation/swiftui/configure-your-apps-navigation-titles)
- [Apple: View.navigationTitle(_:)](https://developer.apple.com/documentation/swiftui/view/navigationtitle(_:))
- [Apple: NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [Apple: View.navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:))
- [Apple: NavigationPath](https://developer.apple.com/documentation/swiftui/navigationpath)
- [Apple: Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [Apple HIG: Navigation and search](https://developer.apple.com/design/human-interface-guidelines/navigation-and-search)
