# `presentationMode`와 `dismiss` — 무엇이 다르고 어느 쪽을 쓰나

`@Environment` 전반과 `\.dismiss`의 용법은 [별도 문서](./environment-property-wrapper.md)에 정리했다. 이 문서는 **두 API의 비교**를 다룬다.

## 질문이 나온 코드

`chapter-69/chapter-69/CourseDetailView.swift`

```swift
@Environment(\.presentationMode) var presentationMode
```

## 공부할 내용

### 결론 먼저

- **`presentationMode`는 구형 API다.** `\.dismiss`가 그것을 대체한다.
- 하는 일은 **거의 같다.** 화면을 닫는다.
- 차이는 **사용 편의성과 표현력**이다. `presentationMode`는 `Binding`을 거쳐야 해서 번거롭다.
- **iOS 27.0에서 deprecated 됐다.** 새 코드에는 `\.dismiss`를 쓴다.

### 버전 이력

| API | 도입 | 상태 |
| --- | --- | --- |
| `\.presentationMode` | iOS 13.0 | **iOS 27.0에서 deprecated** |
| `PresentationMode` 타입 | iOS 13.0 | **iOS 27.0에서 deprecated** |
| `\.dismiss` | **iOS 15.0** | 현행 |
| `\.isPresented` | iOS 15.0 | 현행 |

SwiftUI 첫 버전부터 있던 API이고, iOS 15에서 더 나은 대체제가 나왔다. [`NavigationView` → `NavigationStack` 전환](./navigation-stack-vs-navigation-view.md)과 비슷한 흐름이다.

### `presentationMode`는 어떻게 쓰나

타입이 특이하다.

```swift
var presentationMode: Binding<PresentationMode> { get }
```

**`Binding`으로 감싸져 있다.** 그래서 실제로 쓸 때 `wrappedValue`를 거쳐야 한다.

```swift
@Environment(\.presentationMode) var presentationMode

Button("닫기") {
    presentationMode.wrappedValue.dismiss()
    //               ↑ 이게 번거롭다
}
```

`PresentationMode` 타입이 제공하는 것은 둘이다.

| 멤버 | 용도 |
| --- | --- |
| `dismiss()` | 화면을 닫는다 |
| `isPresented` | 현재 표시 중인지 |

```swift
if presentationMode.wrappedValue.isPresented {
    // 표시 중일 때만
}
```

### `\.dismiss`는 어떻게 쓰나

```swift
@Environment(\.dismiss) private var dismiss

Button("닫기") {
    dismiss()          // 바로 호출
}
```

**`wrappedValue`가 사라진다.** 타입이 `DismissAction`이고 `Binding`이 아니기 때문이다.

`dismiss()`처럼 변수를 함수로 호출할 수 있는 것은 `callAsFunction` 덕분이다. [`@Environment` 문서](./environment-property-wrapper.md)에서 다룬 `openURL`과 같은 방식이다.

`isPresented`는 별도 환경 값으로 분리됐다.

```swift
@Environment(\.isPresented) private var isPresented
```

### 두 API 비교

| | `presentationMode` | `dismiss` |
| --- | --- | --- |
| 타입 | `Binding<PresentationMode>` | `DismissAction` |
| 호출 | `presentationMode.wrappedValue.dismiss()` | **`dismiss()`** |
| 표시 여부 확인 | `.wrappedValue.isPresented` | `\.isPresented` (별도) |
| 시트 닫기 | ✅ | ✅ |
| 네비게이션 pop | ✅ | ✅ |
| `NavigationSplitView` 대응 | ❌ | ✅ (iOS 18+) |
| 상태 | **deprecated** | 현행 |

**기능 자체는 거의 같다.** `dismiss`가 나중에 나온 만큼 새 컨테이너에 대한 대응이 추가됐고, 무엇보다 **쓰기가 간단하다.**

`DismissAction` 문서가 용도를 명시한다.

> You can use this action to:
> - Dismiss a modal presentation, like a sheet or a popover.
> - Pop the current view from a `NavigationStack`.
>
> On apps targeting iOS 18 and aligned releases, you also use the dismiss action to pop the implicit stack of a collapsed `NavigationSplitView`, or clear the equivalent state in an expanded split view.

### 왜 `presentationMode`는 `Binding`이었나

역사적 이유가 있다. iOS 13 시절에는 **환경 값을 통해 양방향으로 소통하는 수단**이 `Binding`밖에 없었다. "닫아라"라는 동작과 "닫혔는가"라는 상태를 한 타입에 담다 보니 `Binding<PresentationMode>`라는 어색한 형태가 됐다.

iOS 15에서 **동작(action)과 상태를 분리**하면서 정리됐다.

```text
presentationMode  =  dismiss() + isPresented  (한 덩어리)
        ↓
\.dismiss      동작만
\.isPresented  상태만
```

[`@Environment`의 Actions 범주](./environment-property-wrapper.md)가 이때 정착한 패턴이다. `openURL`, `refresh`, `openWindow`도 같은 형태다.

### 이 코드는 어떻게 바꾸나

```swift
// 현재
@Environment(\.presentationMode) var presentationMode
// ...
presentationMode.wrappedValue.dismiss()
```

```swift
// 권장
@Environment(\.dismiss) private var dismiss
// ...
dismiss()
```

**`private`을 붙이는 것도 관례다.** 환경 값은 이 뷰 내부에서만 쓰는 것이므로 외부에 노출할 이유가 없다.

배포 타겟이 iOS 15 이상이면 바로 바꿀 수 있다. [버전 확인 방법](./swift-ios-device-compatibility.md)은 별도 문서에 정리했다.

### 공통으로 주의할 점

두 API 모두 **선언한 위치의 환경을 기준으로 동작한다.**

```swift
struct DetailView: View {
    @State private var isSheetPresented = false
    @Environment(\.dismiss) private var dismiss   // DetailView의 환경

    var body: some View {
        Button("시트 열기") { isSheetPresented = true }
        .sheet(isPresented: $isSheetPresented) {
            Button("닫기") {
                dismiss()      // ⚠️ 시트가 닫히지 않는다
            }
        }
    }
}
```

**닫으려는 뷰 안에서 선언해야 한다.** [`@Environment` 문서](./environment-property-wrapper.md)에서 Apple 문서를 인용해 자세히 다뤘다.

이 프로젝트의 `CourseDetailView`는 자기 안에서 선언하므로 올바르다.

### 언제 `dismiss`를 쓰고 언제 `path`를 쓰나

`NavigationStack`에서 뒤로 가는 방법이 둘이다.

| | `dismiss()` | `path.removeLast()` |
| --- | --- | --- |
| 어디서 | **밀려 올라간 화면 안에서** | path를 소유한 뷰에서 |
| 몇 단계 | 한 단계 | 원하는 만큼 |
| 재사용 컴포넌트 | **적합** | 부적합 |

`CourseDetailView`처럼 여러 곳에서 재사용될 수 있는 화면은 **자기가 어떤 스택에 올라와 있는지 몰라도 되는** `dismiss()`가 맞다. [NavigationPath 문서](./navigation-path-and-typed-array.md)에서 비교했다.

### 참고 — 이 프로젝트의 다른 구형 API

`CourseHome.swift`에도 같은 세대의 코드가 있다.

```swift
NavigationView {          // iOS 16에서 deprecated
    List(Course.sample) { course in
        ZStack {
            NavigationLink(destination: CourseDetailView(...)) {
                EmptyView()
            }.opacity(0)
            CourseCardView(course: course)
        }
    }
}
```

- `NavigationView` → `NavigationStack` ([관련 문서](./navigation-stack-vs-navigation-view.md))
- `ZStack` + 투명 `NavigationLink` 패턴 → 라벨에 직접 넣기 ([히트 테스트 문서](./swiftui-hit-testing-vs-dom-events.md))

`CartView.swift`의 `@ObservedObject`도 [`@Observable`](./observation-framework-and-observable.md)로 옮길 수 있는 구형 API다.

**강의 예제를 따라가는 중이라면 그대로 두어도 무방하다.** 다만 실무 코드라면 함께 정리하는 것이 좋다.

### 정리

```text
presentationMode  iOS 13, iOS 27에서 deprecated
  Binding<PresentationMode>
  presentationMode.wrappedValue.dismiss()   ← 장황하다

dismiss           iOS 15, 현행
  DismissAction
  dismiss()                                  ← 간단하다

기능은 거의 같다. 차이는 편의성과 새 컨테이너 대응.

공통 주의: 닫으려는 뷰 안에서 선언해야 한다.
```

## 학습 체크리스트

- [ ] `presentationMode.wrappedValue.dismiss()`를 실제로 호출해 화면이 닫히는지 확인한다.
- [ ] `@Environment(\.dismiss)`로 바꾸고 `dismiss()`만으로 동작하는지 확인한다.
- [ ] `wrappedValue`를 빼고 `presentationMode.dismiss()`를 시도해 에러를 확인한다.
- [ ] `presentationMode`의 타입을 Quick Help로 확인한다 (`Binding<PresentationMode>`).
- [ ] `\.dismiss`의 타입이 `DismissAction`인 것을 확인한다.
- [ ] `presentationMode.wrappedValue.isPresented`와 `\.isPresented`를 비교한다.
- [ ] 부모 뷰에서 `dismiss`를 선언하고 시트가 닫히지 않는 함정을 재현한다.
- [ ] `CourseDetailView`에서 `dismiss()`가 네비게이션 pop으로 동작하는지 확인한다.
- [ ] 같은 뷰를 시트로 띄웠을 때도 `dismiss()`가 동작하는지 확인한다.
- [ ] `@Environment` 앞에 `private`을 붙여 본다.
- [ ] `NavigationView`를 `NavigationStack`으로 바꾸고 `dismiss()`가 여전히 동작하는지 확인한다.
- [ ] 배포 타겟을 iOS 14로 낮추고 `\.dismiss`가 에러가 되는지 확인한다.

## 공식 참고 자료

- [Apple: EnvironmentValues.dismiss](https://developer.apple.com/documentation/swiftui/environmentvalues/dismiss)
- [Apple: DismissAction](https://developer.apple.com/documentation/swiftui/dismissaction)
- [Apple: EnvironmentValues.presentationMode (deprecated)](https://developer.apple.com/documentation/swiftui/environmentvalues/presentationmode)
- [Apple: PresentationMode (deprecated)](https://developer.apple.com/documentation/swiftui/presentationmode)
- [Apple: EnvironmentValues.isPresented](https://developer.apple.com/documentation/swiftui/environmentvalues/ispresented)
- [Apple: EnvironmentValues.dismissWindow](https://developer.apple.com/documentation/swiftui/environmentvalues/dismisswindow)
- [Apple: Environment](https://developer.apple.com/documentation/swiftui/environment)
- [Apple: Binding](https://developer.apple.com/documentation/swiftui/binding)
- [Apple: Modal presentations](https://developer.apple.com/documentation/swiftui/modal-presentations)
