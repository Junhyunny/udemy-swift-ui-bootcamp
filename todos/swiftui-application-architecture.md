# SwiftUI 애플리케이션 아키텍처 정리

> 원본 대화: **SwiftUI 아키텍처 설명**<br>
> 정리 목적: 대화에서 다룬 SwiftUI의 최상위 애플리케이션 구조와 핵심 mental model을 최대한 보존하고, 학습용 문서로 다시 구성한다.

UIKit의 객체 중심 구조와 SwiftUI의 상태 중심 구조를 비교하고 두 프레임워크의 상호운용 방법까지 보려면 [SwiftUI와 UIKit 아키텍처 학습 노트](./swiftui-and-uikit-architecture.md)를 함께 본다.

## 1. 대화의 흐름과 질문 맥락

대화는 사용자가 처음에 `siwftUI 아키텍처`라고 짧게 질문하면서 시작되었다. 이에 대해 답변은 SwiftUI 아키텍처를 단순히 MVVM 하나로 이해하기보다 다음 순서로 공부하는 것이 좋다고 제안했다.

```text
SwiftUI 자체의 상태 관리 방식
        ↓
Feature 분리
        ↓
Dependency Injection
        ↓
Navigation
        ↓
테스트 구조
```

실무적인 앱 내부 구조의 기준점으로는 다음 흐름이 제시되었다.

```text
SwiftUI
   ↓
View
   ↓ user action
Feature / ViewModel
   ↓
UseCase / Service
   ↓
Repository
   ↓
API / DB / System Framework
```

첫 답변의 원본 기록은 `SwiftUI 아키텍처의 핵심은 사실 MV…`에서 끝나므로, 그 뒤의 내용은 보존된 대화에 존재하지 않는다. 이후 사용자가 질문을 구체화했다.

> SwiftUI 아키텍처에 대해 알려줘.<br>
> `App`, `Scene`, `WindowGroup`, `DocumentGroup`은 뭐야?

이에 따라 대화의 초점은 MVVM이나 TCA 같은 앱 내부 설계 패턴이 아니라, 그보다 바깥에 있는 **SwiftUI 애플리케이션 자체의 최상위 계층**으로 이동했다.

마지막으로 사용자는 이 대화의 내용을 최대한 많이 보존한 Markdown 문서를 요청했다.

---

## 2. 가장 중요한 전체 그림: `App → Scene → View`

SwiftUI 앱의 최상위 구조를 크게 보면 다음과 같다.

```text
App
 └── Scene
      ├── WindowGroup
      │    └── View
      │         └── View
      │              └── View ...
      │
      └── DocumentGroup
           └── View
```

여기서 가장 중요한 핵심은 다음 계층이다.

```text
App
 ↓
Scene
 ↓
View
```

- `App`: 애플리케이션 전체와 진입점을 정의한다.
- `Scene`: 앱이 제공하는 UI 세션 또는 창의 구조를 정의한다.
- `View`: 사용자가 실제로 보는 화면과 그 안의 UI 트리를 구성한다.

`WindowGroup`과 `DocumentGroup`은 `View`가 아니라 **`Scene`의 구체적인 종류**다.

---

## 3. `App`: 애플리케이션의 진입점

일반적인 SwiftUI 앱은 다음과 같은 코드에서 시작한다.

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`App`은 SwiftUI 애플리케이션 전체의 최상위 구조다.

```swift
@main
struct MyApp: App
```

`@main`이 붙은 `MyApp` 타입은 프로그램의 진입점이 된다. UIKit에서 `UIApplication`, `AppDelegate`, `SceneDelegate` 등이 맡던 앱 시작과 생명주기 구성의 일부를 SwiftUI에서는 선언적인 형태로 표현한다고 이해할 수 있다.

특히 주목해야 할 부분은 다음 선언이다.

```swift
var body: some Scene
```

`App`의 `body`는 `View`가 아니라 **`Scene`을 반환한다.** 따라서 `ContentView`를 `App`이 곧바로 반환하는 것이 아니라, `WindowGroup` 같은 Scene 안에 배치한다.

---

## 4. `Scene`: 하나의 UI 세션 또는 실행 단위

`Scene`은 처음 접할 때 혼동하기 쉬운 개념이다. 실용적인 mental model은 다음과 같다.

> Scene은 사용자에게 보여줄 수 있는 하나의 UI 인스턴스 또는 UI 세션을 정의하는 단위다.

예를 들어 macOS에서는 같은 앱의 창을 여러 개 열 수 있다.

```text
MyApp
 │
 ├── Window 1
 │    └── ContentView
 │
 ├── Window 2
 │    └── ContentView
 │
 └── Window 3
      └── ContentView
```

각 창은 독립적인 UI 상태와 생명주기를 가질 수 있다. iPadOS에서도 앱이 여러 window/scene을 가질 수 있으며, macOS와 visionOS에서는 이 개념이 더욱 분명하게 드러난다.

따라서 SwiftUI 앱을 단순히 다음처럼 이해하면 부족하다.

```text
App = 화면 하나
```

대신 다음과 같이 이해하는 것이 좋다.

```text
App
 └── Scene
      └── UI
```

`Scene`은 프로토콜이다.

```swift
public protocol Scene
```

일반적으로 개발자가 Scene 프로토콜을 직접 구현하기보다는 Apple이 제공하는 구체적인 Scene 타입을 사용한다. 대표적인 예는 다음과 같다.

- `WindowGroup`
- `DocumentGroup`
- `Window`
- `Settings`
- `MenuBarExtra`

---

## 5. `WindowGroup`: 일반 앱에서 가장 흔한 Scene

일반적인 iPhone 앱에서 가장 자주 사용하는 Scene은 `WindowGroup`이다.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`WindowGroup`은 **하나 이상의 Window를 관리하는 Scene**이다.

```text
MyApp
  │
  │ body
  ▼
WindowGroup
  │
  ▼
ContentView
  │
  ├── HeaderView
  ├── MainView
  └── BottomTabView
```

다음 두 타입의 역할은 명확히 다르다.

```text
WindowGroup : Scene
ContentView : View
```

따라서 이렇게 질문을 나누면 이해하기 쉽다.

```text
App
 │
 │ “내 앱에는 어떤 Scene들이 있는가?”
 ▼
Scene
 │
 │ “이 Scene에는 어떤 UI가 있는가?”
 ▼
View
```

### 왜 `Window`가 아니라 `WindowGroup`인가?

iPhone만 개발하면 보통 앱을 실행했을 때 화면 하나만 보이므로 단순히 `Window`라고 불러도 될 것처럼 느껴진다. 하지만 Apple 플랫폼에서는 하나의 앱이 여러 Window를 가질 수 있다. 특히 macOS, iPadOS, visionOS에서 중요하다.

```text
WindowGroup
   │
   ├── Window A
   │     └── ContentView
   │
   └── Window B
         └── ContentView
```

`WindowGroup`은 **동일한 구조를 가진 Window들의 그룹을 선언**한다.

```swift
WindowGroup {
    ContentView()
}
```

이를 개념적으로 풀면 다음과 가깝다.

> 사용자가 새로운 Window를 만들면 그 Window의 루트 콘텐츠로 `ContentView`를 만들어라.

iPhone에서는 대부분 Window 하나만 사용하므로 그룹이라는 특성이 눈에 잘 띄지 않을 뿐이다.

---

## 6. `Window`: 앱 UI를 담는 컨테이너

Window는 물리적인 디바이스 화면 자체와 다르다. 앱의 UI를 담는 컨테이너로 이해하면 된다.

```text
Device Screen
┌─────────────────────────────┐
│                             │
│        SwiftUI Window       │
│                             │
│        ContentView          │
│                             │
└─────────────────────────────┘
```

UIKit을 알고 있다면 `UIWindow`와 연결해 생각할 수 있다. 다만 SwiftUI의 일반적인 앱에서는 `UIWindow`를 직접 만들고 생명주기를 관리할 필요가 없다.

```swift
WindowGroup {
    ContentView()
}
```

이렇게 원하는 구조를 선언하면 시스템이 실제 Window와 그 생명주기를 관리한다.

여기서 `WindowGroup`은 여러 인스턴스를 허용하는 같은 종류의 창을 표현하는 데 적합하다. 반면 SwiftUI의 `Window` Scene은, 이를 지원하는 플랫폼에서 특정 목적의 고유한 창 하나를 선언할 때 사용할 수 있다. 대화의 핵심 범위에서는 둘의 구분을 다음처럼 기억하면 충분하다.

```text
WindowGroup = 같은 구조의 창 인스턴스들을 관리하는 Scene
Window      = 특정 목적의 개별 창을 나타내는 Scene
```

---

## 7. `DocumentGroup`: 문서 기반 앱을 위한 Scene

`DocumentGroup`도 `WindowGroup`과 마찬가지로 **Scene의 한 종류**지만 목적이 다르다.

`WindowGroup`은 다음과 같은 일반 애플리케이션에 적합하다.

- 소셜 미디어 앱
- 전화 앱
- 쇼핑 앱
- 은행 앱
- 메신저

반면 `DocumentGroup`은 **문서 기반 애플리케이션(document-based app)**을 만들기 위한 Scene이다.

- 텍스트 에디터
- 드로잉 앱
- Markdown 에디터
- 각종 문서 편집 프로그램

개념적인 구조는 다음과 같다.

```text
App
 └── DocumentGroup
       │
       ├── Document A
       │      └── EditorView
       │
       ├── Document B
       │      └── EditorView
       │
       └── Document C
              └── EditorView
```

### `DocumentGroup` 예제

텍스트 문서를 편집하는 앱은 다음과 같은 형태로 구성할 수 있다.

```swift
@main
struct TextEditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
```

일반 앱과 문서 기반 앱을 비교하면 차이가 잘 보인다.

```text
일반 앱

App
 ↓
WindowGroup
 ↓
ContentView
```

```text
문서 기반 앱

App
 ↓
DocumentGroup
 ↓
Document
 ↓
ContentView / EditorView
```

`DocumentGroup`은 문서 생성, 열기, 저장과 같은 document lifecycle을 SwiftUI 시스템과 통합한다. 따라서 개발자가 다음 기능을 모두 처음부터 직접 구축해야 하는 부담을 줄여 준다.

- 파일 선택
- 파일 열기
- 문서 상태 관리
- 저장
- 자동 저장(autosave)

---

## 8. `Scene`과 `View`의 차이

SwiftUI를 처음 배울 때 가장 자주 섞이는 개념 중 하나가 `Scene`과 `View`다.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

이 코드에는 서로 다른 두 계층이 있다.

```text
Application hierarchy

MyApp                  ← App
  │
  ▼
WindowGroup            ← Scene
  │
  ▼
ContentView            ← View
  │
  ├── NavigationStack  ← View
  │     │
  │     └── HomeView   ← View
  │
  └── TabView          ← View
```

| 개념 | 역할 | 예 |
|---|---|---|
| `App` | 애플리케이션 전체와 진입점 정의 | `MyApp` |
| `Scene` | UI 세션 및 Window 구조 정의 | `WindowGroup`, `DocumentGroup`, `Window`, `Settings` |
| `View` | 실제 화면과 UI 트리 구성 | `ContentView`, `Text`, `List`, `NavigationStack` |

Scene은 창과 세션의 경계를 정하고, View는 그 안에 표시될 화면을 구성한다.

---

## 9. 하나의 `App`에는 여러 `Scene`이 올 수 있다

`App`이 Scene 하나만 가져야 하는 것은 아니다. 예를 들어 macOS 앱에서는 메인 창과 설정 화면을 별도의 Scene으로 선언할 수 있다.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}
```

```text
MyApp
 │
 ├── WindowGroup
 │      └── ContentView
 │
 └── Settings
        └── SettingsView
```

더 복잡한 앱에서는 다음과 같은 구성도 가능하다.

```text
App
│
├── Main Window Scene
│      └── MainView
│
├── Secondary Window Scene
│      └── DetailView
│
└── Settings Scene
       └── SettingsView
```

즉, `App.body`의 `some Scene`은 “Scene 하나만 쓴다”는 뜻이 아니다. Swift의 result builder를 통해 여러 Scene 선언을 하나의 Scene 구성으로 묶을 수 있다.

---

## 10. UIKit과 SwiftUI 비교

UIKit 경험이 있다면 다음 대응 관계가 출발점이 될 수 있다.

```text
UIKit
────────────────────────────

UIApplication
      │
      ▼
UIScene
      │
      ▼
UIWindow
      │
      ▼
UIViewController
      │
      ▼
UIView
```

SwiftUI에서는 다음과 같은 구조로 볼 수 있다.

```text
SwiftUI
────────────────────────────

App
 │
 ▼
Scene
 │
 ▼
WindowGroup / Window / DocumentGroup
 │
 ▼
View
 │
 ▼
View
```

다만 이것은 이해를 돕기 위한 **대략적인 연결**이지 엄밀한 1:1 대응은 아니다.

| UIKit 쪽 개념 | SwiftUI에서 연결해 볼 개념 | 주의점 |
|---|---|---|
| `UIApplication`, `AppDelegate` | `App` 및 SwiftUI 생명주기 | 역할이 정확히 같지는 않다. |
| `UIScene`, `SceneDelegate` | `Scene` | SwiftUI에서는 구조를 선언하는 방식이 중심이다. |
| `UIWindow` | `WindowGroup` 또는 `Window`가 관리하는 실제 창 | `WindowGroup` 자체가 `UIWindow`는 아니다. |
| `UIViewController`와 `UIView` 계층 | SwiftUI `View` 트리 | SwiftUI View는 선언적 값 타입 중심이며 UIView와 동일하지 않다. |

가장 큰 관점의 차이는 다음과 같다.

### UIKit의 전형적인 관점

- 생명주기 객체를 직접 다룬다.
- 객체를 생성하고 서로 연결한다.
- 상태 변화에 따라 UI를 명령형으로 갱신하는 경우가 많다.

### SwiftUI의 관점

- 원하는 앱, Scene, View의 구조를 선언한다.
- 상태가 바뀌면 그 상태에 맞는 UI를 다시 기술한다.
- 시스템이 실제 Window와 렌더링 및 생명주기의 많은 부분을 관리한다.

```swift
WindowGroup {
    ContentView()
}
```

이 코드는 실제 Window 객체를 직접 생성하고 연결하는 절차보다, **앱이 제공해야 할 UI 구조를 선언하는 표현**에 가깝다.

---

## 11. 두 종류의 “SwiftUI 아키텍처”를 구분하라

이 대화에서 가장 중요한 확장 포인트는 “SwiftUI 아키텍처”라는 말이 서로 다른 두 층을 가리킬 수 있다는 점이다.

### 11.1 SwiftUI 프레임워크의 Application Architecture

```text
App
 ↓
Scene
 ↓
WindowGroup / DocumentGroup / Window
 ↓
View Tree
```

이 계층은 SwiftUI 프레임워크 자체가 앱의 시작, UI 세션, 창, 화면을 어떻게 조직하는지에 관한 것이다.

### 11.2 개발자가 설계하는 앱 내부 Architecture

```text
View
 ↓ user action
ViewModel / Store / Feature
 ↓
UseCase / Service
 ↓
Repository
 ↓
API / DB / System Framework
```

이 계층은 비즈니스 로직, 상태, 데이터 접근, 의존성, 테스트 가능성을 개발자가 어떻게 나눌지에 관한 것이다.

다음 용어들은 주로 두 번째 계층에 속한다.

- MVVM
- MVI
- TCA(The Composable Architecture)
- Clean Architecture
- Repository Pattern
- Coordinator
- Dependency Injection

따라서 `App`, `Scene`, `WindowGroup`을 이해하는 것과 MVVM을 적용하는 것은 서로 경쟁하는 선택지가 아니다. 전자는 SwiftUI 앱의 바깥 골격이고, 후자는 그 안의 상태와 기능을 조직하는 설계 방식이다.

---

## 12. 핵심 mental model

### Mental model 1: 앱은 화면 하나가 아니다

```text
잘못 축약한 생각
App = ContentView

권장하는 생각
App → Scene → Window → View Tree
```

### Mental model 2: `WindowGroup`은 View가 아니다

```text
WindowGroup : Scene
ContentView : View
```

`WindowGroup`은 창들이 어떤 콘텐츠를 루트로 사용할지 선언하고, `ContentView`는 실제 화면 트리를 만든다.

### Mental model 3: Scene은 UI 세션의 경계다

하나의 앱에 여러 Scene과 여러 Window가 존재할 수 있다. 각 Window는 독립된 상태와 생명주기를 가질 수 있다.

### Mental model 4: SwiftUI는 구조를 선언한다

개발자가 “Window를 만들고 여기에 View를 넣어라”라는 절차를 하나씩 수행하기보다 다음처럼 원하는 결과 구조를 선언한다.

```swift
WindowGroup {
    ContentView()
}
```

시스템은 이 선언을 바탕으로 실제 창과 생명주기를 관리한다.

### Mental model 5: 문서가 앱의 중심이면 `DocumentGroup`

일반적인 앱의 중심은 앱 UI이므로 보통 `WindowGroup`을 사용한다. 파일 문서의 생성, 열기, 편집, 저장이 앱 경험의 중심이면 `DocumentGroup`이 적합하다.

### Mental model 6: 프레임워크 구조와 내부 설계 패턴을 분리한다

```text
프레임워크가 제공하는 골격
App → Scene → Window → View

개발자가 선택하는 내부 설계
View → ViewModel/Store → UseCase → Repository → 외부 시스템
```

이 둘을 분리해서 이해하면 MVVM이나 TCA를 도입할 때 각각이 어느 문제를 해결하는지 명확해진다.

---

## 13. 예제를 한 번에 읽기

### 13.1 가장 단순한 일반 앱

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Hello, SwiftUI!")
    }
}
```

읽는 순서:

1. `@main`인 `MyApp`이 앱의 진입점이다.
2. `MyApp.body`는 Scene 구성을 반환한다.
3. `WindowGroup`은 같은 구조를 가진 창들을 관리한다.
4. 각 창의 루트 콘텐츠는 `ContentView`다.
5. `ContentView.body`부터 실제 View 트리가 시작된다.

### 13.2 메인 창과 설정 Scene이 있는 앱

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}
```

이 앱은 하나의 App 안에서 메인 Window Scene과 설정 Scene을 함께 선언한다.

### 13.3 문서 기반 앱

```swift
import SwiftUI

@main
struct TextEditorApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
```

여기서는 일반 앱의 고정된 루트 화면보다 각 문서와 연결된 편집 화면이 중심이다. `file.$document`는 편집 중인 문서를 View에 바인딩해 문서의 변경 사항이 UI와 연결되도록 한다.

---

## 14. 다음 학습 순서

대화에서 권장한 다음 학습 흐름은 다음과 같다.

```text
View
 ↓
State
 ↓
Binding
 ↓
Environment
 ↓
Observation
 ↓
View lifecycle
 ↓
Scene lifecycle
```

그 다음 앱 규모가 커질 때 아래 주제로 확장하는 것이 자연스럽다.

```text
Feature 분리
 ↓
ViewModel / Store와 단방향 데이터 흐름
 ↓
Dependency Injection
 ↓
Navigation
 ↓
UseCase / Service / Repository
 ↓
테스트 구조
```

이 순서를 따르면 MVVM이나 TCA를 단순한 폴더 구조나 유행하는 패턴으로 암기하지 않고, SwiftUI의 상태 흐름과 생명주기에서 출발해 “왜 이런 설계가 필요한가”를 이해할 수 있다.

---

## 15. 최종 요약

```text
@main App
   │
   ├── WindowGroup ── 일반적인 앱과 여러 창 인스턴스
   │       └── View Tree
   │
   ├── DocumentGroup ── 문서 생성·열기·저장 중심 앱
   │       └── Document-bound View Tree
   │
   ├── Window ── 특정 목적의 개별 창
   │       └── View Tree
   │
   └── Settings 등 다른 Scene
           └── View Tree
```

- `App`은 앱의 진입점이자 최상위 선언이다.
- `App.body`는 `View`가 아니라 `Scene`을 반환한다.
- `Scene`은 UI 세션과 Window 구조를 정의한다.
- `WindowGroup`, `DocumentGroup`, `Window`, `Settings`는 Scene의 종류다.
- `View`는 Scene 안에서 실제 화면을 구성한다.
- `WindowGroup`은 같은 구조의 하나 이상의 Window를 관리한다.
- `DocumentGroup`은 문서의 생성, 열기, 편집, 저장 생명주기를 앱에 통합한다.
- UIKit과 SwiftUI의 개념은 대략 연결할 수 있지만 1:1 대응은 아니다.
- SwiftUI는 객체를 직접 조립하는 절차보다 원하는 App–Scene–View 구조를 선언하는 방식에 가깝다.
- 이 프레임워크 골격과 MVVM, TCA, Clean Architecture 같은 앱 내부 설계는 서로 다른 레이어다.

한 문장으로 압축하면 다음과 같다.

> SwiftUI 앱은 `App`이 하나 이상의 `Scene`을 선언하고, 각 Scene이 Window 또는 문서 세션을 제공하며, 그 안의 `View` 트리가 실제 화면을 구성하는 선언적 구조다.
