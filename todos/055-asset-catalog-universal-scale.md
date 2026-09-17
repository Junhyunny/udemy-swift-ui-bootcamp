# Asset catalog의 "Universal"과 배율 슬롯의 의미

## 질문이 나온 코드

`chapter-16/chapter-16/ContentView.swift`의 `Image(.photo1)`과 `chapter-16/chapter-16/Assets.xcassets/photo1.imageset/`

## 공부할 내용

### image set은 "이미지 한 장"이 아니라 "한 이미지의 변형 모음"이다

Asset catalog에서 image set 하나는 **런타임에 불러올 이미지 하나**를 나타낸다. 그 안에는 기기 특성별 변형(variation)이 여러 개 들어간다. 코드에서 이름으로 참조하면 시스템이 **현재 기기 특성에 맞는 변형을 골라서** 표시한다.

> "An asset set contains one or more variations of that resource for different device characteristics, for example, platform, screen size, resolution, appearance, and language. When you refer to a resource in code, the system determines the appropriate variation to display at runtime based on the characteristics of the current device."

에디터에 보이는 박스 하나하나가 그 변형을 넣는 자리(**well**)이고, 박스 위에 붙은 글자는 그 자리가 담당하는 기기 특성을 설명하는 label이다.

### "Universal"은 배율이 아니라 기기 종류(idiom)를 뜻한다

`Universal`은 **idiom** 값이다. idiom은 이미지가 어떤 device family를 위한 것인지를 지정하고, `universal`은 "The image works on any device and platform" 즉 **기기를 가리지 않고 쓴다**는 뜻이다. 태그를 아예 넣지 않아도 `universal`과 같게 취급된다.

idiom에는 `universal` 외에 `iphone`, `ipad`, `mac`, `tv`, `watch` 등이 있다. Attributes inspector의 Devices에서 특정 기기를 체크하면 `iPhone`, `iPad` 같은 label이 붙은 **줄이 추가로** 생기고, 그 기기에서만 쓸 이미지를 따로 넣을 수 있다. 지금은 Universal 한 줄만 있으므로 모든 기기가 같은 이미지를 쓴다.

### 1x / 2x / 3x는 화면 배율(display scale)이다

한 줄 안의 박스 세 개는 **targeted display scale**을 뜻한다.

| 슬롯 | 의미 |
| --- | --- |
| `1x` | Targeted for unscaled displays |
| `2x` | Targeted for Retina displays |
| `3x` | Targeted for Retina displays with higher density |

SwiftUI의 `frame(width: 300, height: 300)` 같은 수치는 pixel이 아니라 **point** 단위다. 배율은 1 point를 실제 몇 pixel로 그리는지를 정한다. 즉 2x 기기에서 300 point는 600 pixel, 3x 기기에서는 900 pixel이다. 배율 슬롯이 나뉘어 있는 이유는 **같은 point 크기를 각 기기에서 선명하게 그리려면 서로 다른 pixel 크기의 원본이 필요하기** 때문이다.

Xcode는 image set을 만들 때 기본으로 @1x, @2x, @3x well을 만들어 둔다. 파일명이 `@2x`나 `@3x`로 끝나면 해당 배율 자리에 자동으로 들어간다.

> "By default, Xcode creates each image set with wells for @1x, @2x, and @3x resolutions. If the filename of the image you import ends in `@2x` or `@3x`, Xcode automatically places the image into the well with the corresponding resolution."

### 지금 프로젝트의 상태를 직접 확인해 보자

`photo1.imageset/Contents.json`을 열면 UI에서 본 박스들이 그대로 데이터로 적혀 있다.

```json
{
  "images" : [
    { "filename" : "photo-1.jpg", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ]
}
```

`photo-1.jpg`가 **1x 자리에만** 들어가 있고 2x·3x는 `filename`이 없는 빈 자리다. 그런데 원본 `photo-1.jpg`는 실제로 6048 × 8064 pixel이다. 1x 슬롯에 넣었으므로 시스템은 이 이미지를 **6048 × 8064 point짜리 이미지**로 해석한다. 배율별로 나눠 준비한 이미지가 아니라 큰 원본 한 장을 1x 자리에 넣은 상태이고, 화면에는 `frame`으로 줄여서 표시하고 있는 것이다.

학습용으로는 문제없지만, 실제 앱이라면 (1) 표시할 point 크기를 정하고 (2) 그 크기의 1x/2x/3x 이미지를 각각 만들어 자리에 맞게 넣는 것이 원래 방식이다. 그렇게 하면 1x 기기는 작은 파일만 내려받아 쓰고 3x 기기만 큰 파일을 쓴다.

### 배율을 나누지 않는 경우

`scale` 태그가 없는 항목은 "any display scale"을 뜻하며 해상도에 독립적인 이미지(`.pdf` 같은 vector)를 가리킨다. Attributes inspector에서 배율 구성을 바꾸면 이렇게 슬롯 하나만 쓰는 형태로도 만들 수 있다.

## 학습 체크리스트

- [ ] `photo1.imageset/Contents.json`을 열어 에디터의 박스 배치와 JSON의 `idiom`·`scale` 항목이 어떻게 대응되는지 확인한다.
- [ ] Attributes inspector에서 Devices에 iPhone / iPad를 추가해 보고 `Contents.json`에 어떤 항목이 늘어나는지 본다.
- [ ] 크기가 다른 이미지를 각각 1x·2x·3x 자리에 넣고 시뮬레이터를 2x 기기와 3x 기기로 바꿔가며 어느 것이 쓰이는지 확인한다.
- [ ] `photo-1.jpg`를 2x 자리로 옮겼을 때 화면에 보이는 크기가 어떻게 달라지는지 설명한다.
- [ ] 파일명을 `photo-1@3x.jpg`로 바꿔 다시 import하면 Xcode가 어느 자리에 넣는지 확인한다.
- [ ] point와 pixel의 차이를 설명하고, 3x 기기에서 `frame(width: 300)`이 몇 pixel인지 계산한다.

## 참고 자료

- [Apple: Adding images to your Xcode project](https://developer.apple.com/documentation/xcode/adding-images-to-your-xcode-project)
- [Apple: Managing assets with asset catalogs](https://developer.apple.com/documentation/xcode/managing-assets-with-asset-catalogs)
- [Apple: Asset Catalog Format Reference — Image Set Type (idiom, scale 키)](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/ImageSetType.html)
- [Apple: Asset Catalog Format Reference — Contents.json File](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/Contents.html)
- [Apple HIG: Images](https://developer.apple.com/design/human-interface-guidelines/images)
