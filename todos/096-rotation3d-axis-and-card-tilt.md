# `rotation3DEffect`의 회전축과 카드 기울이기

## 질문이 나온 코드

`chapter-42/chapter-42/ContentView.swift`는 드래그 방향으로 카드가 기울어 보이도록 회전축을 계산한다.

```swift
.rotation3DEffect(
    .degrees(isDragging ? 10 : 0),
    axis: (
        x: -valueTranslation.height,
        y: valueTranslation.width,
        z: 0
    )
)
```

## 공부할 내용

### 실제 3D 모델을 만드는 기능은 아니다

Apple은 `rotation3DEffect`가 지정 축을 중심으로 3차원 회전한 것처럼 뷰의 콘텐츠를 렌더링한다고 설명한다. 기존의 2D 뷰를 회전시킨 뒤 원래 뷰 평면에 투영해 입체감이 생기는 **그래픽 효과**다. 모델의 꼭짓점이나 메시를 만드는 3D 모델링 API는 아니다.

또한 이 modifier는 표시 결과를 바꾸지만 뷰의 레이아웃 frame은 바꾸지 않는다. 회전한 모서리가 주변 뷰의 배치를 다시 밀어내지는 않는다.

### `axis`는 회전의 중심선 방향이다

`axis: (x:y:z:)`는 3차원 공간에서 회전축이 향하는 방향을 나타내는 벡터다. 카드를 가운데에 놓고 축 하나씩 시험하면 이해하기 쉽다.

| 축 | 값 | 보이는 동작 |
| --- | --- | --- |
| x축 | `(1, 0, 0)` | 카드의 가로 중심선을 축으로 위·아래가 앞뒤로 기운다. |
| y축 | `(0, 1, 0)` | 카드의 세로 중심선을 축으로 왼쪽·오른쪽이 앞뒤로 기운다. |
| z축 | `(0, 0, 1)` | 화면에 수직인 축을 중심으로 평면에서 돈다. |
| 대각선축 | `(1, 1, 0)` | 카드 평면의 대각선 방향을 축으로 기운다. |

`axis`는 회전량이 아니라 **방향**이고 실제 회전량은 첫 번째 `Angle` 인자가 정한다. 축 벡터는 `(1, 0, 0)` 같은 단위값으로 시작하면 의도가 가장 분명하다. 여러 성분을 쓸 때는 성분의 상대적인 비율이 축의 방향을 정한다고 생각하면 된다.

회전의 중심 위치는 별도 인자인 `anchor`가 정한다. 기본값은 `.center`다. 예를 들어 `axis: (0, 1, 0), anchor: .leading`은 카드의 왼쪽 가장자리를 경첩처럼 보이게 할 수 있다. `perspective`는 가까운 쪽은 크게, 먼 쪽은 작게 보이는 소실점 효과의 강도를 조절한다.

### 현재 코드가 드래그 값을 교차해서 넣는 이유

화면에서 드래그 벡터를 `(dx, dy)`라고 하면 현재 회전축은 `(-dy, dx, 0)`이다. 이는 2D에서 드래그 방향에 수직인 벡터다.

- 오른쪽으로 드래그하면 `dx > 0`이므로 y축 회전이 생긴다.
- 아래로 드래그하면 `dy > 0`이므로 음의 x축 회전이 생긴다.
- 대각선으로 드래그하면 x축과 y축이 섞인 대각선 축으로 회전한다.

카드를 어떤 방향으로 기울이려면 그 이동 방향 자체가 아니라 그 방향에 수직인 선을 경첩처럼 회전축으로 삼아야 한다. 그래서 width는 y 성분으로, height는 부호를 바꿔 x 성분으로 교차한다.

현재 코드는 드래그 중 회전 각도를 항상 10도로 고정하고 축 방향만 바꾼다. 드래그 거리에 따라 기울기도 바꾸고 싶다면 축은 방향용으로 정규화하고, 거리를 제한된 각도로 변환하는 편이 이해하기 쉽다.

### 축별 동작을 확인하는 가장 작은 예제

```swift
struct AxisRotationDemo: View {
    @State private var angle = 0.0

    var body: some View {
        VStack(spacing: 32) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.blue.gradient)
                .frame(width: 220, height: 140)
                .overlay { Text("CARD").foregroundStyle(.white) }
                .rotation3DEffect(
                    .degrees(angle),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 1
                )

            Slider(value: $angle, in: -60...60)
        }
        .padding()
    }
}
```

먼저 `axis`를 `(1, 0, 0)`, `(0, 1, 0)`, `(0, 0, 1)`로 하나씩 바꿔 본다. 그 다음 `anchor`를 `.center`, `.leading`, `.top`으로 바꾸면 **축의 방향**과 **축이 통과하는 위치**가 서로 다른 개념임을 확인할 수 있다.

### 더 복잡한 3D 회전으로 넘어갈 때

튜플 기반 API는 애니메이션 중 각도와 축의 각 성분을 따로 보간한다. Apple은 자연스러운 3D 회전 보간이 필요하면 `Rotation3D` 값을 받는 overload를 고려하라고 안내한다. 단순한 카드 tilt에는 현재 API가 충분하지만, 여러 회전을 이어 붙이거나 3D 모델을 자연스럽게 보간할 때는 `Rotation3D`, `RotationAxis3D`, quaternion 개념이 다음 학습 단계다.

## 학습 체크리스트

- [ ] 최소 예제에서 x, y, z축을 하나씩 적용하고 각 움직임을 말로 설명한다.
- [ ] 같은 y축 회전에서 `anchor`를 `.center`와 `.leading`으로 바꿔 경첩 위치를 비교한다.
- [ ] `perspective` 값을 바꾸며 원근감이 어떻게 달라지는지 확인한다.
- [ ] 오른쪽·아래·대각선 드래그 때 `(-dy, dx, 0)`가 어떤 축이 되는지 계산한다.
- [ ] `rotation3DEffect`가 레이아웃 frame을 바꾸지 않는지 `border`로 확인한다.
- [ ] 고정 10도 대신 드래그 거리를 `0...15`도로 제한해 매핑하는 실험을 한다.
- [ ] 2D 뷰의 3D 투영 효과와 실제 3D 모델링의 차이를 설명한다.

## 공식 참고 자료

- [Apple: View.rotation3DEffect(_:axis:anchor:anchorZ:perspective:)](https://developer.apple.com/documentation/swiftui/view/rotation3deffect(_:axis:anchor:anchorz:perspective:))
- [Apple: View.rotation3DEffect(_:axis:anchor:)](https://developer.apple.com/documentation/swiftui/view/rotation3deffect(_:axis:anchor:)-4kzwf)
- [Apple: Rotation3D](https://developer.apple.com/documentation/spatial/rotation3d)
- [Apple: RotationAxis3D](https://developer.apple.com/documentation/spatial/rotationaxis3d)
- [Apple: Graphics and rendering modifiers](https://developer.apple.com/documentation/swiftui/view-graphics-and-rendering)
- [Apple: Core Animation basics](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/CoreAnimationBasics/CoreAnimationBasics.html)
