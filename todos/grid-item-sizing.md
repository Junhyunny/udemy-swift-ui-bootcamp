# `GridItem`으로 만들 수 있는 grid의 종류

## 질문이 나온 코드

`chapter-23/chapter-23/ContentView.swift`의 `columns` 배열과 `LazyVGrid(columns: columns)`

## 공부할 내용

### `GridItem` 배열이 곧 grid의 설계도다

`GridItem`은 "lazy grid의 행 또는 열 하나에 대한 설명"이다.

> "A description of a row or a column in a lazy grid."
>
> "Use an array of `GridItem` instances to configure the layout of items in a lazy grid."

중요한 건 배열의 **개수가 곧 열(또는 행)의 개수**라는 점이다. `LazyVGrid`는 세로로 자라므로 행 개수는 무한히 늘어날 수 있고, **열 개수만 `GridItem` 개수로 고정**한다.

> "The number of rows can grow unbounded, but you specify the number of columns by providing a corresponding number of `GridItem` instances to the grid's initializer."

`LazyHGrid`는 정확히 반대다. 행을 `GridItem`으로 고정하고 열이 무한히 늘어난다.

### 크기 지정 방식은 세 가지 — `GridItem.Size`

`GridItem(...)`의 첫 인자는 `GridItem.Size` 열거형이고, "grid의 minor axis 방향 크기"를 정한다. `LazyVGrid`에서는 **가로 폭**을 뜻한다.

**`.fixed(_:)`** — "A single item with the specified fixed size."
말 그대로 고정 폭이다. 화면 크기와 무관하게 그 값을 유지한다. 열 폭을 정확히 통제해야 할 때 쓴다.

**`.flexible(minimum:maximum:)`** — "A single flexible item."
남은 공간을 나눠 갖는다. 계산 방식이 문서에 명시돼 있다.

> "The size of this item is the size of the grid with spacing and inflexible items removed, divided by the number of flexible items, clamped to the provided bounds."

즉 **전체 폭에서 spacing과 고정 항목을 먼저 빼고, 남은 폭을 flexible 항목 수로 나눈** 뒤 `minimum`/`maximum` 범위로 자른다. `GridItem(.flexible())` 두 개면 정확히 반씩 나눠 갖는 2열 grid가 된다.

**`.adaptive(minimum:maximum:)`** — "Multiple items in the space of a single flexible item."
이것만 성격이 다르다. **항목 하나가 열 하나가 아니라, flexible 항목 하나 몫의 공간 안에 여러 개를 밀어 넣는다.**

> "This size case places one or more items into the space assigned to a single `flexible` item, using the provided bounds and spacing to decide exactly how many items fit. This approach prefers to insert as many items of the `minimum` size as possible but lets them increase to the `maximum` size."

`minimum` 크기로 최대한 많이 넣어 보고, 남으면 `maximum`까지 늘린다. 그래서 **열 개수를 화면 폭에 맡기고 싶을 때** 쓴다. `[GridItem(.adaptive(minimum: 50))]` 하나만 두면 폭에 따라 열 수가 자동으로 변하는 grid가 된다.

### 지금 코드는 세 방식이 섞여 있다

```swift
let columns = [
    GridItem(.adaptive(minimum: 50)),
    GridItem(.flexible()),
    GridItem(.flexible()),
]
```

배열 원소가 3개이므로 열 슬롯이 3개다. 그런데 첫 슬롯만 `.adaptive`라서, **1번 슬롯 안에는 폭이 허락하는 만큼 여러 항목이 들어가고 2·3번 슬롯에는 각각 하나씩만** 들어간다. 세 열이 균등하게 나뉘는 형태가 아니라 왼쪽 덩어리 하나 + 오른쪽 두 칸이 되는 셈이라, 결과가 예상과 다르게 보일 수 있다.

의도를 분명히 하려면 셋 중 하나로 통일해 보는 편이 이해에 좋다.

```swift
[GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]  // 균등 3열
[GridItem(.adaptive(minimum: 50))]                                     // 폭에 따라 열 수 자동
[GridItem(.fixed(80)), GridItem(.flexible())]                          // 왼쪽 고정 + 나머지
```

### 크기 말고도 정할 수 있는 것

`GridItem(_:spacing:alignment:)`는 크기 외에 두 가지를 더 받는다.

- `spacing` — "The spacing to use between this and the next item." 즉 **그 항목과 다음 항목 사이** 간격이라, 항목마다 다르게 줄 수 있다.
- `alignment` — 그 항목 안에서의 정렬.

### lazy grid가 아닌 `Grid`도 있다

행·열 수가 적고 데이터가 표 형태라면 iOS 16의 `Grid` / `GridRow`가 더 적합하다. `GridItem` 배열 대신 `GridRow`로 행을 직접 쓴다.

> "A grid and its rows behave something like a collection of `HStack` instances wrapped in a `VStack`. However, the grid handles row and column creation as a single operation, which applies alignment and spacing to cells, rather than first to rows and then to a column of unrelated rows."

`GridRow` 대신 view를 바로 넣으면 **모든 열을 가로지르는 행**이 되어 구분선 같은 것을 넣기 좋다. 다만 `Grid`는 lazy가 아니므로 항목이 많으면 `LazyVGrid`를 쓴다.

## 학습 체크리스트

- [ ] `columns`를 `.flexible()` 3개로 통일해 균등 3열이 되는지 확인한다.
- [ ] `columns`를 `[GridItem(.adaptive(minimum: 50))]` 하나만 두고, 시뮬레이터를 가로/세로로 회전해 열 수가 변하는지 본다.
- [ ] `.adaptive`의 `minimum`을 50 → 100 → 150으로 바꿔가며 한 줄에 들어가는 개수가 어떻게 달라지는지 기록한다.
- [ ] `.fixed(80)`과 `.flexible()`을 섞어 왼쪽만 고정된 grid를 만든다.
- [ ] 현재의 `.adaptive` + `.flexible` × 2 조합에서 각 열이 실제로 어떻게 나뉘는지 `background(.orange)` 대신 열마다 다른 색을 줘서 확인한다.
- [ ] `GridItem`마다 다른 `spacing`을 주고 간격이 "다음 항목과의 간격"으로 적용되는지 확인한다.
- [ ] 같은 데이터를 `LazyHGrid`로 바꿔 rows를 지정하고, 늘어나는 축이 반대가 되는지 확인한다.
- [ ] `Grid` + `GridRow`로 작은 표를 만들어 `LazyVGrid`와 무엇이 다른지 설명한다.

## 참고 자료

- [Apple: GridItem](https://developer.apple.com/documentation/swiftui/griditem)
- [Apple: GridItem.Size](https://developer.apple.com/documentation/swiftui/griditem/size-swift.enum)
- [Apple: GridItem.Size.fixed(_:)](https://developer.apple.com/documentation/swiftui/griditem/size-swift.enum/fixed(_:))
- [Apple: GridItem.Size.flexible(minimum:maximum:)](https://developer.apple.com/documentation/swiftui/griditem/size-swift.enum/flexible(minimum:maximum:))
- [Apple: GridItem.Size.adaptive(minimum:maximum:)](https://developer.apple.com/documentation/swiftui/griditem/size-swift.enum/adaptive(minimum:maximum:))
- [Apple: GridItem.init(_:spacing:alignment:)](https://developer.apple.com/documentation/swiftui/griditem/init(_:spacing:alignment:))
- [Apple: LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid)
- [Apple: LazyHGrid](https://developer.apple.com/documentation/swiftui/lazyhgrid)
- [Apple: Grid](https://developer.apple.com/documentation/swiftui/grid)
- [Apple: GridRow](https://developer.apple.com/documentation/swiftui/gridrow)
- [Apple: Grouping data with lazy stack views](https://developer.apple.com/documentation/swiftui/grouping-data-with-lazy-stack-views)
- [Apple: Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)
