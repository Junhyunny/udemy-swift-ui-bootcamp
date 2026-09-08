# `PreferenceKey` — 자식이 조상에게 값을 올려 보내는 통로

## 질문이 나온 코드

`chapter-47/chapter-47/ContentView.swift`

```swift
struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize

    static let defaultValue: Value = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
```

```swift
content.background(
    GeometryReader { proxy in
        Color.clear
            .preference(
                key: SizePreferenceKey.self,
                value: proxy.size
            )
    }
)
```

```swift
modifier(MeasuringSizeModifier())
    .onPreferenceChange(SizePreferenceKey.self, perform: action)
```

## 공부할 내용

### 왜 필요한가 — 데이터가 흐르는 방향 문제

SwiftUI에서 데이터는 기본적으로 **위에서 아래로** 흐른다.

| 방향 | 수단 |
| --- | --- |
| 부모 → 자식 | 프로퍼티 전달, `@Binding`, `@Environment` |
| 자식 → 부모 | **`PreferenceKey`** |

`@Binding`은 부모가 이미 갖고 있는 값을 자식이 고쳐 쓰는 것이라, "자식만 아는 값을 부모에게 알린다"와는 다르다. 자식이 **렌더링된 뒤에야 알 수 있는 값**(자기 크기, 자기 위치, 자기가 원하는 제목)을 조상에게 전달하려면 별도의 통로가 필요하고, 그게 preference 시스템이다.

Apple 문서의 `PreferenceKey` 설명이 이 성격을 그대로 말한다.

> A view with multiple children automatically combines its values for a given preference into a single value visible to its ancestors.

핵심 단어가 **`visible to its ancestors`** 다. 값이 뷰 트리를 타고 **위로** 올라간다.

이 예제가 하려는 일이 정확히 그것이다. `Text`의 실제 크기는 SwiftUI가 레이아웃을 마쳐야 정해진다. 그 값을 `ContentView`의 `@State viewSize`로 끌어올려야 하는데, 부모는 그걸 알 방법이 없다. 그래서 `GeometryReader`로 측정하고 preference로 올려 보낸다.

```text
ContentView (@State viewSize)          ← ③ onPreferenceChange가 받아서 State에 저장
   └ Text
       └ background
           └ GeometryReader (proxy.size)  ← ① 크기 측정
               └ Color.clear
                   .preference(...)       ← ② 값을 위로 올림
```

### 프로토콜의 세 가지 요구사항

```swift
protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
    static func reduce(value: inout Self.Value, nextValue: () -> Self.Value)
}
```

**1. `associatedtype Value` — 무엇을 올려 보낼 것인가**

`associatedtype`이라 구현하는 쪽이 구체 타입을 정한다. 이 예제는 `CGSize`다. 왜 `typealias Value = CGSize`를 쓸 수 있고, 왜 굳이 쓸 필요는 없는지는 [typealias와 associatedtype](./typealias-and-associated-type.md)에서 따로 다룬다.

**2. `static var defaultValue` — 아무도 값을 주지 않았을 때의 값**

> Views that have no explicit value for the key produce this default value. Combining child views may remove an implicit value produced by using the default. This means that `reduce(value: &x, nextValue: {defaultValue})` shouldn't change the meaning of x.

마지막 문장이 중요한 설계 규칙이다. **default 값이 섞여 들어와도 결과가 바뀌면 안 된다.** 수학의 항등원과 같은 역할이다.

| `Value` 타입 | 적절한 `defaultValue` | 이유 |
| --- | --- | --- |
| `CGSize` | `.zero` | 크기 합산·최대값 계산에서 무해 |
| `[T]` | `[]` | 배열 이어붙이기의 항등원 |
| `CGFloat` (최대값 수집) | `0` 또는 `-.infinity` | `max`의 항등원 |
| `String?` | `nil` | 없음을 뜻함 |

**3. `static func reduce` — 형제가 여럿일 때 어떻게 합칠 것인가**

> This method receives its values in view-tree order. Conceptually, this combines the preference value from one tree with that of its next sibling.

`value`가 `inout`인 것은 **누적 결과를 계속 갱신**하기 때문이다. `nextValue`가 클로저(`() -> Value`)인 것은 필요할 때만 평가하기 위해서다.

`reduce`의 몸통이 곧 합치기 정책이다.

```swift
// 이 예제 — 마지막 값이 이긴다
static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
}

// 가장 큰 높이를 고르고 싶다면
static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
}

// 전부 모으고 싶다면
static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
    value.append(contentsOf: nextValue())
}
```

**이 예제에서 `value = nextValue()`가 안전한 이유**는 값을 올려 보내는 뷰가 `Color.clear` 하나뿐이기 때문이다. 형제가 여럿인 상황에서 이 구현을 쓰면 **마지막 값만 남고 나머지는 조용히 사라진다.** 여러 자식의 크기를 각각 알아야 하는 컴포넌트로 확장할 때 가장 먼저 깨지는 지점이므로 기억해 둔다.

### `preference(key:value:)` — 값을 올려 보내는 쪽

```swift
nonisolated func preference<K>(key: K.Type = K.self, value: K.Value) -> some View
    where K : PreferenceKey
```

`key` 파라미터의 타입이 `K.Type`이다. 인스턴스가 아니라 **타입 자체**를 넘긴다. 그래서 `SizePreferenceKey()`가 아니라 `SizePreferenceKey.self`를 쓴다. 이 `.self`의 정체는 [메타타입과 `.self`](./metatype-and-self.md)에서 다룬다.

기본값이 `K.Type = K.self`인 점도 눈여겨볼 만하다. 타입 추론이 가능한 자리라면 생략할 수도 있다는 뜻이다.

`Color.clear`에 붙이는 것에도 이유가 있다. 측정은 하되 **화면에 아무것도 그리지 않고 레이아웃도 건드리지 않아야** 하기 때문이다. `background` 안의 `GeometryReader`는 부모가 제안한 크기를 그대로 받으므로, 이 조합이 크기 측정의 표준 관용구가 된다. 자세한 배경은 [GeometryReader 활용](./geometry-reader-use-cases.md)에 있다.

### `onPreferenceChange(_:perform:)` — 값을 받는 쪽

```swift
nonisolated func onPreferenceChange<K>(
    _ key: K.Type = K.self,
    perform action: @escaping (K.Value) -> Void
) -> some View where K : PreferenceKey, K.Value : Equatable
```

> A view that triggers `action` when the value for `key` changes.

주목할 제약이 둘 있다.

- **`K.Value : Equatable`** — 값이 실제로 **바뀌었을 때만** 콜백이 불린다. 같은 값이 다시 올라오면 무시된다. `CGSize`는 `Equatable`이라 이 예제가 성립한다.
- **`@escaping`** — 이 클로저는 `onPreferenceChange` 호출이 끝난 뒤 값이 바뀔 때마다 불린다. 그래서 저장되어야 하고, 저장되는 클로저에는 `@escaping`이 필요하다. 그 결과 `measureSzie(perform:)`의 `action` 파라미터도 `@escaping`이어야 한다. `@escaping`의 의미는 [클로저와 view builder](./closures-and-view-builders.md)에서 다뤘다.

예제에서 `action`이 무엇인지 따라가 보면 이렇다.

```swift
.measureSzie { size in
    viewSize = size        // ← 이 클로저가 action
}
```

```swift
func measureSzie(perform action: @escaping (CGSize) -> Void) -> some View {
    modifier(MeasuringSizeModifier())
        .onPreferenceChange(SizePreferenceKey.self, perform: action)
        //                                          └── 그대로 전달만 한다
}
```

즉 `action`은 **호출한 쪽이 준 콜백**이고, `measureSzie`는 그것을 `onPreferenceChange`에 연결해 주는 배선 역할만 한다. `CGSize`를 받아 아무것도 돌려주지 않는 `(CGSize) -> Void` 타입이다.

### 전체 흐름 정리

```text
① Text가 렌더링될 크기가 정해진다
        ↓
② background의 GeometryReader가 proxy.size로 읽는다
        ↓
③ Color.clear가 .preference(key: SizePreferenceKey.self, value: proxy.size)로 올려 보낸다
        ↓
④ 트리를 타고 위로 올라가며 형제가 있으면 reduce로 합쳐진다
        ↓
⑤ onPreferenceChange가 값 변화를 감지한다 (Equatable 비교)
        ↓
⑥ action(size) 호출 → viewSize = size
```

### 주의점

**1. 무한 루프 위험**

측정한 크기로 **자기 자신의 크기를 다시 정하면** 순환이 생긴다. 이 예제가 실제로 그 경계에 서 있다.

```swift
Text("This view knows its own size.")
    .frame(width: viewSize.width, height: viewSize.height)   // viewSize로 크기 결정
    .measureSzie { size in
        viewSize = size                                       // 그 크기를 다시 viewSize에
    }
```

여기서는 `frame`이 크기를 고정해 버려 측정값이 곧 지정값과 같아지고, `Equatable` 비교 덕분에 두 번째부터는 콜백이 멈춰 안정된다. 하지만 `frame`을 빼고 내용에 따라 크기가 변하게 두면 "측정 → 상태 변경 → 레이아웃 → 재측정"이 계속 돌 수 있다. **측정 대상과 크기 반영 대상을 분리**하는 것이 안전한 설계다.

**2. `reduce` 구현을 형제 개수에 맞게 쓴다**

앞서 말한 대로 `value = nextValue()`는 단일 소스 전제다.

**3. 레이아웃에 영향을 주지 않는 자리에서 측정한다**

`background`/`overlay` 안에서 `Color.clear`와 함께 쓰는 관용구를 지킨다. 본문에 `GeometryReader`를 직접 넣으면 레이아웃이 망가진다.

**4. 값이 자주 바뀌면 비용이 든다**

스크롤 중에는 매 프레임 값이 올라올 수 있다. Apple이 `onGeometryChange` 문서에서 경고하는 것과 같은 맥락이다. 자세한 내용은 [GeometryReader와 성능](./geometry-reader-performance.md)에 정리했다.

**5. 최신 API를 먼저 검토한다**

크기 측정만이 목적이라면 iOS 16의 `onGeometryChange(for:of:action:)`나 `containerRelativeFrame`, `visualEffect`가 더 단순하고 저렴하다. `PreferenceKey`는 **여러 자식의 값을 모아 조상에서 합쳐야 할 때** 진가가 나온다.

### `PreferenceKey`가 실제로 빛나는 경우

- 커스텀 탭바에서 **각 탭의 위치**를 모아 인디케이터를 정확히 옮길 때
- 스크롤 중 **현재 화면에 보이는 섹션 헤더**를 판별할 때
- 여러 행의 라벨 폭을 재서 **가장 넓은 값에 전부 맞출** 때
- 자식 뷰가 조상 컨테이너에 **제목·툴바 항목 같은 설정을 등록**할 때 (SwiftUI의 `navigationTitle`도 같은 원리다)

좌표까지 다뤄야 하면 `Anchor`와 `anchorPreference`/`overlayPreferenceValue` 조합으로 확장된다.

## 학습 체크리스트

- [ ] `defaultValue`를 `.zero`가 아닌 값으로 바꿔 첫 프레임에 어떤 값이 오는지 확인한다.
- [ ] `reduce`에 `print`를 넣어 몇 번, 어떤 순서로 불리는지 관찰한다.
- [ ] `Color.clear` 대신 `Color.red`로 바꿔 측정용 뷰가 실제로 그려지는 자리를 눈으로 확인한다.
- [ ] 형제 뷰 두 개가 각각 `preference`를 올리게 만들고 `value = nextValue()`가 값을 잃는 것을 확인한다.
- [ ] 같은 상황에서 `reduce`를 `max(...)`나 배열 누적으로 바꿔 결과가 달라지는 것을 확인한다.
- [ ] `onPreferenceChange`의 `action`에 `print`를 넣어 같은 값일 때 호출되지 않음을 확인한다 (`Equatable`).
- [ ] `Value`를 `Equatable`이 아닌 타입으로 만들어 `onPreferenceChange`가 컴파일되지 않는 것을 확인한다.
- [ ] `.frame(width:height:)`를 제거하고 측정→반영 순환이 생기는지 관찰한다.
- [ ] `preference(key:)`에서 `key:` 인자를 생략해도 컴파일되는지 시험한다 (기본값 `K.self`).
- [ ] 같은 기능을 `onGeometryChange(for: CGSize.self)`로 다시 구현하고 코드 양을 비교한다.
- [ ] `Value`를 `[CGRect]`로 바꿔 여러 자식의 프레임을 모두 수집하는 키를 직접 만들어 본다.

## 공식 참고 자료

- [Apple: PreferenceKey](https://developer.apple.com/documentation/swiftui/preferencekey)
- [Apple: PreferenceKey.defaultValue](https://developer.apple.com/documentation/swiftui/preferencekey/defaultvalue)
- [Apple: PreferenceKey.reduce(value:nextValue:)](https://developer.apple.com/documentation/swiftui/preferencekey/reduce(value:nextvalue:))
- [Apple: PreferenceKey.Value](https://developer.apple.com/documentation/swiftui/preferencekey/value)
- [Apple: view.preference(key:value:)](https://developer.apple.com/documentation/swiftui/view/preference(key:value:))
- [Apple: view.onPreferenceChange(_:perform:)](https://developer.apple.com/documentation/swiftui/view/onpreferencechange(_:perform:))
- [Apple: view.onGeometryChange(for:of:action:)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))
- [Apple: Anchor](https://developer.apple.com/documentation/swiftui/anchor)
- [Apple: GeometryProxy](https://developer.apple.com/documentation/swiftui/geometryproxy)
