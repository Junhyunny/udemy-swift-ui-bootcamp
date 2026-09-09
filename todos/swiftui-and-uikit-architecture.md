# SwiftUI와 UIKit 아키텍처 학습 노트

> 핵심 요약: UIKit은 **살아 있는 UI 객체를 만들고 직접 변경하는 명령형 방식**이고, SwiftUI는 **현재 상태라면 UI가 어떻게 보여야 하는지를 선언하는 방식**이다. 두 프레임워크는 배타적인 관계가 아니며, 실제 앱에서는 공식 상호운용 도구를 이용해 함께 사용하는 경우가 많다.

## 목차

1. [`UI` 접두사가 붙는 타입의 의미](#1-ui-접두사가-붙는-타입의-의미)
2. [UIKit은 지금도 실무에서 쓰이는가](#2-uikit은-지금도-실무에서-쓰이는가)
3. [SwiftUI와 UIKit의 상호운용](#3-swiftui와-uikit의-상호운용)
4. [UIKit API 직접 호출과 Representable의 구분](#4-uikit-api-직접-호출과-representable의-구분)
5. [`UITextField` + `Coordinator` + `@Binding` 예제](#5-uitextfield--coordinator--binding-예제)
6. [`UIViewControllerRepresentable` 카메라 예제](#6-uiviewcontrollerrepresentable-카메라-예제)
7. [`UIHostingController` 역방향 예제](#7-uihostingcontroller-역방향-예제)
8. [고전 UIKit과 SwiftUI의 전체 구조](#8-고전-uikit과-swiftui의-전체-구조)
9. [`UIView`와 SwiftUI `View`의 본질적 차이](#9-uiview와-swiftui-view의-본질적-차이)
10. [명령형 UI와 선언형 UI](#10-명령형-ui와-선언형-ui)
11. [Controller 역할과 아키텍처 변화](#11-controller-역할과-아키텍처-변화)
12. [생명주기, 레이아웃, 내비게이션 비교](#12-생명주기-레이아웃-내비게이션-비교)
13. [상태 중심 설계와 단방향 데이터 흐름](#13-상태-중심-설계와-단방향-데이터-흐름)
14. [현대적인 SwiftUI 앱 구조](#14-현대적인-swiftui-앱-구조)
15. [전체 비교 요약과 학습 방향](#15-전체-비교-요약과-학습-방향)

---

## 1. `UI` 접두사가 붙는 타입의 의미

SwiftUI 코드에서 이름 앞에 `UI`가 붙는 타입을 만났다면, 대부분은 SwiftUI 컴포넌트가 아니라 **UIKit 타입**이다.

| 타입 | 프레임워크 | 역할 |
|---|---|---|
| `UIView` | UIKit | 모든 UIKit View의 기본 클래스 |
| `UILabel` | UIKit | 텍스트 표시 |
| `UIButton` | UIKit | 버튼 |
| `UIImageView` | UIKit | 이미지 표시 |
| `UITextField` | UIKit | 한 줄 텍스트 입력 |
| `UITextView` | UIKit | 여러 줄 텍스트 입력 |
| `UIScrollView` | UIKit | 스크롤 컨테이너 |
| `UITableView` | UIKit | 행 기반 리스트 |
| `UICollectionView` | UIKit | 컬렉션·그리드·복합 목록 |
| `UIViewController` | UIKit | 화면과 생명주기 관리 |
| `UINavigationController` | UIKit | 스택 기반 내비게이션 |
| `UITabBarController` | UIKit | 탭 기반 화면 전환 |
| `UIApplication` | UIKit | 실행 중인 앱을 대표하는 객체 |
| `UIWindow` | UIKit | 화면 계층이 표시되는 윈도우 |
| `UIScreen` | UIKit | 물리적 디스플레이 정보 |
| `UIColor`, `UIImage`, `UIFont` | UIKit | 색상, 이미지, 글꼴 값 |

UIKit과 SwiftUI의 대표적인 표현은 다음과 같이 대응한다.

```swift
// UIKit
let label = UILabel()
let button = UIButton()
let imageView = UIImageView()

// SwiftUI
Text("Hello")
Button("Save") { }
Image(systemName: "star")
```

UIKit은 2008년부터 사용된 전통적인 iOS UI 프레임워크이며 `UI` 접두사를 적극적으로 사용한다.

```text
UIKit
 ├─ UIView
 │   ├─ UILabel
 │   ├─ UIButton
 │   ├─ UIImageView
 │   ├─ UIScrollView
 │   │   ├─ UITableView
 │   │   └─ UICollectionView
 │   └─ UITextField
 │
 └─ UIViewController
```

SwiftUI는 2019년에 등장한 선언형 UI 프레임워크로, 타입 이름이 더 간결하다.

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hello")
            Image(systemName: "phone")
            Button("Call") {
                // 사용자 액션 처리
            }
        }
    }
}
```

다만 `UI` 접두사만으로 프레임워크를 100% 단정해서는 안 된다. 예를 들어 `UIViewRepresentable`과 `UIViewControllerRepresentable`은 이름에 UIKit 타입이 들어가지만, **SwiftUI가 제공하는 상호운용 프로토콜**이다.

```text
             iOS UI 개발
                 │
        ┌────────┴────────┐
        │                 │
      UIKit            SwiftUI
        │                 │
   UIViewController       View
        │                 │
      UIView           VStack
        │              Text
   UILabel             Button
   UIButton            List
   UIImageView         ...
        │                 │
        └──── bridge ─────┘
             ↑
   UIViewRepresentable
   UIViewControllerRepresentable
```

---

## 2. UIKit은 지금도 실무에서 쓰이는가

UIKit은 여전히 실무에서 중요하다. 특히 다음 상황에서는 UIKit 지식이 필요하거나 큰 도움이 된다.

- 오래된 대형 iOS 앱과 기존 UIKit 코드베이스를 유지·확장할 때
- 시스템 API나 저수준 네이티브 기능을 깊게 사용할 때
- UIKit 기반의 기존 사내·서드파티 컴포넌트를 재사용할 때
- 점진적으로 SwiftUI로 전환하는 앱을 다룰 때
- SwiftUI만으로 표현하기 어려운 세밀한 UI 동작이나 레거시 화면을 연결할 때

신규 앱은 SwiftUI 비중이 높아지고 있지만, 실무 앱은 흔히 두 기술이 섞여 있다.

```text
iOS App
│
├── SwiftUI
│   ├── Text
│   ├── Button
│   ├── List
│   └── NavigationStack
│
└── UIKit
    ├── UIView
    ├── UIViewController
    ├── UIScrollView
    ├── UICollectionView
    └── 기존·서드파티 UI
```

오래된 앱이라면 UIKit이 중심이고 새 화면 일부만 SwiftUI일 수도 있다.

```text
기존 UIKit App
│
├── UIViewController
│   ├── UIView
│   └── ...
│
└── 새로 만드는 화면 일부
      ↓
    SwiftUI
```

따라서 SwiftUI와 UIKit은 경쟁 관계라기보다 **점진적 마이그레이션이 가능한 공존 관계**로 보는 편이 정확하다.

---

## 3. SwiftUI와 UIKit의 상호운용

두 프레임워크를 연결할 때 기억해야 할 핵심 도구는 세 가지다.

| 가져오는 방향 | 대상 | 도구 |
|---|---|---|
| UIKit → SwiftUI | `UIView` | `UIViewRepresentable` |
| UIKit → SwiftUI | `UIViewController` | `UIViewControllerRepresentable` |
| SwiftUI → UIKit | SwiftUI `View` | `UIHostingController` |

```text
UIKit View
        ↓
UIViewRepresentable
        ↓
SwiftUI

UIKit ViewController
        ↓
UIViewControllerRepresentable
        ↓
SwiftUI

SwiftUI View
        ↓
UIHostingController
        ↓
UIKit
```

### 3.1 `UIViewRepresentable`: UIKit View를 SwiftUI에 넣기

```swift
import SwiftUI
import UIKit

struct MyUIKitView: UIViewRepresentable {
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = "Hello UIKit"
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        // SwiftUI 상태가 변경될 때 기존 UILabel을 갱신한다.
    }
}
```

SwiftUI에서는 일반 `View`처럼 조합한다.

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            Text("SwiftUI")
            MyUIKitView()
            Button("Button") {
                // ...
            }
        }
    }
}
```

```text
SwiftUI

VStack
 ├── Text
 │
 ├── MyUIKitView
 │       │
 │       └─ UIViewRepresentable
 │                │
 │                └─ UILabel ← UIKit
 │
 └── Button
```

`UIViewRepresentable`의 핵심 메서드는 다음과 같다.

- `makeUIView(context:)`: UIKit View를 최초 한 번 생성하고 기본 설정을 한다.
- `updateUIView(_:context:)`: SwiftUI 상태 변화가 기존 UIKit View에 반영되도록 동기화한다.
- `makeCoordinator()`: delegate, target-action, callback 같은 UIKit 이벤트를 SwiftUI 상태와 연결할 때 사용한다.

### 3.2 `UIViewControllerRepresentable`: UIKit 화면 단위를 SwiftUI에 넣기

```swift
struct MyController: UIViewControllerRepresentable {
    func makeUIViewController(
        context: Context
    ) -> SomeViewController {
        SomeViewController()
    }

    func updateUIViewController(
        _ viewController: SomeViewController,
        context: Context
    ) {
        // SwiftUI 상태를 기존 ViewController에 반영
    }
}
```

```swift
struct ContentView: View {
    var body: some View {
        MyController()
    }
}
```

### 3.3 `UIHostingController`: SwiftUI View를 UIKit에 넣기

```swift
let swiftUIView = MySwiftUIView()
let controller = UIHostingController(rootView: swiftUIView)

navigationController?.pushViewController(
    controller,
    animated: true
)
```

---

## 4. UIKit API 직접 호출과 Representable의 구분

SwiftUI 코드에서 UIKit 타입을 사용한다고 해서 항상 Representable이 필요한 것은 아니다.

```swift
UIApplication.shared
UIDevice.current
UIImage(...)
UIColor(...)
```

이런 API나 값 객체는 SwiftUI 코드에서 직접 사용할 수 있다.

```swift
struct ContentView: View {
    var body: some View {
        Button("Open Settings") {
            UIApplication.shared.open(
                URL(string: UIApplication.openSettingsURLString)!
            )
        }
    }
}
```

Representable은 **UIKit의 UI 객체를 SwiftUI의 View 계층 안에 실제로 삽입할 때** 필요하다.

```text
SwiftUI View
     │
     ├── UIKit의 API·값 객체 사용
     │       ↓
     │    직접 사용 가능
     │
     ├── UIKit UIView를 화면 계층에 삽입
     │       ↓
     │    UIViewRepresentable 필요
     │
     └── UIKit UIViewController 화면을 삽입
             ↓
          UIViewControllerRepresentable 필요
```

판단 기준을 질문 형태로 정리하면 다음과 같다.

1. UIKit의 기능이나 값을 호출하기만 하는가? → 대개 직접 사용한다.
2. `UIView` 인스턴스를 SwiftUI 화면에 표시해야 하는가? → `UIViewRepresentable`을 쓴다.
3. `UIViewController`가 제공하는 화면·생명주기 단위가 필요한가? → `UIViewControllerRepresentable`을 쓴다.
4. 기존 UIKit 화면 안에 SwiftUI 화면을 넣는가? → `UIHostingController`를 쓴다.

---

## 5. `UITextField` + `Coordinator` + `@Binding` 예제

다음 예제는 UIKit의 `UITextField`를 SwiftUI에서 사용하면서, UIKit의 target-action 이벤트를 SwiftUI 상태와 양방향으로 연결한다.

### 5.1 UIKit View를 감싸는 어댑터

```swift
import SwiftUI
import UIKit

struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()

        textField.borderStyle = .roundedRect
        textField.placeholder = "UIKit TextField"
        textField.delegate = context.coordinator

        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )

        return textField
    }

    func updateUIView(
        _ uiView: UITextField,
        context: Context
    ) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        @objc
        func textChanged(_ sender: UITextField) {
            text = sender.text ?? ""
        }
    }
}
```

### 5.2 SwiftUI에서 사용하기

```swift
struct ContentView: View {
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("SwiftUI 화면")
                .font(.title)

            UIKitTextField(text: $name)
                .frame(height: 44)
                .padding(.horizontal)

            Text("입력값: \(name)")

            Button("Clear") {
                name = ""
            }
        }
        .padding()
    }
}
```

### 5.3 양방향 데이터 흐름

```text
SwiftUI
@State name
    │
    │ Binding
    ▼
UIKitTextField
    │
    │ UIViewRepresentable
    ▼
UITextField
    │
    │ editingChanged
    ▼
Coordinator
    │
    │ @Binding
    ▼
@State name
```

사용자가 `Jun`을 입력했을 때의 흐름은 다음과 같다.

```text
사용자가 UITextField에 "Jun" 입력

UITextField
   ↓
Coordinator.textChanged()
   ↓
@Binding text
   ↓
SwiftUI @State name
   ↓
body 재평가
   ↓
Text("입력값: Jun")
```

반대 방향도 동작한다. SwiftUI의 `Clear` 버튼이 `name = ""`로 상태를 바꾸면 `body`가 다시 평가되고, `updateUIView`가 기존 `UITextField.text`에 빈 문자열을 반영한다.

즉, `Coordinator`는 UIKit의 delegate·callback·target-action 기반 **명령형 이벤트**를 SwiftUI의 `@State`, `@Binding`, `@Observable` 같은 **상태 모델**과 연결하는 중간자다. 실무 상호운용에서 난도가 높아지는 지점도 주로 이 이벤트·상태 동기화 부분이다.

---

## 6. `UIViewControllerRepresentable` 카메라 예제

카메라처럼 UIKit의 화면 단위 기능이나 기존 ViewController 전체를 재사용해야 한다면 `UIViewControllerRepresentable`을 사용한다. 다음 코드는 구조를 설명하기 위한 간단한 가상 카메라 화면이다.

### 6.1 기존 UIKit ViewController

```swift
import UIKit

final class CameraViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        let label = UILabel()
        label.text = "UIKit Camera Screen"
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            label.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            )
        ])
    }
}
```

### 6.2 SwiftUI용 어댑터

```swift
import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(
        context: Context
    ) -> CameraViewController {
        CameraViewController()
    }

    func updateUIViewController(
        _ uiViewController: CameraViewController,
        context: Context
    ) {
        // SwiftUI 상태 변화가 있으면 여기에서 반영한다.
    }
}
```

### 6.3 SwiftUI 내비게이션에서 표시

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            NavigationLink("카메라 열기") {
                CameraView()
            }
        }
    }
}
```

```text
SwiftUI

NavigationStack
   │
   └── CameraView
           │
           │ UIViewControllerRepresentable
           ▼
   CameraViewController
           │
           ▼
        UIView
```

실제 카메라 구현에서는 권한 요청, 캡처 세션, delegate callback, 취소·완료 이벤트 등을 `Coordinator`나 별도 모델을 통해 SwiftUI 상태·클로저와 연결할 수 있다.

---

## 7. `UIHostingController` 역방향 예제

기존 UIKit 앱에서 새 화면 하나만 SwiftUI로 구현하고 싶다면 SwiftUI View를 `UIHostingController`의 root view로 감싼다.

### 7.1 SwiftUI 화면

```swift
import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack {
            Image(systemName: "person.circle")
                .font(.system(size: 80))

            Text("Profile")
                .font(.title)
        }
    }
}
```

### 7.2 UIKit에서 push

```swift
import SwiftUI
import UIKit

final class HomeViewController: UIViewController {
    func openProfile() {
        let swiftUIView = ProfileView()
        let hostingController = UIHostingController(
            rootView: swiftUIView
        )

        navigationController?.pushViewController(
            hostingController,
            animated: true
        )
    }
}
```

이 방법 덕분에 UIKit 앱 전체를 한 번에 재작성하지 않고, 화면 또는 기능 단위로 SwiftUI를 도입할 수 있다.

---

## 8. 고전 UIKit과 SwiftUI의 전체 구조

### 8.1 UIKit 계층

```text
UIKit

UIApplication
    │
    ├── AppDelegate
    │
    └── UIScene
         │
         ├── SceneDelegate
         │
         └── UIWindow
              │
              └── UIViewController
                   │
                   └── UIView
                        │
                        ├── UILabel
                        ├── UIButton
                        ├── UIImageView
                        └── ...
```

- `UIApplication`: 실행 중인 앱과 시스템 이벤트를 대표한다.
- `AppDelegate`: 앱 수준 생명주기와 설정을 다룬다.
- `UIScene`: 하나의 UI 세션을 나타낸다. 멀티 윈도우 환경에서는 여러 Scene이 존재할 수 있다.
- `SceneDelegate`: Scene의 연결·활성·비활성 같은 생명주기를 다룬다.
- `UIWindow`: ViewController와 View 계층이 표시되는 윈도우다.
- `UIViewController`: 화면 단위 구성, 생명주기, 이벤트, 내비게이션을 관리한다.
- `UIView`: 실제 화면 계층을 이루는 객체다.

### 8.2 SwiftUI 계층

```text
SwiftUI

@main
App
 │
 └── Scene
      │
      └── WindowGroup
           │
           └── View
                │
                ├── VStack
                │    ├── Text
                │    ├── Image
                │    └── Button
                │
                └── ...
```

- `App`: 앱의 진입점과 Scene 구성을 선언한다.
- `Scene`: 앱이 제공하는 UI 세션을 선언한다.
- `WindowGroup`: SwiftUI가 윈도우 생성과 관리를 수행하도록 선언한다.
- `View`: 상태를 바탕으로 UI가 어떻게 보여야 하는지 기술한다.

### 8.3 개념적 대응 관계

| UIKit | SwiftUI | 주의점 |
|---|---|---|
| `UIApplication` / `AppDelegate` | `App` | 완전한 1:1 대응이 아니라 앱 구성의 추상화 |
| `UIScene` / `SceneDelegate` | `Scene` | SwiftUI가 많은 생명주기 처리를 감춘다 |
| `UIWindow` | `WindowGroup` | `WindowGroup`이 윈도우 생성을 관리한다 |
| `UIViewController` | 직접 대응 없음 | 역할이 View, 상태, 프레임워크로 분산된다 |
| `UIView` | `View` | 이름은 비슷하지만 본질이 다르다 |
| `UILabel` | `Text` | 객체와 선언이라는 차이가 있다 |
| `UIButton` | `Button` | 객체와 선언이라는 차이가 있다 |
| `UIImageView` | `Image` | 객체와 선언이라는 차이가 있다 |
| `UIStackView` | `VStack`, `HStack`, `ZStack` | SwiftUI는 조합으로 레이아웃을 표현한다 |
| `UINavigationController` | `NavigationStack` | 명령형 push와 상태 기반 내비게이션의 차이 |
| `UITabBarController` | `TabView` | SwiftUI는 탭 구성을 선언한다 |

중요한 결론은 `UIViewController → 어떤 SwiftUI 타입`, `UIView → SwiftUI View`처럼 기계적으로 치환할 수 없다는 것이다. SwiftUI는 UIKit에서 개발자가 직접 맡던 여러 역할을 프레임워크 수준으로 추상화한다.

---

## 9. `UIView`와 SwiftUI `View`의 본질적 차이

### 9.1 UIKit: 살아 있는 객체를 만들고 변경한다

```swift
let label = UILabel()

label.text = "Hello"
label.textColor = .red

view.addSubview(label)
```

`label`은 identity와 변경 가능한 속성을 가진 실제 객체다.

```text
UILabel object
    │
    ├── text = "Hello"
    ├── textColor = red
    ├── frame = ...
    └── 실제 UI 객체
```

나중에 같은 객체를 직접 바꾼다.

```swift
label.text = "World"
```

```text
객체 생성
   ↓
객체 보관
   ↓
객체 property 변경
   ↓
화면 변경
```

### 9.2 SwiftUI: 상태로부터 UI 설명을 계산한다

```swift
struct ContentView: View {
    @State private var name = "Jun"

    var body: some View {
        Text("Hello \(name)")
    }
}
```

`name = "Kim"`으로 바꾸더라도 개발자가 `Text` 객체를 찾아 직접 수정하지 않는다.

```text
State 변경

name
"Jun" → "Kim"
      │
      ▼
SwiftUI가 body를 다시 평가
      │
      ▼
새로운 UI description
      │
      ▼
Text("Hello Kim")
      │
      ▼
기존 UI와 비교
      │
      ▼
필요한 부분 업데이트
```

SwiftUI의 `View` 값은 실제 렌더링 객체 자체라기보다 **현재 상태에 대한 UI 선언 또는 description**에 가깝다. 실제 렌더링과 변경 적용은 SwiftUI가 관리한다.

### 9.3 `class`와 `struct`

UIKit의 중심 타입은 대부분 class다.

```swift
class UIView
class UIViewController
class UILabel: UIView
class UIButton: UIView
```

같은 객체의 identity를 유지한 채 속성을 계속 변경하는 방식이기 때문이다.

```swift
let button = UIButton()
button.isEnabled = false

// 동일한 button 객체를 변경한다.
button.isEnabled = true
```

반면 SwiftUI의 `View`는 프로토콜이며, 우리가 정의하는 View는 대개 struct다.

```swift
public protocol View {
    associatedtype Body: View

    @ViewBuilder
    var body: Self.Body { get }
}
```

```swift
struct ProfileView: View {
    var body: some View {
        Text("Profile")
    }
}
```

SwiftUI에서는 View 값을 오래 붙잡아 직접 mutation하는 것이 핵심이 아니다. 상태가 바뀌면 새로운 View description을 계산하고 프레임워크가 필요한 렌더링 변경을 적용한다.

---

## 10. 명령형 UI와 선언형 UI

### 10.1 UIKit: Imperative UI

UIKit에서는 UI 객체에게 무엇을 해야 하는지 명령한다.

```swift
func updateLoginState(isLoggedIn: Bool) {
    if isLoggedIn {
        loginButton.isHidden = true
        logoutButton.isHidden = false
        welcomeLabel.isHidden = false
        welcomeLabel.text = "Welcome!"
    } else {
        loginButton.isHidden = false
        logoutButton.isHidden = true
        welcomeLabel.isHidden = true
    }
}
```

```text
State
  │
  ▼
Developer logic
  │
  ├── loginButton.isHidden = ...
  ├── logoutButton.isHidden = ...
  └── label.text = ...
```

개발자가 여러 UI 속성의 일관성을 직접 유지해야 한다. 상태 전환이 많아질수록 특정 속성 갱신을 빠뜨려 화면과 실제 상태가 어긋날 위험이 커진다.

### 10.2 SwiftUI: Declarative UI

SwiftUI에서는 특정 상태일 때 UI가 어떻게 생겨야 하는지 선언한다.

```swift
struct ContentView: View {
    @State private var isLoggedIn = false

    var body: some View {
        VStack {
            if isLoggedIn {
                Text("Welcome!")

                Button("Logout") {
                    isLoggedIn = false
                }
            } else {
                Button("Login") {
                    isLoggedIn = true
                }
            }
        }
    }
}
```

```text
              State
                │
         isLoggedIn = true
                │
                ▼
             body
                │
        ┌───────┴───────┐
        │               │
     Welcome!        Logout
```

개발자의 선언은 “이 Label을 숨기고 저 Button을 보이게 해라”가 아니라 “`isLoggedIn == true`일 때 이 UI를 보여라”에 가깝다.

---

## 11. Controller 역할과 아키텍처 변화

### 11.1 UIKit의 `UIViewController`

UIKit에서 `UIViewController`는 화면의 중심이다.

```swift
class ProfileViewController: UIViewController {
    private let nameLabel = UILabel()
    private let saveButton = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupConstraints()
        loadProfile()
    }

    func loadProfile() {
        // data load
    }

    @objc
    func saveButtonTapped() {
        // save
    }
}
```

프로젝트 구조를 잘 나누지 않으면 하나의 ViewController가 다음 역할을 모두 떠맡기 쉽다.

```text
UIViewController

├── View 생성
├── Layout
├── Lifecycle
├── Event 처리
├── Navigation
├── Data loading
├── State
└── Business logic
```

이렇게 역할이 비대해진 상태를 흔히 **Massive View Controller**라고 부른다.

```text
ProfileViewController
      │
      ├── 2,000 lines
      ├── networking
      ├── UI
      ├── navigation
      ├── state
      └── business logic
```

전통적인 Cocoa MVC에서는 ViewController가 Controller 역할을 하지만, 실제 구현에서 View와 Controller의 결합이 강해지면서 비대해지기 쉽다. 이를 완화하기 위해 UIKit 프로젝트에서는 MVC 외에도 MVVM, MVP, VIPER, Coordinator 같은 패턴을 사용해 상태, 비즈니스 로직, 내비게이션 책임을 분리해 왔다.

### 11.2 SwiftUI에서 ViewController가 보이지 않는 이유

```swift
struct ProfileView: View {
    @State private var name = ""

    var body: some View {
        VStack {
            Text(name)

            Button("Save") {
                // ...
            }
        }
    }
}
```

여기에는 `UIViewController`가 없다. 그 역할을 단일 SwiftUI 타입이 그대로 대체한 것이 아니라, SwiftUI 프레임워크와 View·상태·내비게이션 선언에 나누어 맡긴 것이다.

```text
               SwiftUI Framework
                      │
          ┌───────────┼───────────┐
          │           │           │
      Lifecycle   Rendering    Update
          │           │           │
          └───────────┼───────────┘
                      │
                   Your View
                      │
                    State
```

따라서 SwiftUI 개발자는 UI 객체의 생명주기와 속성을 직접 관리하는 일보다 **상태의 소유권, 변화, 전달**에 더 집중한다.

---

## 12. 생명주기, 레이아웃, 내비게이션 비교

### 12.1 생명주기

UIKit의 ViewController 생명주기는 명시적인 callback 중심이다.

```swift
override func viewDidLoad() { }
override func viewWillAppear(_ animated: Bool) { }
override func viewDidAppear(_ animated: Bool) { }
override func viewWillDisappear(_ animated: Bool) { }
override func viewDidDisappear(_ animated: Bool) { }
```

```text
UIViewController 생성
      ↓
viewDidLoad
      ↓
viewWillAppear
      ↓
viewDidAppear
      ↓
   화면 표시
      ↓
viewWillDisappear
      ↓
viewDidDisappear
```

SwiftUI에서는 View modifier와 상태 중심으로 필요한 작업을 선언한다.

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello")
            .onAppear {
                print("appear")
            }
            .task {
                await loadData()
            }
            .onDisappear {
                print("disappear")
            }
    }
}
```

`body`는 상태 변화에 따라 여러 번 평가될 수 있다. 따라서 중요한 side effect를 `body` 계산 자체에 넣으면 안 된다.

```swift
var body: some View {
    print("render!") // body 평가 횟수를 생명주기로 오해하면 안 된다.
    return Text("Hello")
}
```

`body`는 **UI description을 계산하는 곳이지 생명주기 callback이 아니다.** 데이터 로딩 등은 `.task`, 이벤트 처리는 적절한 modifier나 모델 계층에서 수행한다.

### 12.2 레이아웃

UIKit은 전통적으로 Auto Layout constraint로 View 사이의 관계를 설정한다.

```swift
NSLayoutConstraint.activate([
    label.leadingAnchor.constraint(
        equalTo: view.leadingAnchor,
        constant: 16
    ),
    label.trailingAnchor.constraint(
        equalTo: view.trailingAnchor,
        constant: -16
    ),
    label.centerYAnchor.constraint(
        equalTo: view.centerYAnchor
    )
])
```

```text
UIView
 │
 ├── Constraint
 │      ├── leading = 16
 │      ├── trailing = 16
 │      └── centerY
 │
 └── UILabel
```

SwiftUI는 컨테이너와 modifier의 조합으로 레이아웃을 선언한다.

```swift
VStack {
    Text("Hello")
    Text("World")
}
.padding(16)
```

```text
VStack
 │
 ├── Text
 ├── Text
 │
 └── padding(16)
```

UIKit에서는 개발자가 제약 조건과 View 계층을 관리하는 반면, SwiftUI에서는 부모가 공간을 제안하고 자식이 크기를 선택하는 레이아웃 체계 안에서 View를 조합한다.

### 12.3 내비게이션

UIKit에서는 ViewController를 push하라는 명령을 보낸다.

```swift
navigationController?.pushViewController(
    ProfileViewController(),
    animated: true
)
```

```text
User Action
    ↓
pushViewController()
    ↓
Navigation 변경
```

SwiftUI에서는 목적 화면을 선언한다.

```swift
NavigationStack {
    NavigationLink("Profile") {
        ProfileView()
    }
}
```

복잡한 내비게이션은 경로 자체를 상태로 모델링할 수 있다.

```swift
@State private var path: [Route] = []

NavigationStack(path: $path) {
    // destination 선언
}
```

```text
User Action
    ↓
Navigation State 변경
    ↓
SwiftUI
    ↓
Navigation 변경
```

즉, UIKit의 내비게이션은 Controller에 대한 명령에 가깝고, SwiftUI 내비게이션은 UI 상태의 일부로 표현하기 쉽다.

---

## 13. 상태 중심 설계와 단방향 데이터 흐름

UIKit에서는 전통적으로 ViewController가 화면 객체, 이벤트, 상태를 중심에서 관리한다.

```text
              UIViewController
                    │
        ┌───────────┼───────────┐
        │           │           │
      UIView      State       Event
        │
   ┌────┼────┐
 UILabel Button ...
```

SwiftUI에서는 상태가 중심에 가까워진다.

```text
                 State
                   │
          ┌────────┴────────┐
          │                 │
        View              Logic
          │
          │ user action
          └────────┐
                   ▼
                 State
                   │
                   ▼
                  View
```

전형적인 흐름은 다음과 같다.

```text
State
  ↓
View
  ↓
Action
  ↓
State
  ↓
View
  ↓
Action
  ↓
...
```

이를 **단방향 데이터 흐름(Unidirectional Data Flow)**이라고 한다.

- 상태가 View를 결정한다.
- 사용자는 View에서 Action을 발생시킨다.
- 로직이 Action을 처리해 상태를 변경한다.
- 바뀐 상태로 View가 다시 계산된다.

이 구조는 화면에 표시되는 내용과 실제 상태의 관계를 추적하기 쉽게 만들며, 테스트와 기능 분리에 유리하다. 다만 상태 소유권과 의존성 경계를 설계하지 않으면 SwiftUI View나 ViewModel도 충분히 비대해질 수 있다.

---

## 14. 현대적인 SwiftUI 앱 구조

SwiftUI는 특정 아키텍처를 강제하지 않는다. 화면과 앱의 복잡도에 맞춰 구조를 선택해야 한다.

### 14.1 작은 화면: View 내부 상태

```text
View
 │
 ├── @State
 └── @Binding
```

- `@State`: 해당 View가 소유하는 로컬 상태
- `@Binding`: 상위 계층이 소유한 상태에 대한 읽기·쓰기 연결

화면 범위가 작고 비즈니스 로직이 단순하다면 이 구성이 가장 직접적이다.

### 14.2 커지는 기능: MVVM 또는 관찰 가능한 모델

```text
            View
              │
            Action
              │
              ▼
          ViewModel
              │
        ┌─────┴─────┐
        │           │
    Repository    Service
        │
        ▼
       API

              │
              ▼
            State
              │
              ▼
            View
```

```swift
import Observation

@Observable
final class ProfileViewModel {
    var profile: Profile?
    var isLoading = false

    func load() async {
        // Repository 또는 Service 호출
    }
}
```

```swift
struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        // viewModel의 상태를 기반으로 UI 선언
    }
}
```

MVVM에서는 ViewModel이 화면 상태와 사용자 액션 처리를 맡고, Repository·Service가 데이터 접근과 외부 시스템 연동을 맡는 식으로 책임을 나눌 수 있다. 다만 모든 코드를 ViewModel 하나에 몰아넣으면 “Massive ViewModel”이 될 수 있으므로 기능 경계를 유지해야 한다.

### 14.3 복잡한 기능: Reducer 기반 구조와 TCA

```text
          ┌─────────────┐
          │    State    │
          └──────┬──────┘
                 │
                 ▼
               View
                 │
               Action
                 │
                 ▼
              Reducer
                 │
        ┌────────┴────────┐
        │                 │
      Effect          New State
        │                 │
        └─────────────────┘
```

TCA(The Composable Architecture)가 대표적인 예다.

- `State`: 화면과 기능의 전체 상태
- `Action`: 사용자 입력, 시스템 이벤트, 비동기 결과
- `Reducer`: Action을 받아 State를 변경하고 Effect를 반환하는 로직
- `Effect`: 네트워크, 타이머, 저장소 등 외부 작업
- `View`: State를 표시하고 Action을 전달

이 구조는 상태 변화와 side effect가 복잡하고 여러 기능을 조합해야 할 때 명시성과 테스트 가능성을 높인다. 반대로 작은 화면에 과도하게 적용하면 보일러플레이트와 학습 비용이 커질 수 있다.

### 14.4 UIKit 패턴과 SwiftUI 구조의 관계

| 맥락 | 자주 쓰는 구조 | 중심 관심사 |
|---|---|---|
| 전통적 UIKit | MVC | ViewController가 View와 Model을 중재 |
| 대형 UIKit | MVVM, MVP, VIPER, Coordinator | ViewController 책임과 내비게이션 분리 |
| 작은 SwiftUI 기능 | View + `@State` + `@Binding` | 최소한의 상태 소유·전달 |
| 중간 규모 SwiftUI | MVVM, `@Observable` 모델 | 화면 상태와 비즈니스 로직 분리 |
| 복잡한 SwiftUI | Reducer, TCA 등 | 명시적인 State–Action–Effect 흐름 |

SwiftUI라고 해서 MVC나 MVVM이 자동으로 사라지는 것은 아니다. 달라진 핵심은 UI 객체를 직접 갱신하는 코드보다 **상태 모델과 상태 변화의 흐름**이 아키텍처 중심으로 이동한다는 점이다.

---

## 15. 전체 비교 요약과 학습 방향

### 15.1 한 장으로 보는 변화

```text
       Traditional UIKit                    SwiftUI

┌─────────────────────────┐       ┌─────────────────────────┐
│     UIApplication       │       │          App            │
└────────────┬────────────┘       └────────────┬────────────┘
             │                                 │
         UIScene                             Scene
             │                                 │
          UIWindow                         WindowGroup
             │                                 │
             ▼                                 ▼
┌─────────────────────────┐       ┌─────────────────────────┐
│    UIViewController     │       │          View           │
│                         │       │                         │
│ lifecycle               │       │ UI description          │
│ navigation              │       │                         │
│ event handling          │       └────────────┬────────────┘
│ UI management           │                    │
└────────────┬────────────┘                  State
             │                                │ ▲
             ▼                                │ │
┌─────────────────────────┐                   ▼ │
│         UIView          │                 Action
│                         │
│ UILabel                 │
│ UIButton                │
│ UIImageView             │
└─────────────────────────┘

      Object 중심                         State 중심

      Imperative                          Declarative

   "이 Label을 바꿔"                "이 State라면 이렇게 보여"

      class 중심                          struct 중심

UIViewController lifecycle              View description

 UI 객체 직접 관리                    SwiftUI가 rendering 관리
```

### 15.2 잘못된 1:1 치환을 피하기

다음과 같은 단순 치환은 정확하지 않다.

```text
UIViewController → SwiftUI View
UIView           → SwiftUI View
```

실제로는 다음 변화에 가깝다.

```text
UIKit

UIViewController
      +
UIView hierarchy
      +
UI state mutation
      +
lifecycle
      +
layout
      +
rendering 관리

             ↓ SwiftUI가 많은 부분을 추상화

SwiftUI

State
  +
View description
  +
Action
```

따라서 “`UIViewController`에 해당하는 SwiftUI 타입이 무엇인가?”라는 질문의 가장 좋은 답은 **정확한 1:1 대응 타입은 없다**이다.

### 15.3 비교표

| 관점 | UIKit | SwiftUI |
|---|---|---|
| 기본 패러다임 | 명령형 | 선언형 |
| 중심 | UI 객체·ViewController | 상태와 View description |
| 대표 타입 성격 | class, reference identity | struct 기반 값·선언 |
| UI 갱신 | 객체 속성을 직접 변경 | 상태 변경 후 body 재평가 |
| 화면 관리 | `UIViewController` 중심 | 프레임워크 + View + 상태로 분산 |
| 생명주기 | 명시적 ViewController callback | `.task`, `.onAppear`, `.onDisappear` 등 |
| 레이아웃 | View 계층 + Auto Layout constraints | 컨테이너 + modifier 조합 |
| 내비게이션 | push/present 같은 명령 | 목적 화면·경로 상태 선언 |
| 이벤트 | target-action, delegate, callback | Action이 상태 변경으로 연결 |
| 데이터 흐름 | 자유롭지만 양방향·분산되기 쉬움 | 단방향 흐름을 만들기 자연스러움 |
| 흔한 구조 | MVC, MVVM, MVP, VIPER, Coordinator | View-local state, MVVM, Reducer/TCA |
| 상호운용 | SwiftUI를 `UIHostingController`로 포함 | UIKit을 Representable로 포함 |

### 15.4 실용적인 학습 순서

SwiftUI 학습을 멈추고 UIKit 전체를 먼저 공부하기보다 다음 순서로 병행하는 방식이 효율적이다.

1. SwiftUI의 `View`, `@State`, `@Binding`, `@Observable`, `NavigationStack`, `.task`, `.sheet`를 익힌다.
2. UIKit의 `UIView → UIViewController → UIWindow → UIScene → UIApplication` 관계를 익힌다.
3. `viewDidLoad`, `viewWillAppear`, `viewDidAppear`, `present`, `dismiss`, `UINavigationController`를 이해한다.
4. `UIViewRepresentable`, `UIViewControllerRepresentable`, `UIHostingController`로 두 세계를 연결한다.
5. delegate와 callback을 `Coordinator` 및 SwiftUI 상태에 연결해 본다.
6. 같은 작은 앱을 UIKit MVC와 SwiftUI 방식으로 각각 구현해 구조를 비교한다.
7. 규모가 커졌을 때 MVVM, Repository·Service 분리, Reducer/TCA를 선택적으로 학습한다.

예제로는 **사용자 목록 → 상세 → 수정** 흐름이 좋다. 같은 기능을 두 방식으로 구현하면 다음 차이를 한 번에 확인할 수 있다.

- `UIViewController` 생명주기와 SwiftUI View 평가 방식
- 직접 UI 속성을 변경하는 코드와 상태 기반 선언
- Auto Layout과 SwiftUI 레이아웃 조합
- push 기반 내비게이션과 상태 기반 경로
- UIKit delegate/callback과 SwiftUI `@Binding`
- Massive View Controller 문제와 상태·로직 분리

---

## 최종 기억 포인트

```text
1. UI로 시작하는 타입은 대체로 UIKit이다.
2. UIKit은 여전히 중요하며 SwiftUI와 함께 사용된다.
3. UIKit API 호출 자체에는 Representable이 필요하지 않다.
4. UIView를 화면에 넣을 때 UIViewRepresentable을 쓴다.
5. UIViewController를 넣을 때 UIViewControllerRepresentable을 쓴다.
6. SwiftUI View를 UIKit에 넣을 때 UIHostingController를 쓴다.
7. Coordinator는 UIKit 이벤트를 SwiftUI 상태와 연결한다.
8. UIKit은 객체 중심·명령형·class 중심이다.
9. SwiftUI는 상태 중심·선언형·struct 기반 View description 중심이다.
10. UIViewController와 SwiftUI View에는 정확한 1:1 대응이 없다.
11. SwiftUI에서는 State → View → Action → State 흐름이 자연스럽다.
12. 앱 규모에 맞춰 View-local state, MVVM, Reducer/TCA 등을 선택한다.
```

---

## 관련 TODO 문서

- [`UIViewRepresentable`과 `UI` 접두사 — UIKit 컴포넌트를 SwiftUI로 가져오기](./uiviewrepresentable-and-uikit-bridge.md)
- [SwiftUI 애플리케이션 아키텍처 — `App`, `Scene`, `WindowGroup`, `DocumentGroup`](./swiftui-application-architecture.md)
- [SwiftUI의 생명주기 — App, Scene, View](./view-lifecycle-hooks.md)
- [`NavigationStack`은 언제 등장했고 `NavigationView`와 무엇이 다른가](./navigation-stack-vs-navigation-view.md)
- [상태 관리 래퍼 총정리 — 왜 이렇게 종류가 많은가](./state-wrapper-decision-guide.md)
- [`Observation` 모듈과 `@Observable` 매크로](./observation-framework-and-observable.md)
