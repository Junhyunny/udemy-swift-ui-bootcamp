# SwiftUI가 이미 제공하는 버튼들 — `EditButton`과 그 형제들

## 질문이 나온 코드

`chapter-166/chapter-166/ContentView.swift`

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        EditButton()
    }
}
```

`EditButton`은 SwiftUI가 이미 제공하는 버튼인 것 같은데, **다른 버튼도 있는지, 어떤 종류가 있는지**가 질문이다.

## 공부할 내용

### 결론 먼저

있다. 공식 문서는 이들을 **"special-purpose buttons"**라는 이름으로 묶어 둔다. 공통점은 **동작·모양·현지화가 이미 정해져 있어 내가 구현할 필요가 없다**는 것이다.

```text
Button        →  내가 동작을 정한다. 껍데기만 제공
특수 버튼      →  동작까지 시스템이 안다. 이름·아이콘·번역도 따라온다
```

`EditButton`을 `Button("편집")`으로 직접 만들면 **"Edit" ↔ "Done" 전환, 30개 언어 번역, 편집 모드 전파**를 전부 손으로 해야 한다.

### 한눈에 보기

| 버튼 | 하는 일 | iOS |
|---|---|---|
| `Button` | 기본. 동작은 내가 | 13 |
| `EditButton` | `editMode` 환경 값 토글 | 13 |
| `PasteButton` | 클립보드를 읽어 클로저에 전달 | 16 |
| `RenameButton` | 표준 이름 변경 동작 발동 | 16 |
| `ShareLink` | 공유 시트 표시 | 16 |
| `Link` | URL 열기 | 14 |
| `TextFieldLink` | 눌러서 텍스트 입력 요청 | watchOS 중심 |
| `HelpLink` | 앱 도움말 열기 | macOS 중심 |
| `Toggle` | 켜짐/꺼짐 (버튼처럼 스타일 가능) | 13 |
| `Menu` | 눌러서 메뉴 표시 | 14 |

플랫폼 제약이 있는 것들이 있다. **`EditButton`은 iOS·iPadOS·macCatalyst·visionOS 전용**이고 macOS·tvOS·watchOS에는 없다.

---

## 1. `EditButton` — 지금 쓰고 있는 것

공식 정의는 한 줄이다.

> A button that toggles the edit mode environment value.

**이 버튼이 하는 일은 환경 값 하나를 뒤집는 것뿐**이다. 나머지는 주변 뷰가 반응한다.

```text
EditButton 탭
    ↓
@Environment(\.editMode) 가 .inactive ↔ .active
    ↓
편집 모드를 지원하는 컨테이너(List 등)가 알아서 반응
    ↓
레이블도 "Edit" ↔ "Done" 으로 바뀐다 (번역 포함)
```

공식 문서의 예제는 삭제·이동 쪽이다.

```swift
@State private var fruits = ["Apple", "Banana", "Papaya", "Mango"]

var body: some View {
    NavigationView {
        List {
            ForEach(fruits, id: \.self) { fruit in
                Text(fruit)
            }
            .onDelete { fruits.remove(atOffsets: $0) }
            .onMove { fruits.move(fromOffsets: $0, toOffset: $1) }
        }
        .navigationTitle("Fruits")
        .toolbar {
            EditButton()
        }
    }
}
```

> Because the `ForEach` in the above example defines behaviors for `onDelete(perform:)` and `onMove(perform:)`, the editable list displays the delete and move UI when the user taps Edit. Notice that the Edit button displays the title "Done" while edit mode is active.

**중요한 점은 `EditButton`이 삭제·이동 UI를 만드는 게 아니라는 것**이다. `onDelete`·`onMove`가 있어야 그 UI가 생긴다. 버튼은 스위치일 뿐이다.

### 멀티 셀렉트는 어디서 오나

질문의 코드는 삭제·이동이 아니라 **선택**이다. 이것도 `EditButton`이 만드는 게 아니다.

```swift
@State private var selectedCourses: Set<String> = []   // ① 선택 담을 Set

List(selection: $selectedCourses) {                    // ② selection 바인딩
    ForEach(model.data) { course in
        HStack { Text(course.emoji); Text(course.name) }
            .selectionDisabled(!course.published)       // ③ 선택 불가 행
    }
}
.toolbar { EditButton() }                              // ④ 스위치
```

네 조각의 역할이 각각 다르다.

| 조각 | 없으면 |
|---|---|
| `Set<String>` 상태 | 선택을 담을 곳이 없다 |
| `List(selection:)` | **체크 동그라미가 아예 안 생긴다** |
| `selectionDisabled` | 미공개 강의도 선택된다 |
| `EditButton` | 편집 모드로 들어갈 방법이 없다 |

`Set`의 원소 타입이 `String`인 이유는 `CourseModel.id`가 `String`이기 때문이다.

```swift
struct CourseModel: Identifiable, Hashable {
    var name: String
    var id: String { name }     // ← 이 타입이 Set 의 원소 타입이 된다
}
```

`List(selection:)`은 각 행의 **identity 값**을 모은다. [`Identifiable` 프로토콜 문서](./025-identifiable-protocol.md), [`id`에 쓰이는 `Hashable` 문서](./026-hashable-id-and-collisions.md)와 이어진다.

### 편집 상태를 직접 읽기

내 뷰가 편집 모드에 반응해야 하면 환경 값을 읽는다.

```swift
@Environment(\.editMode) private var editMode

var body: some View {
    VStack {
        if editMode?.wrappedValue.isEditing == true {
            Text("항목을 선택하세요")
        }
    }
}
```

`editMode`는 `Binding<EditMode>?`라 **옵셔널이고 두 번 벗겨야** 한다. `EditMode`에는 `.inactive`, `.transient`, `.active` 세 상태가 있고 `isEditing` 계산 프로퍼티가 있다. [`@Environment` 문서](./048-environment-property-wrapper.md)와 이어진다.

`EditButton` 대신 직접 토글할 수도 있다.

```swift
Button(editMode?.wrappedValue.isEditing == true ? "완료" : "편집") {
    withAnimation {
        editMode?.wrappedValue = editMode?.wrappedValue.isEditing == true
            ? .inactive : .active
    }
}
```

**직접 만들면 번역이 사라진다.** 특별한 이유가 없으면 `EditButton`을 쓰는 편이 낫다.

---

## 2. `ShareLink` — 공유 시트

가장 자주 쓰게 되는 특수 버튼이다.

```swift
ShareLink(item: URL(string: "https://apple.com")!)

ShareLink("이 강의 공유", item: courseURL)

ShareLink(
    item: courseURL,
    subject: Text("추천 강의"),
    message: Text("이거 좋더라")
)
```

미리보기를 붙일 수도 있다.

```swift
ShareLink(
    item: course.url,
    preview: SharePreview(course.name, image: Image("thumbnail"))
)
```

`UIActivityViewController`를 직접 띄우던 일을 **한 줄로** 대체한다. 툴바에 넣기 좋다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        ShareLink(item: url)
    }
}
```

## 3. `Link` — URL 열기

```swift
Link("애플 홈페이지", destination: URL(string: "https://apple.com")!)

Link(destination: url) {
    Label("문서 보기", systemImage: "doc.text")
}
```

`Button { openURL(url) }`과 비슷하지만, **링크라는 의미가 접근성에 전달**되고 시스템이 적절히 처리한다. 딥링크·커스텀 스킴도 열 수 있다. [딥링크와 URL 스킴 문서](./085-deep-link-and-url-scheme.md)와 이어진다.

`@Environment(\.openURL)`을 쓰면 버튼 없이 코드에서 열 수 있다.

```swift
@Environment(\.openURL) private var openURL
// ...
Button("열기") { openURL(url) }
```

## 4. `PasteButton` — 붙여넣기

> A system button that reads items from the pasteboard and delivers it to a closure.

```swift
@State private var text = ""

PasteButton(payloadType: String.self) { strings in
    text = strings.first ?? ""
}
```

시스템 버튼이라 **사용자가 누르는 순간에만** 클립보드에 접근한다. 직접 `UIPasteboard.general.string`을 읽으면 iOS가 "앱이 클립보드를 읽었습니다" 알림을 띄우지만, `PasteButton`은 그 알림이 뜨지 않는다. **개인정보 측면에서 권장되는 방식**이다.

## 5. `RenameButton` — 이름 변경

> A button that triggers a standard rename action.

단독으로는 동작하지 않고 `renameAction(_:)`과 짝을 이룬다.

```swift
@FocusState private var isRenaming: Bool

TextField("이름", text: $name)
    .focused($isRenaming)
    .contextMenu {
        RenameButton()
    }
    .renameAction { isRenaming = true }
```

타이틀 메뉴에 넣는 것도 전형적이다.

```swift
.toolbarTitleMenu {
    RenameButton()
}
```

## 6. `Menu` — 눌러서 메뉴

버튼처럼 생겼지만 누르면 목록이 뜬다.

```swift
Menu("더 보기") {
    Button("복제") { duplicate() }
    Button("이름 변경") { rename() }
    Divider()
    Button("삭제", role: .destructive) { delete() }
}
```

레이블을 커스텀할 수 있다.

```swift
Menu {
    Button("최신순") { sort = .newest }
    Button("이름순") { sort = .name }
} label: {
    Image(systemName: "ellipsis.circle")
}
```

툴바 공간이 부족할 때 여러 동작을 하나로 접는 표준 수단이다.

---

## 특수 버튼이 아니라 `Button`을 꾸미는 것들

"다른 버튼"을 찾을 때 헷갈리기 쉬운데, **별도 타입이 아니라 `Button`에 붙이는 설정**인 것들이 있다.

### `ButtonRole` — 의미 부여

```swift
Button("삭제", role: .destructive) { delete() }   // 빨갛게, 확인창에서 강조
Button("취소", role: .cancel) { }                 // 취소 위치로
Button("닫기", role: .close) { dismiss() }        // 닫기 (iOS 26+)
Button("확인", role: .confirm) { }                // 확인 (iOS 26+)
```

`role`은 **색과 배치를 시스템이 정하게** 한다. 직접 `.foregroundStyle(.red)`를 칠하는 것보다 낫다 — 플랫폼·다크 모드·접근성 설정에 맞게 조정된다.

`confirmationDialog`나 `alert` 안에서 특히 의미가 크다.

```swift
.confirmationDialog("삭제할까요?", isPresented: $showDialog) {
    Button("삭제", role: .destructive) { delete() }
    Button("취소", role: .cancel) { }
}
```

### `buttonStyle` — 모양

```swift
Button("저장") { }.buttonStyle(.borderedProminent)   // 채워진 강조 버튼
Button("취소") { }.buttonStyle(.bordered)            // 테두리 버튼
Button("더보기") { }.buttonStyle(.borderless)        // 장식 없음
Button("전체") { }.buttonStyle(.plain)               // 기본 꾸밈 제거
Button("유리") { }.buttonStyle(.glass)               // Liquid Glass (iOS 26+)
Button("유리강조") { }.buttonStyle(.glassProminent)  // (iOS 26+)
```

`chapter-162`에서 쓴 `.buttonStyle(.glassProminent)`가 이 계열이다.

직접 스타일을 만들 수도 있다.

```swift
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}
```

`makeBody`가 override가 아니라 프로토콜 요구사항이라는 점은 [style 프로토콜 문서](./036-protocol-requirements-and-style-protocols.md)에 정리되어 있다.

### 그 밖의 설정

```swift
.buttonBorderShape(.capsule)          // 테두리 모양
.buttonRepeatBehavior(.enabled)       // 길게 누르면 반복 실행
.buttonSizing(.fitted)                // 크기 정책 (iOS 26+)
.controlSize(.large)                  // 컨트롤 크기
```

---

### 선택 기준

```text
동작이 시스템에 이미 정의되어 있나?
   ├─ 편집 모드 토글        → EditButton
   ├─ 공유                  → ShareLink
   ├─ URL 열기              → Link
   ├─ 붙여넣기              → PasteButton
   ├─ 이름 변경             → RenameButton + renameAction
   ├─ 여러 동작 접기         → Menu
   └─ 그 외                 → Button
                               ├─ 의미가 있나?  → role
                               └─ 모양을 바꾸나? → buttonStyle
```

**특수 버튼이 있으면 특수 버튼을 쓴다.** 번역·접근성·플랫폼별 관례가 공짜로 따라오기 때문이다.

### 이 코드에 적용하면

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        EditButton()
    }
}
```

`EditButton`은 올바른 선택이다. 여기에 선택 항목으로 무언가를 하려면 다른 버튼들을 섞으면 된다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) { EditButton() }
    ToolbarItemGroup(placement: .bottomBar) {
        Button("삭제", role: .destructive) { deleteSelected() }
            .disabled(selectedCourses.isEmpty)
        Spacer()
        ShareLink(items: selectedCourses.sorted())
            .disabled(selectedCourses.isEmpty)
    }
}
```

배치와 툴바 API 전반은 [`toolbar` API 문서](./082-toolbar-api-use-cases.md)에 정리되어 있다.

## 체크리스트

- [ ] `EditButton`이 하는 일이 "환경 값 토글"뿐임을 설명한다.
- [ ] `List(selection:)`을 지우고 체크 동그라미가 사라지는 것을 확인한다.
- [ ] `selectionDisabled(!course.published)`를 지우고 미공개 강의도 선택되는지 본다.
- [ ] `onDelete`·`onMove`를 추가해 편집 모드에서 삭제·이동 UI가 생기는 것을 본다.
- [ ] `@Environment(\.editMode)`를 읽어 편집 상태에 따라 텍스트를 바꿔 본다.
- [ ] `EditButton`을 직접 만든 `Button`으로 대체하고 번역이 사라지는 것을 확인한다.
- [ ] 기기 언어를 바꿔 `EditButton` 레이블이 번역되는지 확인한다.
- [ ] `ShareLink`를 툴바에 넣어 공유 시트를 띄운다.
- [ ] `PasteButton`과 직접 클립보드 읽기를 비교해 알림 차이를 관찰한다.
- [ ] `RenameButton` + `renameAction`으로 이름 변경 흐름을 만든다.
- [ ] `Button(role: .destructive)`와 `.foregroundStyle(.red)`의 차이를 다크 모드에서 비교한다.
- [ ] `buttonStyle`을 `.bordered` / `.borderedProminent` / `.glass`로 바꿔 본다.
- [ ] 커스텀 `ButtonStyle`을 만들어 눌림 효과를 준다.

## 공식 참고 자료

- [SwiftUI: Controls and indicators](https://developer.apple.com/documentation/swiftui/controls-and-indicators)
- [SwiftUI: EditButton](https://developer.apple.com/documentation/swiftui/editbutton)
- [SwiftUI: EditMode](https://developer.apple.com/documentation/swiftui/editmode)
- [SwiftUI: EnvironmentValues — editMode](https://developer.apple.com/documentation/swiftui/environmentvalues/editmode)
- [SwiftUI: ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)
- [SwiftUI: SharePreview](https://developer.apple.com/documentation/swiftui/sharepreview)
- [SwiftUI: Link](https://developer.apple.com/documentation/swiftui/link)
- [SwiftUI: PasteButton](https://developer.apple.com/documentation/swiftui/pastebutton)
- [SwiftUI: RenameButton](https://developer.apple.com/documentation/swiftui/renamebutton)
- [SwiftUI: Menu](https://developer.apple.com/documentation/swiftui/menu)
- [SwiftUI: Button](https://developer.apple.com/documentation/swiftui/button)
- [SwiftUI: ButtonRole](https://developer.apple.com/documentation/swiftui/buttonrole)
- [SwiftUI: buttonStyle(_:)](https://developer.apple.com/documentation/swiftui/view/buttonstyle(_:))
- [SwiftUI: List — selection](https://developer.apple.com/documentation/swiftui/list)
- [SwiftUI: selectionDisabled(_:)](https://developer.apple.com/documentation/swiftui/view/selectiondisabled(_:))
