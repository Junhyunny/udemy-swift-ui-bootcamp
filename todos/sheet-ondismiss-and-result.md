# `sheet`의 두 클로저 — `onDismiss`는 언제 실행되고 결과는 어떻게 받나

`presentationMode`와 `dismiss`의 비교는 [별도 문서](./presentation-mode-vs-dismiss.md)에 정리했다. 이 문서는 **`sheet`의 클로저와 결과 전달**을 다룬다.

## 질문이 나온 코드

`chapter-69/chapter-69/CartView.swift`

```swift
.sheet(isPresented: $isPresented) {
    cart.courses = []
} content: {
    CheckoutView(cart: cart)
}
```

## 공부할 내용

### 시그니처를 보면 답이 나온다

```swift
nonisolated func sheet<Content>(
    isPresented: Binding<Bool>,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content
) -> some View where Content : View
```

**클로저가 두 개**다.

| 파라미터 | 역할 | 실행 시점 |
| --- | --- | --- |
| `onDismiss` | 닫힌 뒤 처리 | **시트가 닫힐 때** |
| `content` | 시트 내용 | 시트를 그릴 때 |

### 질문 확인: 열릴 때인가 닫힐 때인가

**닫힐 때다.**

이 코드에서 trailing closure 문법 때문에 헷갈리기 쉽다.

```swift
.sheet(isPresented: $isPresented) {
    cart.courses = []              // ← 이게 onDismiss
} content: {
    CheckoutView(cart: cart)       // ← 이게 content
}
```

`onDismiss`가 `content`보다 **앞에** 선언되어 있으므로, 첫 번째 trailing closure가 `onDismiss`가 된다. 두 번째는 `content:` 라벨을 명시했다.

[클로저와 trailing closure 문법](./closures-and-view-builders.md)에서 다룬 multiple trailing closure 규칙이다. 첫 번째만 라벨을 생략할 수 있고 나머지는 라벨을 붙인다.

**혼동을 피하려면 라벨을 명시하는 편이 낫다.**

```swift
.sheet(isPresented: $isPresented, onDismiss: {
    cart.courses = []
}, content: {
    CheckoutView(cart: cart)
})
```

Apple 문서의 예제는 함수로 분리해 의도를 드러낸다.

```swift
.sheet(isPresented: $isShowingSheet,
       onDismiss: didDismiss) {
    // 시트 내용
}

func didDismiss() {
    // Handle the dismissing action.
}
```

### 이 코드에 실제 버그가 있다

**결제 성공 여부와 무관하게 장바구니가 비워진다.**

```swift
onDismiss: {
    cart.courses = []      // 무조건 실행된다
}
```

`onDismiss`는 **어떤 이유로 닫히든 실행된다.**

- 결제 완료 버튼을 눌러 닫힘 → 비운다 ✅ 의도대로
- 취소 버튼을 눌러 닫힘 → **비운다** ⚠️
- 아래로 스와이프해 닫힘 → **비운다** ⚠️
- 결제 실패 후 닫힘 → **비운다** ⚠️

사용자가 결제 화면을 열었다가 그냥 내려도 장바구니가 사라진다. 실제 앱이라면 심각한 문제다.

### 질문 확인: 성공 여부를 어떻게 전달받나

**질문의 짐작이 정확하다. 외부 상태로 전달해야 한다.**

`onDismiss`의 타입이 `(() -> Void)?`이므로 **파라미터도 반환값도 없다.** 시트에서 무슨 일이 있었는지 전달할 통로가 시그니처에 없다.

**방법 ① 별도 `@State`로 결과를 받는다 — 가장 단순**

```swift
struct CartView: View {
    @ObservedObject var cart: Cart
    @State private var isPresented = false
    @State private var didCheckout = false      // 결과를 담을 상태

    var body: some View {
        // ...
        .sheet(isPresented: $isPresented, onDismiss: {
            if didCheckout {                     // 성공했을 때만
                cart.courses = []
            }
            didCheckout = false                  // 다음을 위해 초기화
        }, content: {
            CheckoutView(cart: cart, didCheckout: $didCheckout)
        })
    }
}
```

```swift
struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var didCheckout: Bool

    var body: some View {
        Button("결제하기") {
            // 결제 처리...
            didCheckout = true       // 성공을 알린다
            dismiss()
        }
    }
}
```

[`@Binding`](./property-wrapper-dollar-sign.md)으로 시트가 부모의 상태를 쓰게 한다.

**방법 ② `onDismiss`를 쓰지 않고 시트 안에서 직접 처리**

```swift
struct CheckoutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cart: Cart

    var body: some View {
        Button("결제하기") {
            // 결제 처리...
            cart.courses = []        // 여기서 바로 비운다
            dismiss()
        }
    }
}
```

`cart`가 참조 타입이므로 시트 안에서 바꿔도 부모에 반영된다. **가장 단순하고 의도가 명확하다.** `onDismiss` 자체가 필요 없어진다.

**방법 ③ `sheet(item:)`으로 결과 타입을 다룬다**

결과가 여러 갈래라면 `enum`으로 표현할 수 있다.

```swift
enum CheckoutResult {
    case success(orderID: String)
    case cancelled
    case failed(Error)
}

@State private var result: CheckoutResult?

.sheet(isPresented: $isPresented, onDismiss: {
    switch result {
    case .success:  cart.courses = []
    case .cancelled, .failed, .none: break
    }
    result = nil
}, content: {
    CheckoutView(cart: cart, result: $result)
})
```

**방법 ④ 클로저를 콜백으로 전달**

```swift
CheckoutView(cart: cart) { success in
    if success { cart.courses = [] }
}
```

시트 뷰가 완료 콜백을 받는 형태다. [`@escaping` 클로저](./closures-and-view-builders.md)와 같은 패턴이다.

**어느 것을 고르나**

| 상황 | 방법 |
| --- | --- |
| 결과가 성공/실패 두 갈래 | ① `@State` + `@Binding` |
| 공유 객체를 시트가 직접 수정 | ② 시트 안에서 처리 — **가장 단순** |
| 결과가 여러 종류 | ③ `enum` 결과 타입 |
| 시트가 재사용 컴포넌트 | ④ 콜백 클로저 |

**이 프로젝트에는 ②가 가장 적합하다.** `cart`가 이미 `CheckoutView`에 전달되고 있으므로, 결제 성공 시 그 안에서 비우면 된다.

### `onDismiss`가 실제로 유용한 경우

**시트가 닫힌 뒤에만 할 수 있는 일**이 있을 때다.

```swift
.sheet(isPresented: $isPresented, onDismiss: {
    // 데이터 다시 불러오기
    Task { await reload() }
}, content: {
    EditView()
})
```

- 목록 새로고침
- 다음 화면 전환 (시트와 겹치면 안 되므로 닫힌 뒤에)
- 분석 이벤트 기록
- 임시 상태 정리

**시트가 열릴 때 실행할 곳은 따로 없다.** `content` 안의 뷰에서 `.onAppear`나 [`.task`](./task-modifier-and-async-lifecycle.md)를 쓴다.

```swift
content: {
    CheckoutView(cart: cart)
        .onAppear { /* 열릴 때 */ }
}
```

### `content` 클로저의 평가 시점

주의할 점이 하나 있다. **`content` 클로저는 시트가 표시될 때 평가되지만, 그 시점의 상태를 캡처한다.**

```swift
@State private var selectedItem: Item?

.sheet(isPresented: $isPresented) {
    DetailView(item: selectedItem)     // ⚠️ nil일 수 있다
}
```

`isPresented`를 `true`로 만드는 것과 `selectedItem`을 설정하는 순서에 따라 문제가 생길 수 있다. **`sheet(item:)`이 이 문제를 해결한다.**

```swift
@State private var selectedItem: Item?

.sheet(item: $selectedItem) { item in
    DetailView(item: item)             // item이 보장된다
}
```

`item`이 `nil`이 아니게 되면 자동으로 열리고, `nil`이 되면 닫힌다. `isPresented` 불리언을 따로 둘 필요가 없다.

### 관련 modifier들

| modifier | 용도 |
| --- | --- |
| `sheet(isPresented:onDismiss:content:)` | 불리언으로 제어 |
| `sheet(item:onDismiss:content:)` | 옵셔널 값으로 제어 |
| `fullScreenCover(isPresented:...)` | 전체 화면 |
| `popover(isPresented:...)` | 팝오버 (iPad/Mac) |
| `alert(_:isPresented:)` | 경고 |
| `confirmationDialog(_:isPresented:)` | 액션 시트 |

**세로가 좁은 환경에서는 시트가 자동으로 전체 화면이 된다.**

> In vertically compact environments, such as iPhone in landscape orientation, a sheet presentation automatically adapts to appear as a full-screen cover.

### 정리

```text
sheet(isPresented:onDismiss:content:)
  onDismiss  시트가 닫힐 때        ← 첫 번째 trailing closure
  content    시트 내용

onDismiss는 파라미터가 없다
  → 결과를 받으려면 외부 상태를 써야 한다  ✅ 짐작이 맞다

이 코드의 문제
  결제 성공/취소를 구분하지 않고 무조건 장바구니를 비운다

해결
  ① @State + @Binding으로 결과 전달
  ② 시트 안에서 직접 처리 (cart가 참조 타입) ← 이 경우 가장 단순
  ③ enum 결과 타입
  ④ 콜백 클로저

열릴 때 실행하려면 content 안에서 onAppear / .task
```

## 학습 체크리스트

- [ ] `onDismiss`에 `print("닫힘")`을 넣어 언제 실행되는지 확인한다.
- [ ] 시트를 아래로 스와이프해 닫아도 `onDismiss`가 실행되는지 확인한다.
- [ ] 결제하지 않고 취소해도 장바구니가 비워지는 버그를 재현한다.
- [ ] `@State didCheckout` + `@Binding`으로 성공 여부를 전달해 본다.
- [ ] `CheckoutView` 안에서 `cart.courses = []`를 직접 실행하도록 바꿔 본다.
- [ ] `onDismiss`와 `content`의 라벨을 명시적으로 써서 가독성을 비교한다.
- [ ] `content` 안의 뷰에 `.onAppear`를 넣어 열릴 때 실행되는지 확인한다.
- [ ] `onDismiss`를 생략하고 `sheet(isPresented:content:)`만 써 본다.
- [ ] `sheet(item:)` 방식으로 바꿔 옵셔널 값으로 제어해 본다.
- [ ] `enum CheckoutResult`를 만들어 여러 결과를 구분해 본다.
- [ ] `fullScreenCover`로 바꿔 차이를 확인한다.
- [ ] iPhone 가로 모드에서 시트가 전체 화면이 되는 것을 확인한다.
- [ ] 시트 안에서 `dismiss()`를 호출하고 `onDismiss`가 뒤이어 실행되는 순서를 확인한다.

## 공식 참고 자료

- [Apple: view.sheet(isPresented:onDismiss:content:)](https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:))
- [Apple: view.sheet(item:onDismiss:content:)](https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:))
- [Apple: view.fullScreenCover(isPresented:onDismiss:content:)](https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:))
- [Apple: view.popover(isPresented:attachmentAnchor:arrowEdge:content:)](https://developer.apple.com/documentation/swiftui/view/popover(ispresented:attachmentanchor:arrowedge:content:))
- [Apple: Modal presentations](https://developer.apple.com/documentation/swiftui/modal-presentations)
- [Apple: EnvironmentValues.dismiss](https://developer.apple.com/documentation/swiftui/environmentvalues/dismiss)
- [Apple: Binding](https://developer.apple.com/documentation/swiftui/binding)
- [Apple: view.presentationDetents(_:)](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))
- [Swift 공식 문서: Closures — Trailing Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/#Trailing-Closures)
