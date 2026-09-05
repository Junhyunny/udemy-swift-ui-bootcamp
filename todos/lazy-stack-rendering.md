# `LazyVStack`의 용도와 lazy 렌더링 시점

## 질문이 나온 코드

`chapter-21/chapter-21/ContentView.swift`의 `ScrollView { LazyVStack(spacing: 10) { ForEach(0..<200, ...) } }`

## 공부할 내용

### 무엇이 "lazy"한가 — 자식 view를 미리 만들지 않는다

`LazyVStack`은 "세로로 자식을 배치하되 **필요할 때만 항목을 만드는**" 스택이다.

> "A view that arranges its children in a line that grows vertically, creating items only as needed."
>
> "The stack is 'lazy,' in that the stack view doesn't create items until it needs to render them onscreen."

일반 `VStack`은 정반대다.

> "Unlike `LazyVStack`, which only renders the views when your app needs to display them, a `VStack` renders the views all at once, regardless of whether they are on- or offscreen. Use the regular `VStack` when you have a small number of subviews or don't want the delayed rendering behavior of the 'lazy' version."

즉 `VStack`은 화면 밖에 있든 말든 **200개를 전부 즉시** 만들고, `LazyVStack`은 **화면에 그려야 할 때가 되어서야** 만든다. Apple이 제시하는 선택 기준도 명확하다. 자식 수가 적으면 그냥 `VStack`을 쓰고, 지연 생성이 필요할 만큼 많을 때 lazy 버전을 쓴다.

### lazy stack은 스크롤 기능이 없다 — `ScrollView`가 필수인 이유

`LazyVStack`을 `ScrollView`로 감싼 것은 관례가 아니라 필요 때문이다.

> "Like stack views, lazy stacks don't include any inherent support for scrolling, and you should wrap lazy stack views in `ScrollView` containers."

lazy stack 자체는 스크롤을 모른다. "지금 화면에 무엇이 보이는지"를 아는 주체는 `ScrollView`이고, 그 정보에 따라 stack이 필요한 항목만 만들어 내는 구조다. `ScrollView` 없이 쓰면 스크롤도 안 되고 lazy의 이점도 사라진다.

### 지금 코드가 왜 렌더링 시점을 드러내는 예제인가

```swift
ForEach(0..<200, id: \.self) { _ in
    Text(Date().formatted(date: .omitted, time: .standard))
}
```

`Date()`는 **그 행의 view가 만들어지는 순간**에 평가된다. `LazyVStack`은 항목을 미리 만들지 않으므로, 처음 화면에 보이는 몇 개만 앱 시작 시각으로 찍히고 **스크롤을 내리며 새로 나타나는 행은 그때그때의 시각**으로 찍힌다. 시각이 서로 다르다는 사실 자체가 "이 행은 지금 만들어졌다"는 증거다.

가장 정확한 비교는 `LazyVStack`을 `VStack`으로만 바꿔 보는 것이다. `VStack`은 200개를 한 번에 만들므로 **끝까지 스크롤해도 모든 행의 시각이 동일**하다. 두 결과의 차이가 곧 lazy의 정의다.

생성 시점을 더 분명히 보고 싶으면 `onAppear`로 로그를 남기면 된다.

```swift
ForEach(0..<200, id: \.self) { index in
    Text("Row \(index)")
        .onAppear { print("appear \(index)") }
}
```

`LazyVStack`에서는 스크롤에 따라 로그가 순차적으로 찍히고, `VStack`에서는 처음부터 대량으로 찍힌다.

### `ForEach`와 함께 쓸 때의 주의점

lazy 컨테이너는 `ForEach`의 원소를 **필요한 만큼만 조회**한다. 그래서 항목 하나가 만들어 내는 view 개수가 일정해야 성능이 나온다.

> "Some containers like `List` or `LazyVStack` will query the elements within a for each lazily. To obtain maximal performance, ensure that the view created from each element in the collection represents a constant number of views."

원소마다 `if`로 view를 만들거나 말거나 하면 개수가 1개 또는 0개로 달라져, 스택이 "몇 개를 얼마나 만들어야 하는지" 미리 계산하기 어려워진다.

### 정리 — 언제 쓰는가

- 항목이 많고 대부분 화면 밖에 있다 → `LazyVStack` + `ScrollView`
- 항목이 적다 → 그냥 `VStack` (지연 생성의 복잡함을 살 이유가 없다)
- 가로 방향이면 `LazyHStack`
- 섹션 헤더를 상단에 고정하고 싶다 → `pinnedViews` 파라미터

## 학습 체크리스트

- [ ] `LazyVStack`을 `VStack`으로만 바꿔 실행하고, 끝까지 스크롤했을 때 모든 행의 시각이 같아지는지 확인한다.
- [ ] 두 경우 각각 앱 실행 직후 첫 화면이 뜨기까지의 체감 시간을 비교한다.
- [ ] `onAppear`에 `print`를 넣어 행이 만들어지는 순서와 시점을 콘솔로 확인한다.
- [ ] 한 번 지나간 행으로 다시 스크롤을 올렸을 때 시각이 그대로인지, 다시 찍히는지 관찰하고 그 의미를 정리한다.
- [ ] `ScrollView`를 벗겨내고 `LazyVStack`만 남겼을 때 어떻게 동작하는지 확인한다.
- [ ] `ForEach` 내부에 `if`를 넣어 원소당 view 개수가 달라지게 만들고 Apple이 왜 이를 피하라고 하는지 설명한다.
- [ ] 200을 20으로 줄여 보고, 이 규모에서 `VStack`과 `LazyVStack`의 차이가 체감되는지 확인한다.
- [ ] `Section`과 `pinnedViews: [.sectionHeaders]`를 적용해 헤더가 고정되는 예제를 만든다.

## 참고 자료

- [Apple: LazyVStack](https://developer.apple.com/documentation/swiftui/lazyvstack)
- [Apple: VStack (LazyVStack과의 차이)](https://developer.apple.com/documentation/swiftui/vstack)
- [Apple: LazyHStack](https://developer.apple.com/documentation/swiftui/lazyhstack)
- [Apple: Grouping data with lazy stack views](https://developer.apple.com/documentation/swiftui/grouping-data-with-lazy-stack-views)
- [Apple: LazyVStack.init(alignment:spacing:pinnedViews:content:)](https://developer.apple.com/documentation/swiftui/lazyvstack/init(alignment:spacing:pinnedviews:content:))
- [Apple: ScrollView](https://developer.apple.com/documentation/swiftui/scrollview)
- [Apple: ForEach (lazy 컨테이너에서의 주의점)](https://developer.apple.com/documentation/swiftui/foreach)
- [Apple: View.onAppear(perform:)](https://developer.apple.com/documentation/swiftui/view/onappear(perform:))
