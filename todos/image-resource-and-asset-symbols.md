# `ImageResource`는 언제 등장했고, 그전에는 어떻게 했나

asset catalog의 구조와 배율 슬롯은 [별도 문서](./asset-catalog-universal-scale.md)에 정리했다. 이 문서는 **코드에서 이미지를 가리키는 방법**의 변천을 다룬다.

## 질문이 나온 코드

`chapter-56/chapter-56/ContentView.swift`

```swift
let photoCollection: [ImageResource] = [
    .pic1, .pic2, .pic3, .pic4, .pic5, .pic6,
]
```

```swift
Image(imageResource)
```

## 공부할 내용

### 먼저 두 가지 정정

**① `class`가 아니라 `struct`다.**

```swift
struct ImageResource
```

값 타입이다. 복사되며 참조 카운팅 대상이 아니다. [struct와 class](./struct-vs-class.md)의 구분이 그대로 적용된다.

**② "Swift 15"는 없다.** Swift는 현재 6.x대이고 15 버전은 존재하지 않는다. 혼동하기 쉬운데, `ImageResource`를 만들어 낸 것은 **Xcode 15**다.

정확한 도입 시점은 이렇다.

| 항목 | 값 |
| --- | --- |
| 도입 도구 | **Xcode 15** (2023) |
| 소속 프레임워크 | `DeveloperToolsSupport` |
| 최소 배포 타겟 | **iOS 17.0**, macOS 14.0, watchOS 10.0, tvOS 17.0 |
| 타입 | `struct` |

**Swift 언어 버전이 아니라 Xcode 버전과 SDK 버전의 문제**라는 점이 핵심이다. Swift 문법이 바뀐 것이 아니라, Xcode가 **빌드 시점에 코드를 생성**해 주는 기능이 추가된 것이다.

### 무엇이 생성되는가 — asset symbol generation

Xcode 15부터 asset catalog를 빌드하면 그 안의 각 asset에 대응하는 **Swift 심볼이 자동 생성**된다.

```text
Assets.xcassets/
├── pic1.imageset/   →  ImageResource.pic1
├── pic2.imageset/   →  ImageResource.pic2
└── AccentColor.colorset/ → ColorResource.accentColor
```

그래서 예제가 `.pic1`이라고만 써도 컴파일된다. `ImageResource` 타입의 정적 프로퍼티로 만들어져 있기 때문에 [타입 추론에 의한 축약](./static-type-properties-and-implicit-init.md)이 가능하다.

색상도 같이 생성된다. `ColorResource`가 그 짝이다.

### 그전에는 어떻게 했나

**① SwiftUI — 문자열로 지정**

```swift
Image("pic1")
Color("AccentColor")
```

가장 오래된 방식이고 지금도 동작한다.

**② UIKit — `UIImage(named:)`**

```swift
let image = UIImage(named: "pic1")     // UIImage? — 옵셔널이다
imageView.image = image
```

**③ 문자열 상수로 관리 (수동 대응책)**

문자열 직접 사용의 위험을 줄이려고 개발자들이 쓰던 방법이다.

```swift
enum AssetName {
    static let pic1 = "pic1"
    static let pic2 = "pic2"
}

Image(AssetName.pic1)
```

**④ SwiftGen 같은 코드 생성 도구**

써드파티 도구로 asset 이름을 훑어 타입 안전한 코드를 생성했다. `ImageResource`는 이 아이디어를 Xcode가 공식으로 흡수한 것이라고 볼 수 있다.

### 무엇이 좋아졌나 — 문자열의 문제

**오타를 컴파일러가 못 잡는다.**

```swift
Image("pic1")     // OK
Image("pci1")     // ⚠️ 컴파일 통과. 실행하면 빈 이미지
```

`Image(_:)`는 이름을 찾지 못해도 크래시하지 않고 **아무것도 그리지 않는다.** 그래서 화면이 비었는데 원인을 찾기 어렵다.

```swift
Image(.pic1)      // OK
Image(.pci1)      // ✅ 컴파일 에러 — 즉시 발견
```

**이름을 바꾸면 추적이 안 된다.** asset 이름을 `pic1`에서 `photo1`로 바꾸면 문자열은 조용히 깨지지만, 심볼은 컴파일 에러로 알려 준다.

**자동완성이 된다.** `Image(.` 까지 치면 사용 가능한 asset 목록이 뜬다.

**옵셔널 처리가 사라진다.** `UIImage(named:)`가 `UIImage?`를 돌려주던 것과 달리, 심볼은 존재가 보장되므로 옵셔널이 아니다.

### 어떻게 쓰나

`Image`의 이니셜라이저가 `ImageResource`를 직접 받는다.

```swift
Image(.pic1)                    // 축약형
Image(ImageResource.pic1)       // 전체 표기 — 같은 것
```

예제처럼 **변수에 담아 전달**할 수도 있다. 문자열이 아니라 타입이므로 배열로 다루기도 자연스럽다.

```swift
let photoCollection: [ImageResource] = [.pic1, .pic2, .pic3]

Image(imageResource)
```

이것이 `PhaseAnimator`의 phases로 넘어갈 수 있는 이유이기도 하다. `ImageResource`가 `Equatable`을 만족하므로 `where Phase : Equatable` 제약을 통과한다. [phase 타입 이야기](./phase-animator-parameters-and-phase-types.md) 참조.

UIKit에서도 쓸 수 있다.

```swift
let image = UIImage(resource: .pic1)    // 옵셔널이 아니다
```

직접 만들 수도 있다. 동적으로 이름을 정해야 할 때 쓴다.

```swift
init(name: String, bundle: Bundle)
```

```swift
let dynamic = ImageResource(name: "pic\(index)", bundle: .main)
Image(dynamic)
```

다만 이 경로는 문자열로 돌아가는 것이라 타입 안전성이 없다.

### 이름은 어떻게 변환되나

asset 이름이 Swift 식별자로 그대로 쓸 수 없는 경우 Xcode가 변환한다.

| asset 이름 | 생성되는 심볼 |
| --- | --- |
| `pic1` | `.pic1` |
| `AccentColor` | `.accentColor` (첫 글자 소문자화) |
| `my-image` | `.myImage` (camelCase 변환) |
| `2x-logo` | 숫자로 시작하면 백틱 처리 등 조정 |

폴더(namespace)를 쓰면 중첩 구조도 만들어진다.

```text
Assets.xcassets/
└── Photos/            ← "Provides Namespace" 체크
    └── pic1.imageset  →  ImageResource.Photos.pic1
```

### 언제 문자열 방식을 써야 하나

`ImageResource`가 항상 답은 아니다.

- **iOS 16 이하를 지원해야 할 때** — 배포 타겟이 낮으면 심볼을 쓸 수 없다
- **런타임에 이름이 정해질 때** — 서버가 내려준 이름으로 로컬 이미지를 찾는 경우
- **asset catalog 밖의 이미지** — 번들의 파일이나 다운로드한 이미지

```swift
// 원격 이미지는 별개의 API다
AsyncImage(url: URL(string: "https://..."))
```

### 정리

```text
Xcode 14 이하        Image("pic1")            문자열, 오타 위험
                    UIImage(named: "pic1")   옵셔널 반환

Xcode 15 이상        Image(.pic1)             자동 생성 심볼, 컴파일 타임 검증
(iOS 17+)           UIImage(resource: .pic1) 옵셔널 아님

핵심: Swift 언어가 아니라 Xcode의 코드 생성 기능이다.
```

## 학습 체크리스트

- [ ] `Image(.pic1)`을 `Image(ImageResource.pic1)`로 바꿔 같은 것임을 확인한다.
- [ ] `Image(.pci1)`처럼 오타를 내고 컴파일 에러가 나는지 확인한다.
- [ ] `Image("pci1")`로 문자열 오타를 내고 컴파일은 통과하되 화면이 비는 것을 확인한다.
- [ ] asset 이름을 `pic1`에서 `photo1`로 바꾸고 어느 쪽이 에러를 내는지 비교한다.
- [ ] `Image(.` 까지 입력해 자동완성 목록이 뜨는지 확인한다.
- [ ] `ImageResource`의 정의로 점프해(⌃⌘클릭) `struct`임을 확인한다.
- [ ] asset catalog에 폴더를 만들고 "Provides Namespace"를 켜서 중첩 심볼을 만든다.
- [ ] asset 이름에 하이픈(`my-pic`)을 넣고 생성된 심볼 이름을 확인한다.
- [ ] `ImageResource(name:bundle:)`로 동적 리소스를 만들어 본다.
- [ ] `UIImage(named:)`와 `UIImage(resource:)`의 반환 타입 차이를 확인한다.
- [ ] `ColorResource`로 색상 심볼도 생성되는지 확인한다.
- [ ] 배포 타겟을 iOS 16으로 낮추고 어떤 에러가 나는지 본다.

## 공식 참고 자료

- [Apple: ImageResource](https://developer.apple.com/documentation/developertoolssupport/imageresource)
- [Apple: ImageResource.init(name:bundle:)](https://developer.apple.com/documentation/developertoolssupport/imageresource/init(name:bundle:))
- [Apple: ColorResource](https://developer.apple.com/documentation/developertoolssupport/colorresource)
- [Apple: DeveloperToolsSupport](https://developer.apple.com/documentation/developertoolssupport)
- [Apple: Managing assets with asset catalogs](https://developer.apple.com/documentation/xcode/managing-assets-with-asset-catalogs)
- [Apple: Image](https://developer.apple.com/documentation/swiftui/image)
- [Apple: UIImage.init(resource:)](https://developer.apple.com/documentation/uikit/uiimage/init(resource:))
- [Apple: AsyncImage](https://developer.apple.com/documentation/swiftui/asyncimage)
