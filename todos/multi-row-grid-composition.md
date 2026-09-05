# 여러 행으로 grid를 구성하는 방법과 공식 예제

각 `GridItem`의 크기 지정 방식(`.fixed` / `.flexible` / `.adaptive`)은 [GridItem으로 만들 수 있는 grid의 종류](./grid-item-sizing.md)에서 다룬다. 이 문서는 **행을 여러 개 두고 grid를 구성하는 방법**에 집중한다.

## 질문이 나온 코드

`chapter-24/chapter-24/ContentView.swift`의 `rows` 배열과 `LazyHGrid(rows: rows)`

## 공부할 내용

### 먼저 채워지는 방향을 알아야 한다

`LazyHGrid`는 가로로 자라므로 **행 수를 `rows` 배열로 고정**하고 열이 무한히 늘어난다.

> "The number of columns can grow unbounded, but you specify the number of rows by providing a corresponding number of `GridItem` instances to the grid's initializer."

채워지는 순서가 핵심이다.

> "The first view that you provide to the grid's `content` closure appears in the top row of the column that's on the grid's leading edge. Additional views occupy successive cells in the grid, filling the first column from top to bottom, then the second column, and so on."

즉 **한 열을 위에서 아래로 다 채운 뒤 다음 열로 넘어간다.** 지금 코드는 행이 3개이고 `ForEach`가 항목마다 view를 하나씩 만드니, 1~3번이 첫 열, 4~6번이 둘째 열에 들어가고 100개면 34번째 열까지 생긴다. `LazyVGrid`는 정확히 반대로 한 행을 좌우로 채운 뒤 다음 행으로 내려간다.

### 공식 예제 1 — 행마다 크기와 간격을 다르게 (`GridItem` 문서)

`GridItem` 문서가 바로 "행을 여러 개 쓰는" 예제를 보여 준다. 행마다 `.fixed` 값과 `spacing`이 전부 다르다.

```swift
let rows = [
    GridItem(.fixed(30), spacing: 1),
    GridItem(.fixed(60), spacing: 10),
    GridItem(.fixed(90), spacing: 20),
    GridItem(.fixed(10), spacing: 50)
]

ScrollView(.horizontal) {
    LazyHGrid(rows: rows, spacing: 5) {
        ForEach(0...300, id: \.self) { _ in
            Color.red.frame(width: 30)
            Color.green.frame(width: 30)
            Color.blue.frame(width: 30)
            Color.yellow.frame(width: 30)
        }
    }
}
```

여기서 두 가지를 배울 수 있다. 첫째, **행마다 성격을 다르게 줄 수 있다.** 둘째, `GridItem`의 `spacing`은 "그 항목과 다음 항목 사이" 간격이므로 행 사이 간격이 제각각이 된다. `LazyHGrid`에 준 `spacing: 5`는 그와 별개로 **열 사이** 간격이다.

### 공식 예제 2 — 한 번의 반복으로 여러 행을 채우기 (`LazyHGrid` 문서)

```swift
let rows = [GridItem(.fixed(30)), GridItem(.fixed(30))]

ScrollView(.horizontal) {
    LazyHGrid(rows: rows) {
        ForEach(0x1f600...0x1f679, id: \.self) { value in
            Text(String(format: "%x", value))
            Text(emoji(value))
                .font(.largeTitle)
        }
    }
}
```

`ForEach` 한 번에 view를 **2개** 만들고 행도 2개다. 그래서 반복 한 번이 열 하나를 통째로 채우고, 위 칸에는 코드값·아래 칸에는 이모지가 짝지어 놓인다. 위 예제 1도 view 4개 / 행 4개로 같은 구조다.

**행 수와 반복당 view 수를 맞추는 것**이 multi-row grid의 핵심 idiom이다. 지금 chapter-24 코드는 행 3개에 반복당 view 1개라 항목이 순서대로 흘러가는 형태인데, 반복당 view를 3개로 만들면 "열 하나 = 의미 있는 묶음 하나"가 된다.

### 행을 명시적으로 쓰는 `Grid` / `GridRow`

항목이 적고 표 형태라면 `GridItem` 배열 대신 행을 직접 나열하는 `Grid`가 낫다.

> "A grid and its rows behave something like a collection of `HStack` instances wrapped in a `VStack`. However, the grid handles row and column creation as a single operation, which applies alignment and spacing to cells, rather than first to rows and then to a column of unrelated rows."

```swift
Grid {
    GridRow {
        Text("Hello")
        Image(systemName: "globe")
    }
    GridRow {
        Image(systemName: "hand.wave")
        Text("World")
    }
}
```

행을 여러 개 다룰 때 알아 둘 기능들이 있다.

**행 전체를 가로지르는 요소** — `GridRow` 대신 view를 바로 넣으면 모든 열을 span하는 행이 된다. 행 사이 구분선에 쓴다.

```swift
Grid {
    GridRow { Text("Hello"); Image(systemName: "globe") }
    Divider()
    GridRow { Image(systemName: "hand.wave"); Text("World") }
}
```

다만 `Divider`는 부모가 주는 만큼 폭을 차지해서 grid 전체가 화면 폭까지 늘어난다. `gridCellUnsizedAxes(.horizontal)`을 붙이면 다른 셀들이 요구하는 폭으로 되돌아온다.

**명시적 행 + 반복 생성 행 섞기** — `GridRow` 문서의 예제가 헤더 행 하나를 직접 쓰고 나머지는 `ForEach`로 만든다.

```swift
Grid {
    GridRow {
        Color.clear
            .gridCellUnsizedAxes([.horizontal, .vertical])
        ForEach(1..<4) { column in Text("C\(column)") }
    }
    ForEach(1..<4) { row in
        GridRow {
            Text("R\(row)")
            ForEach(1..<4) { _ in Circle().foregroundStyle(.mint) }
        }
    }
}
```

**여러 열 걸치기** — `gridCellColumns(_:)`. 기본적으로 `GridRow`의 view 하나가 열 하나에 대응하는데, 이 modifier로 여러 열을 차지하게 한다.

**열 단위 정렬** — `gridColumnAlignment(_:)`는 그 view가 속한 **열 전체**의 가로 정렬을 바꾼다. 행마다 반복해서 지정할 필요가 없다.

**셀 단위 정렬** — `gridCellAnchor(_:)`는 특정 셀만 anchor 기반 정렬로 바꾼다.

### 어느 것을 쓸까

- 항목이 많고 스크롤한다 → `LazyHGrid` / `LazyVGrid` + `GridItem` 배열
- 행 수가 적고 행마다 셀 구성이 다르다(설정 화면, 표) → `Grid` + `GridRow`

## 학습 체크리스트

- [ ] 현재 코드에서 항목 번호가 열 방향으로 채워지는지(1·2·3이 첫 열) 확인한다.
- [ ] `rows`를 `[.fixed(30), .fixed(60), .fixed(90)]`처럼 크기가 다른 행으로 바꿔 본다.
- [ ] `GridItem`마다 다른 `spacing`을 주고, `LazyHGrid(rows:spacing:)`의 spacing과 무엇이 다른지 구분해 설명한다.
- [ ] `ForEach` 한 번에 view를 3개 만들어(행 수와 동일) 열 하나가 한 묶음이 되게 바꾼다.
- [ ] 같은 데이터를 `LazyVGrid`로 옮겨 채워지는 방향이 반대가 되는 것을 확인한다.
- [ ] `Grid` + `GridRow`로 2행 2열 표를 만들고 사이에 `Divider()`를 넣는다.
- [ ] 그 `Divider()`에 `gridCellUnsizedAxes(.horizontal)`을 붙였을 때 grid 폭이 어떻게 달라지는지 비교한다.
- [ ] `gridCellColumns(2)`로 한 셀이 두 열을 차지하게 만든다.
- [ ] 헤더 행은 직접 쓰고 본문 행은 `ForEach`로 생성하는 표를 만든다.

## 참고 자료

- [Apple: LazyHGrid (rows 예제)](https://developer.apple.com/documentation/swiftui/lazyhgrid)
- [Apple: LazyHGrid.init(rows:alignment:spacing:pinnedViews:content:)](https://developer.apple.com/documentation/swiftui/lazyhgrid/init(rows:alignment:spacing:pinnedviews:content:))
- [Apple: GridItem (행마다 크기·간격이 다른 예제)](https://developer.apple.com/documentation/swiftui/griditem)
- [Apple: LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid)
- [Apple: Grid](https://developer.apple.com/documentation/swiftui/grid)
- [Apple: GridRow (명시적 행 + ForEach 혼합 예제)](https://developer.apple.com/documentation/swiftui/gridrow)
- [Apple: View.gridCellColumns(_:)](https://developer.apple.com/documentation/swiftui/view/gridcellcolumns(_:))
- [Apple: View.gridCellUnsizedAxes(_:)](https://developer.apple.com/documentation/swiftui/view/gridcellunsizedaxes(_:))
- [Apple: View.gridCellAnchor(_:)](https://developer.apple.com/documentation/swiftui/view/gridcellanchor(_:))
- [Apple: View.gridColumnAlignment(_:)](https://developer.apple.com/documentation/swiftui/view/gridcolumnalignment(_:))
- [Apple: Grid.init(alignment:horizontalSpacing:verticalSpacing:content:)](https://developer.apple.com/documentation/swiftui/grid/init(alignment:horizontalspacing:verticalspacing:content:))
- [Apple: Layout adjustments](https://developer.apple.com/documentation/swiftui/layout-adjustments)
