# 프리뷰의 파란 테두리와 Image 크기 조절 modifier

## 질문이 나온 코드

`chapter-16/chapter-16/ContentView.swift`의 `#Preview` 블록과, `Image(.photo1)`에 붙은 `resizable`, `aspectRatio`, `scaledToFit`, `frame`, `clipped`

## 공부할 내용

### 파란 창은 "선택한 view의 layout 경계"다

Xcode preview에서 selectable(마우스 아이콘) 모드로 요소를 클릭하면 나타나는 파란 사각형은 **그 view가 layout 상 차지하는 영역**을 표시한 것이다. Apple 문서가 이 기능을 그대로 설명한다.

> "Using Xcode previews, you can quickly see the size of a specific view element by selecting the view or child view in the editor. ... With the `Image` selected, you'll see a blue border around the view in the Xcode preview"

즉 디버깅용 시각화이지 코드에 영향을 주는 요소가 아니다. 선택한 대상이 바뀌면 테두리도 그 view의 경계로 바뀌므로, **modifier를 하나 붙일 때마다 경계가 어떻게 변하는지**를 눈으로 추적하는 도구로 쓰면 된다.

한 번에 하나만 볼 수 있다는 한계가 있어서, 여러 view의 경계를 동시에 보려면 임시로 `border(_:)`를 붙이는 방법을 Apple이 함께 권한다. 이때 Xcode가 그리는 파란색과 헷갈리지 않도록 **파란색이 아닌 색**을 쓰라고 명시한다.

```swift
Image(.photo1)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: 300, height: 300)
    .border(.red)          // layout frame을 항상 보이게
```

### 파란 테두리와 실제로 그려진 그림은 다를 수 있다 — 이것이 `clipped()`와의 연결고리

여기가 질문의 핵심이다. **frame은 layout에만 쓰이고, 그 밖으로 넘친 내용도 그대로 화면에 그려진다.**

> "By default, a view's bounding frame is used only for layout, so any content that extends beyond the edges of the frame is still visible."

그래서 파란 테두리(= layout 경계)는 300 × 300인데 사진은 그 밖까지 삐져나와 보이는 상황이 생긴다. 테두리와 보이는 그림이 어긋나 보이는 이유가 바로 이것이고, `clipped(antialiased:)`는 그 넘친 부분을 잘라내서 둘을 일치시킨다.

### 각 modifier의 역할

- **`resizable(capInsets:resizingMode:)`** — "Sets the mode by which SwiftUI resizes an image to fit its space." `Image`는 기본적으로 원본 크기를 고집한다. 이걸 붙여야 비로소 주어진 공간에 맞춰 크기가 변한다. **`resizable()`이 없으면 뒤에 `frame`을 붙여도 그림 자체는 줄지 않는다.** `resizingMode`는 늘려서 채우는 `.stretch`(기본)와 원본 크기로 반복해 채우는 `.tile`이 있다.
- **`aspectRatio(_:contentMode:)`** — "Constrains this view's dimensions to the specified aspect ratio." 비율을 `nil`로 두면 원본 비율을 유지한다.
- **`ContentMode.fit`** — "resizes the content so it's all within the available space, both vertically and horizontally." 비율을 유지하며 **전부 들어가게** 맞추므로, 비율이 다르면 한 축은 공간에 딱 맞고 다른 축에는 **빈 공간이 남는다.**
- **`ContentMode.fill`** — "resizes the content so it occupies all available space." 비율을 유지하며 **빈틈없이 채우므로**, 비율이 다르면 한 축은 딱 맞고 다른 축은 **공간보다 커진다(넘친다).**
- **`scaledToFit()` / `scaledToFill()`** — 각각 `aspectRatio(nil, contentMode: .fit)` / `.fill`과 **동등하다.** 즉 `aspectRatio`의 축약형이지 별개 기능이 아니다.
- **`frame(width:height:alignment:)`** — "Positions this view within an invisible frame with the specified size." 보이지 않는 상자를 만들어 그 안에 배치한다. 한쪽만 지정하면 나머지 축은 원래 크기 동작을 따른다.
- **`clipped(antialiased:)`** — layout 경계 밖으로 나간 내용을 잘라낸다.

### 지금 코드에서 벌어지는 일

```swift
Image(.photo1)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: 300, height: 300)
```

`photo-1.jpg`는 6048 × 8064, 즉 3:4의 세로 사진이다. `.fill`은 300 × 300 정사각형을 빈틈없이 채우려 하므로 **짧은 축인 가로를 300에 맞추고**, 그 결과 세로는 400이 되어 위아래로 넘친다. `frame`이 잡은 layout 경계는 300 × 300이므로 파란 테두리는 정사각형으로 보이지만, 실제 그림은 세로로 삐져나온다. 주석 처리된 `.clipped()`를 살리면 넘친 부분이 잘려 테두리와 그림이 일치한다.

`.scaledToFit()`으로 바꾸면 반대로 **긴 축인 세로를 300에 맞추므로** 가로는 225가 되고, 300 × 300 안에 좌우 여백이 생긴다. 넘치는 부분이 없으니 `.clipped()`도 의미가 없어진다.

### modifier는 순서가 결과를 바꾼다

SwiftUI에서 modifier는 원본 view를 감싸는 새 view를 만든다. 따라서 `aspectRatio` → `frame` 순서와 `frame` → `aspectRatio` 순서는 서로 다른 결과를 낸다. 마찬가지로 `clipped()`를 `frame` 앞에 붙이면 자를 기준이 되는 경계가 달라진다. 파란 테두리로 각 단계의 경계를 확인하면 이 차이를 눈으로 볼 수 있다.

## 학습 체크리스트

- [ ] preview를 selectable 모드로 두고 `Image`, `VStack`을 번갈아 선택해 파란 테두리가 어떻게 달라지는지 본다.
- [ ] `.border(.red)`를 `frame` 앞과 뒤에 각각 붙여 layout 경계가 어디에 잡히는지 비교한다.
- [ ] `.resizable()`만 지우고 나머지는 그대로 두었을 때 그림 크기가 왜 안 변하는지 설명한다.
- [ ] `.aspectRatio(contentMode: .fill)`과 `.scaledToFit()`을 번갈아 적용해 여백이 생기는 쪽과 넘치는 쪽을 확인한다.
- [ ] `.clipped()`를 켜고 끄면서 파란 테두리와 실제 그림이 일치하는지 비교한다.
- [ ] `.frame(width: 300, height: 300)`과 `.aspectRatio(...)`의 순서를 바꿔 결과가 달라지는 것을 확인한다.
- [ ] 같은 이미지를 `.fit` / `.fill` / `resizable 없음` 세 가지로 나란히 놓고 `border`로 경계를 표시한 비교 예제 view를 만든다.
- [ ] `.resizingMode: .tile`을 적용해 `.stretch`와 어떻게 다른지 확인한다.

## 참고 자료

- [Apple: Inspecting view layout (프리뷰의 파란 테두리)](https://developer.apple.com/documentation/swiftui/inspecting-view-layout)
- [Apple: Previews in Xcode](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
- [Apple: Image.resizable(capInsets:resizingMode:)](https://developer.apple.com/documentation/swiftui/image/resizable(capinsets:resizingmode:))
- [Apple: Image.ResizingMode](https://developer.apple.com/documentation/swiftui/image/resizingmode)
- [Apple: View.aspectRatio(_:contentMode:)](https://developer.apple.com/documentation/swiftui/view/aspectratio(_:contentmode:))
- [Apple: ContentMode](https://developer.apple.com/documentation/swiftui/contentmode)
- [Apple: View.scaledToFit()](https://developer.apple.com/documentation/swiftui/view/scaledtofit())
- [Apple: View.scaledToFill()](https://developer.apple.com/documentation/swiftui/view/scaledtofill())
- [Apple: View.frame(width:height:alignment:)](https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:))
- [Apple: View.clipped(antialiased:)](https://developer.apple.com/documentation/swiftui/view/clipped(antialiased:))
