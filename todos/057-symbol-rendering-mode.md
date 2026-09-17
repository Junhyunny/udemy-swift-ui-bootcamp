# SF Symbol rendering mode의 종류와 차이

## 질문이 나온 코드

`chapter-14/chapter-14/ContentView.swift`의 `Image(systemName: "square.and.arrow.up.badge.checkmark")`에 적용한 `.symbolRenderingMode(.palette)`와 `.foregroundStyle(.indigo, .mint)`

## 공부할 내용

### rendering mode를 결정하는 것은 layer와 style의 대응 방식

SF Symbol은 하나의 그림이 아니라 여러 **layer**로 나뉘어 있다. `SymbolRenderingMode`는 그 layer들에 foreground style을 **어떻게 나눠 칠할지**를 정한다. 네 가지 모드의 차이는 "몇 개의 색을 쓰는가"가 아니라 "layer와 style을 어떻게 대응시키는가"에 있다.

- **`.monochrome`** — 모든 layer를 하나로 합쳐 foreground style 하나로 칠한다. Apple 설명은 "renders symbols as a single layer filled with the foreground style". SF Symbols의 typographic한 성격에 가장 가깝고 가장 중립적이다.
- **`.hierarchical`** — layer를 유지하되 **같은 색의 opacity를 단계별로** 적용한다. 첫 layer는 primary style, 나머지는 secondary·tertiary variant로 칠해진다. 색상(hue)은 하나로 유지하면서 깊이와 강조를 준다.
- **`.palette`** — layer마다 **서로 다른 style**을 매핑한다. 정의된 layer 순서대로 primary → secondary → tertiary foreground style이 적용된다. style을 하나만 주면 SwiftUI가 나머지를 그 style에서 파생시킨다.
- **`.multicolor`** — symbol이 **자체적으로 가진 고유 색**(inherent style)으로 칠한다. 예를 들어 `exclamationmark.triangle.fill`은 삼각형이 노랑, 느낌표가 흰색으로 나온다. 개발자가 색을 지정하는 것이 아니라 symbol에 내장된 색을 쓰는 것이므로, 고유 색이 없는 symbol에서는 monochrome과 구분이 안 된다.

### 명시하지 않으면 자동으로 결정된다

`EnvironmentValues.symbolRenderingMode`의 기본값은 `nil`이고, 이는 "the mode is picked automatically using the current image and foreground style as parameters"를 뜻한다. 즉 mode를 지정하지 않으면 SwiftUI가 **symbol과 foreground style을 보고 알아서 고른다**.

그 자동 판정의 대표적인 규칙이 `foregroundStyle(_:_:)` 문서에 명시되어 있다. style을 두 개 이상 넘기면 다른 mode를 명시하지 않는 한 palette가 적용된다.

```swift
// 아래 둘은 같은 결과다
Image(systemName: "exclamationmark.triangle.fill")
    .symbolRenderingMode(.palette)
    .foregroundStyle(Color.yellow, Color.cyan)

Image(systemName: "exclamationmark.triangle.fill")
    .foregroundStyle(Color.yellow, Color.cyan)   // 다중 style → palette로 암시적 전환
```

현재 chapter-14 코드의 `.symbolRenderingMode(.palette)`는 이 규칙상 생략해도 동작이 같다. 의도를 드러내기 위해 남겨두는 것은 선택의 문제다.

### mode와 foregroundStyle은 짝으로 이해해야 한다

같은 `.foregroundStyle(Color.purple)`이라도 mode에 따라 결과가 달라진다.

| mode | `.foregroundStyle(.purple)` 하나만 준 경우 |
| --- | --- |
| `.monochrome` | 전체가 보라색 단색 |
| `.hierarchical` | 보라색 + 자동 파생된 낮은 opacity 보라색들 |
| `.palette` | 보라색 + 보라색에서 파생된 secondary·tertiary style |
| `.multicolor` | symbol 고유 색 사용 (foreground style이 무시될 수 있음) |

`.hierarchical`과 `.palette`가 헷갈리기 쉬운데, style을 **하나만** 줬을 때는 둘 다 "파생"이라 결과가 비슷해 보인다. 차이는 style을 **여러 개** 줬을 때 드러난다. palette는 각 layer에 서로 다른 색을 그대로 매핑하고, hierarchical은 어디까지나 하나의 hue를 opacity로 나눈다.

### iOS 26에 추가된 색 채우기 방식 (`SymbolColorRenderingMode`)

Xcode 26 / iOS 26부터 rendering mode와는 **별개 축**으로 layer를 채우는 방식을 고를 수 있다.

- `.flat` — layer를 단색으로 채운다.
- `.gradient` — layer를 axial gradient로 채운다. 단일 색에서 자동으로 부드러운 gradient를 만들어 입체감을 준다.

`.symbolColorRenderingMode(_:)` modifier로 적용하며, 네 가지 rendering mode 어디에나 조합할 수 있다. 현재 프로젝트는 iOS 26 기준(Xcode 26)이므로 사용 가능하다.

## 학습 체크리스트

- [ ] 같은 symbol에 네 가지 mode를 나란히 배치한 `VStack`을 만들어 눈으로 차이를 비교한다.
- [ ] `.hierarchical`과 `.palette`에 `foregroundStyle`을 각각 1개 / 2개 / 3개 넘겨보고 어느 조합에서 두 mode의 결과가 갈리는지 확인한다.
- [ ] `.symbolRenderingMode(.palette)` 줄을 지우고 `.foregroundStyle(.indigo, .mint)`만 남겼을 때 결과가 같은지 확인한다.
- [ ] `.multicolor`를 고유 색이 있는 symbol(`exclamationmark.triangle.fill`)과 없는 symbol에 각각 적용해 차이를 확인한다.
- [ ] SF Symbols 앱에서 현재 쓰는 `square.and.arrow.up.badge.checkmark`가 layer를 몇 개 가지는지, 각 mode 미리보기가 어떻게 나오는지 본다.
- [ ] `.symbolColorRenderingMode(.gradient)`를 붙여 `.flat`과 비교한다.

## 참고 자료

- [Apple: SymbolRenderingMode](https://developer.apple.com/documentation/swiftui/symbolrenderingmode)
- [Apple: SymbolRenderingMode.monochrome](https://developer.apple.com/documentation/swiftui/symbolrenderingmode/monochrome)
- [Apple: SymbolRenderingMode.hierarchical](https://developer.apple.com/documentation/swiftui/symbolrenderingmode/hierarchical)
- [Apple: SymbolRenderingMode.palette](https://developer.apple.com/documentation/swiftui/symbolrenderingmode/palette)
- [Apple: SymbolRenderingMode.multicolor](https://developer.apple.com/documentation/swiftui/symbolrenderingmode/multicolor)
- [Apple: View.symbolRenderingMode(_:)](https://developer.apple.com/documentation/swiftui/view/symbolrenderingmode(_:))
- [Apple: EnvironmentValues.symbolRenderingMode](https://developer.apple.com/documentation/swiftui/environmentvalues/symbolrenderingmode)
- [Apple: View.foregroundStyle(_:_:)](https://developer.apple.com/documentation/swiftui/view/foregroundstyle(_:_:))
- [Apple: SymbolColorRenderingMode](https://developer.apple.com/documentation/swiftui/symbolcolorrenderingmode)
- [Apple: View.symbolColorRenderingMode(_:)](https://developer.apple.com/documentation/swiftui/view/symbolcolorrenderingmode(_:))
- [Apple HIG: SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
- [WWDC21: SF Symbols in SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10349/)
