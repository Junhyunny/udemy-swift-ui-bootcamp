# `scrollPosition(id:)` — 무엇이 `currentIndex`를 바꾸고 있는가

## 질문이 나온 코드

`chapter-146/chapter-146/Views/OnboardingView.swift`

```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) {
        ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
            OnboardingStepView(step: step, screenSize: viewModel.screenSize)
                .containerRelativeFrame(.horizontal)
                .id(index)
        }
    }
    .scrollTargetLayout()
}
.scrollPosition(id: $viewModel.currentIndex)
.scrollTargetBehavior(.paging)
.onScrollTargetVisibilityChange(idType: Int.self) { visibleIds in
    // 아래 코드를 지웠는데도 슬라이딩 전환이 잘 된다
    //   if let lastVisibleId = visibleIds.last {
    //       viewModel.updateCurrentIndex(lastVisibleId)
    //   }
}
```

질문은 두 가지다.

1. 지금 스크롤 슬라이딩에서 **무엇이 `currentIndex`를 바꾸고 있는가**
2. `scrollPosition`이 위치 변화에 맞춰 **상태를 자동으로 바인딩하고 있는 것인가**

## 공부할 내용

### 결론 먼저

**2번의 답은 "그렇다"이다.** `currentIndex`를 바꾸는 주체는 `.scrollPosition(id: $viewModel.currentIndex)`다. 이 modifier는 **양방향**으로 동작한다.

```text
손가락으로 스크롤   →  SwiftUI가 binding에 새 id를 써 넣는다   (읽기 방향)
binding에 값을 쓴다 →  SwiftUI가 그 id의 뷰로 스크롤한다       (쓰기 방향)
```

공식 문서의 첫 문장이 그대로 이 얘기다.

> Associates a binding to be updated when a scroll view within this view scrolls.
> As the scroll view scrolls, the binding will be updated with the identity of the leading-most / top-most view.

그래서 `onScrollTargetVisibilityChange`에서 수동으로 `updateCurrentIndex`를 호출하던 코드는 **같은 일을 두 번째로 하고 있었고**, 지워야 정상이 된 것이다.

### 읽기 방향 — 스크롤하면 binding이 갱신된다

SwiftUI가 "지금 몇 번째 페이지인가"를 알아내려면 세 가지가 맞아떨어져야 한다.

| 필요한 것 | 이 코드에서 | 역할 |
|---|---|---|
| 후보 뷰들을 담은 레이아웃 표시 | `.scrollTargetLayout()` | "이 레이아웃의 직속 자식들이 스크롤 대상이다" |
| 각 자식의 identity | `.id(index)` | 각 페이지를 `Int` 값으로 식별 |
| 결과를 받을 바인딩 | `.scrollPosition(id: $viewModel.currentIndex)` | 여기에 id가 써진다 |

`.scrollTargetLayout()`이 빠지면 SwiftUI는 어떤 뷰를 후보로 봐야 할지 모르고, binding은 갱신되지 않는다. 공식 문서가 명시한 전제 조건이다.

> Use this modifier along with the `scrollTargetLayout(isEnabled:)` modifier to know the identity of the view that is actively scrolled.

여기서 `.id(index)`가 `Int`이므로 binding도 `Int?`여야 한다. 뷰모델의 선언이 `Int?`인 이유가 이것이다.

```swift
var currentIndex: Int? = 0
```

시그니처를 보면 옵셔널이 선택이 아니라 **요구사항**임을 알 수 있다.

```swift
nonisolated func scrollPosition(
    id: Binding<(some Hashable)?>,
    anchor: UnitPoint? = nil
) -> some View
```

`Binding<(some Hashable)?>` — 감싼 타입이 **옵셔널**이다. 스크롤 위치가 어떤 대상에도 해당하지 않는 상태(초기 레이아웃 전, 대상 사이에 걸친 상태)를 `nil`로 표현해야 하기 때문이다. [`Identifiable` 프로토콜 문서](./identifiable-protocol.md), [`Hashable`과 id 문서](./hashable-id-and-collisions.md)와 이어진다.

### 쓰기 방향 — binding에 쓰면 스크롤이 움직인다

같은 문서가 반대 방향도 설명한다.

> You can write to the binding to scroll to the view with the provided identity.

그래서 "Next" 버튼이 동작한다.

```swift
func navigateToNext() {
    // ...
    withAnimation(.easeInOut(duration: 0.3)) {
        currentIndex = nextIndex     // ← 이 대입이 곧 "스크롤 명령"이다
    }
}
```

`ScrollViewProxy.scrollTo(_:)` 같은 걸 부르지 않는데도 화면이 넘어가는 이유가 여기 있다. `withAnimation`으로 감쌌기 때문에 그 이동이 애니메이션으로 처리된다. [암시적·명시적 애니메이션 문서](./implicit-vs-explicit-animation.md)와 이어진다.

문서는 **사용자가 스크롤하지 않았는데도** SwiftUI가 binding이 가리키는 뷰를 계속 보이게 유지한다고도 말한다.

- 스크롤 뷰의 데이터 순서가 바뀔 때
- 스크롤 뷰 크기가 바뀔 때(창 크기 변경, 기기 회전)
- 최초 레이아웃 시 binding이 첫 뷰가 아닌 다른 id를 가리킬 때

이 코드에서 기기를 회전해도 현재 페이지가 유지되는 것이 세 번째·두 번째 항목 덕분이다.

### `$viewModel.currentIndex`는 어떻게 `Binding<Int?>`가 되나

바인딩이 두 단계를 거친다.

```text
@State private var viewModel: OnboardingViewModel
        ↓  $ (projectedValue)
Binding<OnboardingViewModel>
        ↓  .currentIndex  (dynamicMemberLookup)
Binding<Int?>
```

`Binding`은 `@dynamicMemberLookup`이라서 `$viewModel.currentIndex`처럼 **속성 하나를 콕 집은 바인딩**을 만들어 준다. 여기에 쓰면 실제로는 `viewModel.currentIndex`가 바뀌고, `@Observable`이 그 변화를 감지해 `bottomNavigationView`의 페이지 인디케이터까지 다시 그린다.

`@State`·`$`·`_`의 관계는 [`@State`와 `_viewModel` 문서](./state-property-wrapper-backing-storage.md)에, dynamic member lookup 쪽은 [`subscript` 문서](./subscript-keyword.md)에 정리되어 있다.

### 지운 코드가 왜 문제였나

```swift
.onScrollTargetVisibilityChange(idType: Int.self) { visibleIds in
    if let lastVisibleId = visibleIds.last {
        viewModel.updateCurrentIndex(lastVisibleId)
    }
}
```

두 가지가 겹쳐 있었다.

**① 되먹임 고리(feedback loop)를 만든다**

```text
손가락 스크롤
   ↓
onScrollTargetVisibilityChange 콜백 (기본 threshold 0.5)
   ↓
viewModel.currentIndex = lastVisibleId
   ↓
scrollPosition이 이걸 "쓰기"로 해석 → "그 뷰로 스크롤해라"
   ↓
진행 중인 제스처·paging 애니메이션과 충돌
   ↓
버벅임 / 엉뚱한 페이지로 되돌아감
```

`scrollPosition`은 **읽기 전용 관측점이 아니라 양방향 통로**다. 사용자가 스크롤하는 중에 그 바인딩에 값을 쓰면, SwiftUI 입장에서는 "프로그램이 스크롤을 명령했다"와 구분되지 않는다. **하나의 상태에 주인이 둘이 된 상황**이다.

**② 고르는 기준이 반대다**

`scrollPosition`은 **leading-most(가장 앞쪽)** 뷰를 고른다. 반면 `visibleIds.last`는 **가장 뒤쪽** id다. 두 페이지가 동시에 걸쳐 보이는 순간 두 값이 서로 달라, 위 고리가 더 자주 튀었다.

`onScrollTargetVisibilityChange`의 원래 용도는 이런 쪽이다.

> Use this modifier ... to be informed when the views in the targetted scroll view have crossed the provided threshold to be considered on/off screen.
>
> ```swift
> .onScrollTargetVisibilityChange(for: Model.ID.self, threshold: 0.2) { onScreenCards in
>     // Disable video playback for cards that are offscreen...
> }
> ```

즉 **"화면 밖으로 나간 항목의 비디오를 멈춘다"** 같은 부수적 처리용이지, 현재 페이지를 결정하는 용도가 아니다.

### 역할 분담 정리

| modifier | 방향 | 알려 주는 것 | 이 화면에서 쓸 곳 |
|---|---|---|---|
| `.scrollPosition(id:)` | 양방향 | leading-most 뷰의 id **하나** | **현재 페이지** (단일 진실 공급원) |
| `.onScrollTargetVisibilityChange(idType:)` | 읽기 | 임계값을 넘긴 **여러** id | 화면 밖 항목 정리, 프리페치 |
| `.scrollTargetBehavior(.paging)` | — | 한 페이지 단위로 멈추게 함 | 스냅 동작 |
| `.scrollTargetLayout()` | — | 스크롤 대상 후보 지정 | 위 두 개의 전제 조건 |

원칙 하나로 줄이면 이렇다. **`currentIndex`의 주인은 `scrollPosition` 하나여야 한다.**

### `anchor` 파라미터

어느 뷰를 "현재"로 볼지, 프로그램으로 스크롤할 때 어디에 맞출지를 함께 정한다.

```swift
.scrollPosition(id: $viewModel.currentIndex, anchor: .leading)
```

> For example, providing a value of `bottom` will prefer to have the bottom-most view chosen and prefer to scroll to views aligned to the bottom.
>
> If no anchor has been provided, SwiftUI will scroll the minimal amount when using the scroll position to programmatically scroll to a view.

지금 코드는 `anchor`를 생략했고 `.paging` + `containerRelativeFrame(.horizontal)`로 한 페이지가 화면을 꽉 채우므로 기본값으로 충분하다. 페이지가 화면보다 작다면 `anchor`를 명시해야 의도대로 붙는다.

### 버전 — 무엇이 언제 생겼나

| API | iOS |
|---|---|
| `scrollPosition(id:anchor:)` | 17.0 |
| `scrollTargetLayout(isEnabled:)` | 17.0 |
| `scrollTargetBehavior(_:)` | 17.0 |
| `onScrollTargetVisibilityChange(idType:threshold:_:)` | **18.0** |
| `ScrollPosition` 타입 + `scrollPosition(_:anchor:)` | **18.0** |

iOS 18부터는 id 하나 대신 `ScrollPosition` 값 타입을 쓰는 방식이 생겼다. 오프셋·가장자리 등 id 말고 다른 기준으로도 위치를 지정할 수 있다.

```swift
@State private var position = ScrollPosition(idType: Int.self)

ScrollView(.horizontal) { /* ... */ }
    .scrollPosition($position)

// 쓰기
position.scrollTo(id: 2)
position.scrollTo(edge: .leading)
```

`scrollPosition(id:)`는 deprecated가 아니므로 지금 코드를 바꿀 이유는 없다. 다만 **`onScrollTargetVisibilityChange`를 쓰는 순간 배포 타깃이 iOS 18 이상**이 된다는 점은 알고 있어야 한다. [Swift·iOS 버전 호환성 문서](./swift-ios-device-compatibility.md)와 이어진다.

### 직접 확인하는 방법

바인딩이 정말 자동으로 갱신되는지 눈으로 보려면 콜백 대신 `onChange`를 쓴다.

```swift
.onChange(of: viewModel.currentIndex) { oldValue, newValue in
    print("currentIndex: \(String(describing: oldValue)) → \(String(describing: newValue))")
}
```

`onChange`는 **관측만 하고 바인딩에 쓰지 않으므로** 되먹임 고리를 만들지 않는다. 손가락으로 넘길 때와 버튼을 누를 때 모두 값이 찍히는 것을 볼 수 있다. [`onChange`의 `oldValue`·`newValue` 문서](./onchange-old-new-value.md)를 참고한다.

### 이 코드에 적용하면

```text
손가락 스와이프
   ↓ .paging 이 한 페이지 단위로 스냅
   ↓ .scrollTargetLayout() 의 자식 중 leading-most 를 고름
   ↓ 그 뷰의 .id(index) 값을
   ↓ .scrollPosition(id:) 이 $viewModel.currentIndex 에 써 넣음
   ↓ @Observable 이 변경을 전파
   ↓ AnimatedPageIndicator 와 OnboardingNavigationButton 이 다시 그려짐

"Next" 버튼
   ↓ viewModel.navigateToNext()
   ↓ withAnimation { currentIndex = nextIndex }
   ↓ .scrollPosition(id:) 이 이를 스크롤 명령으로 해석
   ↓ 해당 페이지로 애니메이션 이동
```

두 경로가 **같은 하나의 상태(`currentIndex`)**를 공유한다. `onScrollTargetVisibilityChange` 안의 코드를 지운 것은 이 구조에 맞는 올바른 정리였다.

## 체크리스트

- [ ] `.scrollPosition(id:)`가 읽기·쓰기 양방향임을 각각 코드로 확인한다.
- [ ] `.scrollTargetLayout()`을 지우고 `currentIndex`가 갱신되는지 확인한다.
- [ ] `.id(index)`를 지우고 어떤 일이 생기는지 확인한다.
- [ ] `currentIndex`를 `Int?`에서 `Int`로 바꿔 보고 컴파일 오류를 읽는다.
- [ ] `.onChange(of: viewModel.currentIndex)`로 손가락 스크롤과 버튼 누름 둘 다에서 값이 바뀌는지 로그로 본다.
- [ ] 지웠던 `updateCurrentIndex` 호출을 되살려 버벅임을 재현하고, 왜 생기는지 되먹임 고리로 설명한다.
- [ ] `visibleIds.last` 대신 `visibleIds.first`로 바꿔 보고 차이를 관찰한다.
- [ ] `anchor: .leading`과 `anchor: .center`를 각각 넣고 동작 차이를 확인한다.
- [ ] iOS 18의 `ScrollPosition` 타입으로 같은 화면을 다시 구현해 본다.
- [ ] `onScrollTargetVisibilityChange`를 원래 용도(화면 밖 항목 처리)로 쓰는 예를 하나 만들어 본다.

## 공식 참고 자료

- [SwiftUI: scrollPosition(id:anchor:)](https://developer.apple.com/documentation/swiftui/view/scrollposition(id:anchor:))
- [SwiftUI: scrollTargetLayout(isEnabled:)](https://developer.apple.com/documentation/swiftui/view/scrolltargetlayout(isenabled:))
- [SwiftUI: scrollTargetBehavior(_:)](https://developer.apple.com/documentation/swiftui/view/scrolltargetbehavior(_:))
- [SwiftUI: ScrollTargetBehavior](https://developer.apple.com/documentation/swiftui/scrolltargetbehavior)
- [SwiftUI: onScrollTargetVisibilityChange(idType:threshold:_:)](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:))
- [SwiftUI: scrollPosition(_:anchor:)](https://developer.apple.com/documentation/swiftui/view/scrollposition(_:anchor:))
- [SwiftUI: ScrollPosition](https://developer.apple.com/documentation/swiftui/scrollposition)
- [SwiftUI: containerRelativeFrame(_:alignment:)](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:))
- [SwiftUI: Binding](https://developer.apple.com/documentation/swiftui/binding)
- [WWDC23: Beyond scroll views](https://developer.apple.com/videos/play/wwdc2023/10159/)
