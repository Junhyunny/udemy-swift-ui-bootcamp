# `toolbar` API — 배치, 종류, 사용 케이스 총정리

## 질문이 나온 코드

`chapter-166/chapter-166/ContentView.swift`

```swift
NavigationStack {
    List(selection: $selectedCourses) {
        ForEach(model.data) { course in
            HStack {
                Text(course.emoji)
                Text(course.name)
            }
            .selectionDisabled(!course.published)
        }
    }
    .navigationTitle("Jun Examples")
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
        }
    }
}
```

`toolbar`로 자동 멀티 셀렉트 edit 버튼을 만들 수 있다는 것을 포함해, **어떤 사용 케이스들이 있는지** 모아 정리하는 것이 질문이다.

## 공부할 내용

### 결론 먼저 — 세 층으로 나눠 보면 쉽다

`toolbar` 관련 API는 수가 많지만 역할이 명확히 갈린다.

```text
① 무엇을 넣나   →  ToolbarItem, ToolbarItemGroup, ToolbarSpacer, DefaultToolbarItem
② 어디에 넣나   →  ToolbarItemPlacement  (.topBarTrailing, .bottomBar, .keyboard ...)
③ 어떻게 보이나 →  toolbarBackground, toolbarVisibility, toolbarTitleDisplayMode ...
```

질문의 코드는 ①의 `ToolbarItem` + ②의 배치만 쓰고 있다.

### 먼저 짚을 것 — `.navigationBarTrailing`은 구식 이름이다

공식 문서에서 `navigationBarLeading` / `navigationBarTrailing`은 **Deprecated symbols** 항목으로 분류되어 있고, 가용 범위가 `iOS: 14.0.0 - 27.0.0`으로 닫혀 있다.

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) { EditButton() }   // 구식
    ToolbarItem(placement: .topBarTrailing) { EditButton() }          // 현재 표기
}
```

현재 배포 타깃(iOS 26)에서는 아직 경고가 뜨지 않지만, **새로 쓰는 코드는 `.topBarTrailing`이 맞다.** 이름이 바뀐 이유는 iPadOS·visionOS 등에서 "navigation bar"라는 표현이 정확하지 않아서다. [deprecated API를 확인하는 방법](./deprecated-navigation-link-initializers.md)과 같은 맥락이다.

---

## ① 무엇을 넣나

### `ToolbarItem` — 하나씩 배치

가장 기본이다. 배치를 하나 정하고 뷰 하나를 넣는다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("저장") { save() }
    }
}
```

`placement`를 생략하면 `.automatic`이다.

### `ToolbarItemGroup` — 여러 개를 한 배치에

같은 자리에 버튼이 여럿이면 그룹이 간결하다.

```swift
.toolbar {
    ToolbarItemGroup(placement: .bottomBar) {
        Button("굵게") { }
        Button("기울임") { }
        Button("밑줄") { }
    }
}
```

`ToolbarItem`을 세 번 쓰는 것과 결과는 비슷하지만, **그룹은 하나의 단위로 다뤄져** 오버플로 처리나 커스터마이즈에서 함께 움직인다.

### 축약형 — 배치를 안 쓸 때

`ToolbarItem`으로 감싸지 않고 뷰를 바로 넣어도 된다.

```swift
.toolbar {
    EditButton()          // 공식 EditButton 문서의 예제가 이 형태다
}
```

배치를 직접 정할 필요가 없으면 이쪽이 짧다.

### `ToolbarSpacer` (iOS 26+) — 항목 사이를 띄우기

> A standard space item in toolbars.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) { Button("A") {} }
    ToolbarSpacer(.fixed, placement: .topBarTrailing)
    ToolbarItem(placement: .topBarTrailing) { Button("B") {} }
}
```

Liquid Glass 디자인에서 버튼들을 **시각적 그룹으로 나눌 때** 쓴다.

### `DefaultToolbarItem` (iOS 26+) — 시스템 항목을 배치

> A toolbar item that represents a system component.

검색 필드 같은 시스템 컴포넌트의 위치를 직접 정한다.

```swift
.toolbar {
    DefaultToolbarItem(kind: .search, placement: .bottomBar)
}
```

---

## ② 어디에 넣나 — `ToolbarItemPlacement`

공식 문서는 배치를 **두 부류**로 나눈다.

> - Semantic placements, such as `principal` and `navigation`, denote the intent of the item being added. SwiftUI determines the appropriate placement for the item based on this intent and its surrounding context, like the current platform.
> - Positional placements, such as `navigationBarLeading`, denote a precise placement for the item, usually for a particular platform.

**의미 기반**을 먼저 고려하는 것이 원칙이다. 플랫폼마다 알아서 적절한 자리로 간다.

### 의미 기반 배치

| 배치 | 뜻 |
|---|---|
| `.automatic` | 시스템이 알아서 |
| `.principal` | 중앙의 주요 항목 (커스텀 타이틀 뷰) |
| `.status` | 상태 표시 |
| `.primaryAction` | 주 동작 |
| `.secondaryAction` | 보조 동작 |
| `.confirmationAction` | 모달의 확인 (예: "완료") |
| `.cancellationAction` | 모달의 취소 |
| `.destructiveAction` | 모달의 파괴적 동작 |
| `.navigation` | 탐색 동작 (뒤로/앞으로) |

모달 시트에서 특히 유용하다. **플랫폼별 관례(iOS는 확인이 오른쪽, macOS는 다름)를 시스템이 처리**해 준다.

```swift
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button("취소") { dismiss() }
    }
    ToolbarItem(placement: .confirmationAction) {
        Button("완료") { save(); dismiss() }
    }
}
```

### 위치 기반 배치

| 배치 | 자리 |
|---|---|
| `.topBarLeading` | 상단 바 왼쪽 |
| `.topBarTrailing` | 상단 바 오른쪽 |
| `.topBarPinnedTrailing` | 오른쪽에 고정 (오버플로로 안 밀림) |
| `.bottomBar` | 하단 바 |
| `.keyboard` | 키보드 위 액세서리 |
| `.bottomOrnament` | 창 아래 ornament (visionOS) |
| `.title` / `.subtitle` | 타이틀·부제 영역 |
| `.largeTitle` / `.largeSubtitle` | 라지 타이틀·부제 영역 |
| `.accessoryBar(id:)` | 액세서리 바 |

`.keyboard`는 알아 두면 유용하다. 키보드가 올라올 때만 나타나는 툴바를 만든다.

```swift
.toolbar {
    ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("완료") { isFocused = false }
    }
}
```

### 공간이 부족하면

> In iOS, iPadOS, and macOS, the system uses the space available to the toolbar when determining how many items to render in the toolbar. If not all items fit in the available space, an overflow menu may be created and remaining items placed in that menu.

항목이 넘치면 **오버플로 메뉴로 자동 이동**한다. 이걸 제어하는 API가 따로 있다.

```swift
.toolbarOverflowMenu { Button("추가 동작") {} }   // 오버플로 메뉴 내용 설정
```

항목별 우선순위도 줄 수 있다.

```swift
ToolbarItem(placement: .topBarTrailing) { Button("중요") {} }
    .visibilityPriority(.high)
```

---

## ③ 어떻게 보이나 — 스타일과 가시성

### 배경과 가시성

```swift
.toolbarBackground(.blue, for: .navigationBar)              // 배경색
.toolbarBackgroundVisibility(.visible, for: .navigationBar) // 배경 항상 표시
.toolbarVisibility(.hidden, for: .navigationBar)            // 바 자체 숨김
.toolbarColorScheme(.dark, for: .navigationBar)             // 다크 스타일 강제
.toolbarForegroundStyle(.white, for: .navigationBar)        // 전경색
```

스크롤 시 배경이 사라지는 기본 동작이 싫을 때 `toolbarBackgroundVisibility(.visible, ...)`를 쓴다.

### 타이틀 표시 방식

```swift
.toolbarTitleDisplayMode(.inline)       // 항상 작게
.toolbarTitleDisplayMode(.large)        // 항상 크게
.toolbarTitleDisplayMode(.inlineLarge)  // 크게 시작해 스크롤하면 작게
```

[`NavigationStack`과 `navigationTitle` 문서](./navigation-stack-and-title.md)와 이어진다.

### 타이틀 메뉴

타이틀을 탭하면 뜨는 메뉴다. 문서 앱의 "이름 변경 / 복제 / 이동"이 이것이다.

```swift
.toolbarTitleMenu {
    RenameButton()
    Button("복제") { duplicate() }
    ShareLink(item: document.url)
}
```

### 기본 항목 제거

```swift
.toolbar(removing: .sidebarToggle)
```

### 툴바 최소화 (iOS 26+)

```swift
.toolbarMinimizationBehavior(.onScroll, for: .bottomBar)
```

스크롤에 따라 바가 줄어드는 동작을 제어한다.

---

## 사용 케이스 모음

### 케이스 1 — 편집 모드 + 멀티 셀렉트 (질문의 코드)

질문에서 관찰한 대로다. 다만 **`EditButton`만으로 멀티 셀렉트가 되는 것은 아니다.** 세 조각이 모여야 한다.

```swift
@State private var selected: Set<String> = []          // ① 선택을 담을 Set

List(selection: $selected) {                           // ② selection 바인딩
    ForEach(model.data) { course in
        HStack { Text(course.emoji); Text(course.name) }
            .selectionDisabled(!course.published)       // 선택 불가 행 지정
    }
}
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        EditButton()                                    // ③ editMode 토글
    }
}
```

```text
EditButton 탭
    ↓ @Environment(\.editMode) 를 .active 로 바꾼다
List 가 편집 모드로 전환
    ↓ selection 바인딩이 있으므로 각 행에 체크 동그라미가 생긴다
탭한 행의 id 가 selected 에 들어간다
```

`EditButton` 자체는 **환경 값 하나를 토글할 뿐**이고, 멀티 셀렉트 UI는 `List(selection:)`이 만든다. 자세한 내용은 [SwiftUI 기본 제공 버튼 문서](./builtin-swiftui-buttons.md)에 정리했다.

선택 개수를 표시하려면 이렇게 확장한다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        if !selected.isEmpty {
            Text("\(selected.count)개 선택됨")
        }
    }
    ToolbarItem(placement: .topBarTrailing) { EditButton() }
    ToolbarItem(placement: .bottomBar) {
        Button("삭제", role: .destructive) { deleteSelected() }
            .disabled(selected.isEmpty)
    }
}
```

### 케이스 2 — 모달 시트의 취소/완료

```swift
.sheet(isPresented: $isPresented) {
    NavigationStack {
        Form { /* ... */ }
            .navigationTitle("새 항목")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { save(); dismiss() }
                        .disabled(!isValid)
                }
            }
    }
}
```

의미 기반 배치를 쓰는 대표 사례다. [`sheet`의 `onDismiss` 문서](./sheet-ondismiss-and-result.md)와 이어진다.

### 케이스 3 — 커스텀 타이틀 뷰

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        HStack {
            Image(systemName: "wifi")
            Text("연결됨").font(.headline)
        }
    }
}
```

`navigationTitle`로는 텍스트만 넣을 수 있다. 아이콘이나 두 줄 타이틀이 필요하면 `.principal`을 쓴다.

### 케이스 4 — 키보드 액세서리

```swift
@FocusState private var isFocused: Bool

TextField("메모", text: $memo)
    .focused($isFocused)
    .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
            Button("취소") { memo = ""; isFocused = false }
            Spacer()
            Button("완료") { isFocused = false }
        }
    }
```

키보드를 내릴 수단이 없는 `TextField`에서 필수적이다.

### 케이스 5 — 하단 액션 바

```swift
.toolbar {
    ToolbarItemGroup(placement: .bottomBar) {
        ShareLink(item: url)
        Spacer()
        Button { toggleFavorite() } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
        }
        Spacer()
        Button(role: .destructive) { delete() } label: {
            Image(systemName: "trash")
        }
    }
}
```

Safari·Mail 같은 앱의 하단 바가 이 구조다. `Spacer()`로 균등 분배한다.

### 케이스 6 — 상태 표시

```swift
.toolbar {
    ToolbarItem(placement: .status) {
        if isSyncing {
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("동기화 중")
            }
        }
    }
}
```

### 케이스 7 — 사용자 커스터마이즈 가능한 툴바

`toolbar(id:content:)`를 쓰면 사용자가 항목을 직접 재배치할 수 있다(주로 iPadOS·macOS).

```swift
.toolbar(id: "main") {
    ToolbarItem(id: "share", placement: .primaryAction) {
        ShareLink(item: url)
    }
    ToolbarItem(id: "favorite", placement: .secondaryAction) {
        Button("즐겨찾기") { toggleFavorite() }
    }
    .customizationBehavior(.reorderable)
}
```

### 케이스 8 — 조건부 항목

`@ToolbarContentBuilder`도 `if`를 지원한다.

```swift
.toolbar {
    if isEditing {
        ToolbarItem(placement: .topBarLeading) {
            Button("전체 선택") { selectAll() }
        }
    }
    ToolbarItem(placement: .topBarTrailing) { EditButton() }
}
```

`toolbar`의 클로저는 `View`가 아니라 **`ToolbarContent`를 만드는 result builder**다. 그래서 `ToolbarItem`을 반환해야 하고, 안에 `VStack` 같은 걸 바로 넣을 수는 없다. [클로저와 result builder 문서](./closures-and-view-builders.md)와 이어진다.

---

### 헷갈리기 쉬운 것

**① `toolbar`는 `NavigationStack` 안쪽 뷰에 붙인다**

```swift
NavigationStack {
    List { }
        .navigationTitle("제목")     // ← 안쪽에 붙인다
        .toolbar { }                // ← 안쪽에 붙인다
}
// NavigationStack { }.toolbar { }  ← 이러면 동작하지 않는다
```

`navigationTitle`과 같은 규칙이다. 화면마다 툴바가 다르므로 **각 화면이 자기 툴바를 선언**하는 구조다.

**② `toolbar(_:for:)`와 `toolbar(content:)`는 다른 API다**

```swift
.toolbar { ToolbarItem { } }                    // 항목 채우기
.toolbar(.hidden, for: .navigationBar)          // 가시성 설정
```

이름이 같아 헷갈린다. 후자는 `toolbarVisibility(_:for:)`로 이름이 정리되고 있다.

**③ 배치는 플랫폼마다 다르게 해석된다**

`.primaryAction`은 iOS에서 상단 오른쪽, macOS에서 툴바 오른쪽으로 간다. **위치를 하드코딩하지 말고 의미를 쓰라**는 것이 공식 권고다.

### 이 코드에 적용하면

지금 코드는 최소 형태이고, 다듬는다면 이렇다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {   // navigationBarTrailing → topBarTrailing
        EditButton()
    }
}
```

멀티 셀렉트를 실제로 쓸 거라면 선택 항목으로 무언가를 하는 동작이 필요하다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) { EditButton() }
    ToolbarItemGroup(placement: .bottomBar) {
        Button("삭제", role: .destructive) { }
            .disabled(selectedCourses.isEmpty)
        Spacer()
        Text("\(selectedCourses.count)개 선택")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
```

## 체크리스트

- [ ] `.navigationBarTrailing`을 `.topBarTrailing`으로 바꾸고 동작이 같은지 확인한다.
- [ ] `ToolbarItem`으로 감싸지 않고 `EditButton()`만 넣어 보고 차이를 본다.
- [ ] 의미 기반 배치와 위치 기반 배치를 각각 한 문장으로 구분해 설명한다.
- [ ] 시트에서 `.cancellationAction` / `.confirmationAction`을 써 보고 배치를 관찰한다.
- [ ] `.principal`로 아이콘 + 텍스트 커스텀 타이틀을 만든다.
- [ ] `.keyboard` 배치로 키보드 위 "완료" 버튼을 만든다.
- [ ] `ToolbarItemGroup(placement: .bottomBar)`에 `Spacer()`를 섞어 하단 바를 만든다.
- [ ] 툴바 항목을 10개 넣어 오버플로 메뉴가 생기는지 확인한다.
- [ ] `toolbarBackgroundVisibility(.visible, for: .navigationBar)`로 스크롤 시 배경을 고정한다.
- [ ] `toolbarTitleMenu`로 타이틀 탭 메뉴를 만든다.
- [ ] `toolbar`를 `NavigationStack` 바깥에 붙여 보고 동작하지 않는 것을 확인한다.
- [ ] `toolbar` 클로저 안에 `VStack`을 넣어 보고 오류를 읽는다.
- [ ] 선택 개수 표시와 삭제 버튼을 추가해 멀티 셀렉트를 완성한다.

## 공식 참고 자료

- [SwiftUI: Toolbars](https://developer.apple.com/documentation/swiftui/toolbars)
- [SwiftUI: toolbar(content:)](https://developer.apple.com/documentation/swiftui/view/toolbar(content:))
- [SwiftUI: ToolbarItem](https://developer.apple.com/documentation/swiftui/toolbaritem)
- [SwiftUI: ToolbarItemGroup](https://developer.apple.com/documentation/swiftui/toolbaritemgroup)
- [SwiftUI: ToolbarItemPlacement](https://developer.apple.com/documentation/swiftui/toolbaritemplacement)
- [SwiftUI: ToolbarSpacer](https://developer.apple.com/documentation/swiftui/toolbarspacer)
- [SwiftUI: DefaultToolbarItem](https://developer.apple.com/documentation/swiftui/defaulttoolbaritem)
- [SwiftUI: ToolbarContent](https://developer.apple.com/documentation/swiftui/toolbarcontent)
- [SwiftUI: toolbar(id:content:)](https://developer.apple.com/documentation/swiftui/view/toolbar(id:content:))
- [SwiftUI: toolbarTitleMenu(content:)](https://developer.apple.com/documentation/swiftui/view/toolbartitlemenu(content:))
- [SwiftUI: toolbarVisibility(_:for:)](https://developer.apple.com/documentation/swiftui/view/toolbarvisibility(_:for:))
- [SwiftUI: toolbarTitleDisplayMode(_:)](https://developer.apple.com/documentation/swiftui/view/toolbartitledisplaymode(_:))
- [Human Interface Guidelines: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
