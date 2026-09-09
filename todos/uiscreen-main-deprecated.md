# `UIScreen.main`이 deprecated된 이유와 대안

`UI` 접두사와 UIKit 연동은 [별도 문서](./uiviewrepresentable-and-uikit-bridge.md)에, `GeometryReader`는 [여기](./geometry-reader-use-cases.md)에 정리했다. 이 문서는 **화면 크기를 얻는 최신 방법**을 다룬다.

## 질문이 나온 코드

`chapter-94/chapter-94/ViewModels/TimerViewModel.swift`

```swift
@Published var timerViewOffset: CGFloat = UIScreen.main.bounds.height
```

```
'main' was deprecated in iOS 26.0: Use a UIScreen instance found through context
instead (i.e, view.window.windowScene.screen), or for properties like UIScreen.scale
with trait equivalents, use a traitCollection found through context.
```

## 공부할 내용

### 왜 deprecated 됐나 — "화면이 하나"라는 전제가 깨졌다

Apple 문서의 설명이다.

> The screen object for the device.
>
> **Apple discourages the use of this symbol.** Use a `UIScreen` instance found through context instead. For example, reference the screen that displays a view through the `screen` property on the window scene managing the window containing the view.

**`UIScreen.main`은 "기기에 화면이 하나뿐"이라는 가정에 기댄 API**다. iPhone 초기에는 맞는 전제였지만 지금은 그렇지 않다.

**화면이 여러 개가 되는 상황들**

| 상황 | 문제 |
| --- | --- |
| **iPad Split View / Slide Over** | 앱이 화면 일부만 차지한다 |
| **Stage Manager** (iPadOS 16+) | 창 크기를 자유롭게 조절 |
| **외부 디스플레이 연결** | 어느 화면이 "main"인가 |
| **Mac Catalyst** | 창 기반 — 화면 전체와 무관 |
| **CarPlay** | 별도 화면 |
| **visionOS** | 물리 화면 개념 자체가 다르다 |

**핵심 문제는 이것이다.** iPad에서 Split View로 앱이 화면 절반만 쓰고 있어도 `UIScreen.main.bounds.height`는 **화면 전체 높이**를 돌려준다. 앱이 실제로 차지하는 크기가 아니다.

이 예제에서는 타이머 뷰를 화면 아래로 밀어 두는 데 쓰인다.

```swift
@Published var timerViewOffset: CGFloat = UIScreen.main.bounds.height
```

**iPad Split View에서는 필요보다 훨씬 큰 오프셋이 되어 뷰가 예상과 다른 위치로 간다.**

### SwiftUI에서는 애초에 쓸 이유가 없다

**가장 중요한 결론이다.** SwiftUI는 크기 정보를 제공하는 자체 수단이 있다.

**① `GeometryReader` — 부모가 준 영역**

이 프로젝트가 이미 쓰고 있다.

```swift
GeometryReader { geo in
    // geo.size.height ← 이 뷰가 실제로 차지하는 높이
}
```

`HomeView`의 `body`가 `GeometryReader`로 감싸져 있고, `timerSlidingView(geo)`에 `geo`를 넘긴다. **그런데 오프셋 초기값만 `UIScreen.main`을 쓴다.** 일관성이 없는 부분이다.

[GeometryReader 문서](./geometry-reader-use-cases.md)에서 다룬 대로, 이것이 "부모가 준 공간"을 아는 표준 수단이다.

**② `containerRelativeFrame` — 컨테이너 대비 비율**

```swift
.containerRelativeFrame(.vertical) { height, _ in height }
```

안전 영역을 뺀 컨테이너 크기를 기준으로 한다. `GeometryReader`보다 가볍다.

**③ `onGeometryChange` — 변화만 관찰 (iOS 16+)**

```swift
.onGeometryChange(for: CGSize.self) { proxy in
    proxy.size
} action: { size in
    screenHeight = size.height
}
```

**④ `@Environment(\.horizontalSizeClass)` — 레이아웃 분기용**

정확한 픽셀 대신 compact/regular 구분이 필요하면 이쪽이 맞다. [`@Environment` 문서](./environment-property-wrapper.md) 참조.

### UIKit이 정말 필요하면 — 컨텍스트에서 찾는다

경고 메시지가 제시한 방법이다.

```
Use a UIScreen instance found through context instead (i.e, view.window.windowScene.screen)
```

**뷰 → 윈도우 → 윈도우 씬 → 화면** 경로로 따라간다.

```swift
// UIKit
if let screen = view.window?.windowScene?.screen {
    let height = screen.bounds.height
}
```

SwiftUI에서 같은 정보가 필요하면 `UIWindowScene`을 찾는다.

```swift
extension UIApplication {
    var currentWindowScene: UIWindowScene? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
```

**하지만 이 방법도 권장하지 않는다.** SwiftUI 뷰에서 UIKit 씬 계층을 뒤지는 것은 두 프레임워크의 경계를 흐린다. `GeometryReader`가 있으면 그것을 쓴다.

**`scale`이나 `traitCollection` 관련 정보**는 경고가 별도로 안내한다.

```
for properties like UIScreen.scale with trait equivalents,
use a traitCollection found through context
```

SwiftUI에서는 [`@Environment(\.displayScale)`](./environment-property-wrapper.md)이 대응한다.

```swift
@Environment(\.displayScale) private var displayScale
```

### 이 코드를 어떻게 고치나

**문제는 두 겹이다.** `UIScreen.main` 사용과, **화면 크기를 뷰모델이 아는 구조** 자체다.

**① 최소 수정 — 초기값을 큰 상수로**

```swift
@Published var timerViewOffset: CGFloat = 1000
```

"화면 밖으로 밀어 두기"가 목적이므로 정확한 화면 높이가 필요하지 않다. **충분히 큰 값이면 된다.** 단순하지만 마법 숫자가 생긴다.

**② 뷰가 크기를 알려 준다 — 권장**

```swift
@Observable
final class TimerViewModel {
    var timerViewOffset: CGFloat = 0
    var isTimerViewHidden = true       // 상태로 표현
}
```

```swift
// HomeView
GeometryReader { geo in
    // ...
    timerSlidingView(geo)
        .offset(y: viewModel.isTimerViewHidden ? geo.size.height : 0)
}
```

**오프셋 계산을 뷰로 옮기고 뷰모델은 "숨김 여부"만 갖는다.** 뷰모델이 화면 크기를 알 필요가 없어지고, [UIKit 의존도 사라진다](./state-wrapper-decision-guide.md).

**③ 뷰의 `@State`로 완전히 옮긴다**

애니메이션 오프셋은 순수한 뷰 관심사다.

```swift
struct HomeView: View {
    @State private var timerViewOffset: CGFloat = 0
    @State private var isTimerVisible = false
    // ...
}
```

**뷰모델에는 타이머 상태(`time`, `selectedTime`)만 남는다.** [상태 관리 문서](./state-wrapper-decision-guide.md)에서 다룬 "뷰 레이아웃 값은 뷰가 소유한다"는 원칙이다.

`resetView()`가 `timerViewOffset`을 되돌리는 부분도 함께 정리된다.

```swift
func resetView() {
    withAnimation {
        time = 0
        selectedTime = 0
        timerHeightChange = 0
        timerViewOffset = UIScreen.main.bounds.height    // ← 이 줄도 사라진다
        buttonAnimation = false
        leftTime = nil
    }
}
```

### 관련해서 알아 둘 것 — `UIScreen` 외의 deprecated 패턴

같은 이유로 권장되지 않는 것들이 있다.

| 구형 | 대안 |
| --- | --- |
| `UIScreen.main.bounds` | `GeometryReader`, `containerRelativeFrame` |
| `UIScreen.main.scale` | `@Environment(\.displayScale)` |
| `UIApplication.shared.windows.first` | `connectedScenes`에서 `UIWindowScene` 찾기 |
| `UIApplication.shared.keyWindow` | 같음 (iOS 13에서 deprecated) |
| `UIDevice.current.orientation` | `@Environment(\.verticalSizeClass)` 또는 `GeometryReader` |

**공통 원인은 "전역 싱글턴으로 환경을 조회한다"는 패턴**이다. 멀티 윈도우·멀티 씬 환경에서는 "전역"이 성립하지 않는다. Apple이 iOS 13(씬 도입) 이후 꾸준히 이 방향으로 정리해 왔다.

`chapter-65`의 `UIDevice.orientationDidChangeNotification` 예제도 같은 계열이다. 알림 자체는 유효하지만, SwiftUI에서는 `verticalSizeClass`나 `GeometryReader`로 회전을 감지하는 편이 낫다.

### 정리

```text
UIScreen.main이 deprecated된 이유
  "기기에 화면이 하나"라는 전제가 깨졌다
  iPad Split View / Stage Manager / 외부 디스플레이 / Mac Catalyst / visionOS

가장 큰 실질 문제
  iPad Split View에서 앱이 화면 절반만 써도 전체 높이를 돌려준다
  → 앱이 실제로 차지하는 크기가 아니다

SwiftUI에서는 애초에 쓸 이유가 없다
  GeometryReader              부모가 준 영역
  containerRelativeFrame      컨테이너 대비 비율
  onGeometryChange            변화만 관찰
  @Environment(\.displayScale) 배율
  @Environment(\.horizontalSizeClass) 레이아웃 분기

UIKit이 필요하면 컨텍스트에서 찾는다
  view.window?.windowScene?.screen

이 코드의 근본 개선
  화면 크기를 뷰모델이 아는 구조 자체가 문제
  오프셋 계산을 뷰로 옮기고 뷰모델은 "숨김 여부"만 갖는다
```

## 학습 체크리스트

- [ ] `UIScreen.main.bounds.height`를 출력하고 iPad Split View에서 값이 어떻게 나오는지 확인한다.
- [ ] 같은 상황에서 `GeometryReader`의 `geo.size.height`와 비교한다.
- [ ] iPad 시뮬레이터에서 Split View로 앱을 절반 크기로 만들고 타이머 뷰 위치를 관찰한다.
- [ ] `timerViewOffset` 초기값을 상수 `1000`으로 바꿔 동작이 같은지 확인한다.
- [ ] `isTimerViewHidden` 불리언으로 바꾸고 오프셋 계산을 뷰로 옮겨 본다.
- [ ] `timerViewOffset`을 뷰의 `@State`로 완전히 옮겨 본다.
- [ ] `resetView()`에서 `UIScreen.main` 참조가 사라지는지 확인한다.
- [ ] `@Environment(\.displayScale)`을 읽어 화면 배율을 확인한다.
- [ ] `containerRelativeFrame(.vertical)`로 같은 효과를 만들어 본다.
- [ ] `UIApplication.shared.connectedScenes`로 윈도우 씬을 찾아 본다.
- [ ] `TimerViewModel`에서 `import SwiftUI`(UIKit 의존)를 제거할 수 있는지 확인한다.

## 공식 참고 자료

- [Apple: UIScreen.main (deprecated)](https://developer.apple.com/documentation/uikit/uiscreen/main)
- [Apple: UIScreen](https://developer.apple.com/documentation/uikit/uiscreen)
- [Apple: UIWindowScene](https://developer.apple.com/documentation/uikit/uiwindowscene)
- [Apple: UIWindowScene.screen](https://developer.apple.com/documentation/uikit/uiwindowscene/screen)
- [Apple: UIApplication.connectedScenes](https://developer.apple.com/documentation/uikit/uiapplication/connectedscenes)
- [Apple: GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
- [Apple: view.containerRelativeFrame(_:alignment:)](https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:))
- [Apple: view.onGeometryChange(for:of:action:)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))
- [Apple: EnvironmentValues.displayScale](https://developer.apple.com/documentation/swiftui/environmentvalues/displayscale)
- [Apple: EnvironmentValues.horizontalSizeClass](https://developer.apple.com/documentation/swiftui/environmentvalues/horizontalsizeclass)
- [Apple: Adopting Stage Manager on iPad](https://developer.apple.com/documentation/uikit/adopting-stage-manager-on-ipad)
- [Apple: Scenes](https://developer.apple.com/documentation/uikit/scenes)
