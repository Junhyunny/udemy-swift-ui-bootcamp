# SwiftUI 화면은 언제 살아 있고, `.task`는 언제 끝날까?

뉴스 상세 화면을 열어 둔 채 기기를 회전한다. 뒤로 가기 스와이프를 절반쯤 했다가 손을 되돌린다. 다시 스와이프해 목록으로 돌아온다. 이 과정에서 `onAppear`, `onDisappear`, `.task`는 각각 몇 번 실행될까?

한 줄로 외울 수 있는 호출 순서는 없다. SwiftUI에서는 **뷰 값의 생성**, **화면 계층에서의 등장**, **scene의 활성 상태**, **비동기 작업의 취소**가 서로 다른 사건이기 때문이다. 이 차이를 먼저 이해하면 화면 전환에서 생기는 중복 요청과 상태 초기화를 설명할 수 있다. 이 글은 [chapter-32의 `onAppear`](../chapter-32/chapter-32/ContentView.swift)와 [chapter-61의 `.task`·`Task { }`](../chapter-61/chapter-61/ContentView.swift)에서 시작한다.

## 먼저 구분할 것: App, Scene, View, 그리고 뷰의 식별성

```text
App (@main)
 └─ Scene (WindowGroup의 창 등)
     └─ View (화면을 구성하는 요소)
```

`App`은 앱의 진입점이다. `Scene`은 창이나 화면의 활성 상태를 가진다. `View`는 UI를 설명하는 값이며 상태 변화에 따라 `body`가 다시 평가되거나 View 값이 다시 만들어질 수 있다. UIKit의 `UIViewController`처럼 `viewDidLoad`부터 `viewDidDisappear`까지 메서드를 순서대로 재정의하는 모델이 아니다. Apple의 [View 생명주기 API 목록](https://developer.apple.com/documentation/SwiftUI/View-Input-and-Events)에는 `onAppear`, `onDisappear`, `onChange`, `.task` 계열이 있다.

다음 네 가지를 같은 사건으로 취급하면 안 된다.

| 일어난 일 | 뜻 |
| --- | --- |
| `body`가 다시 평가됨 | UI 설명을 다시 계산함. 화면이 퇴장했다는 뜻은 아님 |
| View 값이 다시 만들어짐 | 구조체 값이 새로 생김. 저장된 뷰 상태가 반드시 초기화되지는 않음 |
| 뷰의 식별성이 바뀜 | 그 뷰에 연결된 `@State` 등이 초기화될 수 있음 |
| 뷰가 나타나거나 사라짐 | `onAppear`·`onDisappear`와 `.task`의 실행·취소에 관계됨 |

`@State`는 View 구조체의 한 인스턴스에 단순히 저장되는 값이 아니다. SwiftUI가 뷰의 식별성에 연결해 관리한다. 그래서 같은 식별성이 유지되면 View 값이 다시 만들어져도 상태는 이어질 수 있다. 반대로 `.id(value)`의 값이 바뀌면 뷰의 식별성과 상태가 초기화된다. `@StateObject`도 자신을 소유한 뷰의 식별성이 바뀌면 다시 생성될 수 있다.

```swift
// body가 평가될 때마다 새 ID가 생겨 상태가 계속 초기화될 수 있다.
EditorView()
    .id(UUID())
```

`body`나 View의 `init`에서 네트워크 요청·타이머 등록·분석 이벤트 전송을 시작하지 않는 이유가 여기에 있다. 앱 전체에서 오래 유지할 모델은 안정적인 상위 소유자에, 화면 안에서만 필요한 임시 상태는 해당 View의 `@State`에 둔다. [상태와 식별성에 관한 Apple 설명](https://developer.apple.com/documentation/swiftui/stateobject)도 이 차이를 강조한다.

## 뷰가 나타나고 사라질 때: `onAppear`와 `onDisappear`

```swift
Text("Detail")
    .onAppear { print("나타남") }
    .onDisappear { print("사라짐") }
```

`onAppear`는 해당 뷰가 표시되기 전에 동기 액션을 실행한다. 정확한 순간은 뷰 종류에 따라 다르지만 액션은 첫 프레임 전에 끝난다. `onDisappear`는 표시가 끝난 뒤 동기 액션을 실행한다. 따라서 `onAppear`에서 오래 걸리는 일을 하면 첫 화면 표시가 늦어질 수 있다. 두 클로저 안에는 `await`을 직접 쓸 수 없다.

두 modifier는 **한 번만 실행되는 초기화·종료 지점이 아니다.** 상세 화면에 다시 들어오거나 `List`·`LazyVStack`의 행을 스크롤하면 다시 호출될 수 있다. `Group`에 modifier를 붙이면 그룹 자체가 하나의 화면 생명주기를 얻는 것이 아니라 멤버에 적용된다. 또한 앱을 홈으로 보냈다고 뷰가 반드시 사라지지는 않는다.

여기까지는 “뷰에 동기적으로 반응하기”다. 뉴스를 불러오는 것처럼 `await`이 필요한 작업은 다음 단계로 넘어간다.

## 비동기 작업을 뷰에 붙이기: `.task`

[chapter-61](../chapter-61/chapter-61/ContentView.swift)은 현재 `.task` 안에서 로그만 찍고 뉴스 요청은 주석으로 남겨 두었다. 요청을 그 자리에 넣으면 다음 모양이다.

```swift
.task {
    print(await News.fetchNews())
}
```

`.task`는 뷰가 나타나기 전에 `async` 액션을 시작할 수 있다. 액션이 완료되기 전에 뷰가 사라지면 SwiftUI가 취소를 요청할 수 있다. `onAppear`와 `.task`는 둘 다 등장에 반응하고 재등장 때 다시 실행될 수 있지만, 정확한 실행 순서가 정해진 한 쌍의 콜백은 아니다. `onDisappear`와 취소 신호의 순서도 고정해서 가정하지 않는다.

| | `onAppear` / `onDisappear` | `.task` |
| --- | --- | --- |
| 전달하는 코드 | 동기 클로저 | `async` 클로저 |
| 알맞은 일 | 짧은 등장·퇴장 반응 | 로딩, 비동기 구독 |
| 재실행 | 재등장에 따라 가능 | 재등장에 따라 가능 |
| 비동기 취소 | 직접 만든 작업은 직접 관리 | SwiftUI가 연결된 작업에 취소 요청 가능 |
| 값 변경에 따른 재시작 | 별도 코드 필요 | `.task(id:)` |

`.task`의 기본 priority는 `.userInitiated`다. 바로 표시하지 않을 준비 작업에는 `.task(priority: .background)`를 검토할 수 있다. 우선순위의 의미는 [TaskPriority 문서](./104-task-priority-and-scheduling.md)에 있다.

### `onAppear { Task { } }`가 같은 뜻은 아니다

```swift
.onAppear {
    Task { await loadNews() }
}
```

`onAppear`가 동기 클로저이기 때문에 이 코드는 새 `Task`를 만든다. `Task { }`는 Swift의 비구조적 작업이며, **뷰가 사라졌다는 이유만으로 취소되지 않는다.** 작업 핸들을 버리면 취소하거나 결과를 기다릴 수단도 잃는다. 뷰에 소속된 로딩이라면 보통 다음처럼 쓴다.

```swift
.task { await loadNews() }
```

버튼 액션이나 동기 델리게이트에서 비동기 함수를 호출할 때는 `Task { }`가 유용하다. 직접 수명을 관리해야 한다면 핸들을 보관하고 이전 작업을 취소한다.

```swift
@State private var loadTask: Task<Void, Never>?

func startLoading() {
    loadTask?.cancel()
    loadTask = Task { await loadNews() }
}
```

`.task` **안에서** 다시 `Task { }`를 만들면 안쪽 작업은 별개의 비구조적 작업이다. 바깥 작업이 취소돼도 안쪽으로 취소가 자동 전달되지 않는다. [액터 문서](./153-swift-actor-complete-guide.md)의 네트워크 사례도 이 문제를 다룬다. 화면을 떠나도 끝내야 하는 업로드라면 화면 밖의 소유자와 취소 정책을 정한다. `Task.detached`는 현재 액터 문맥을 상속하지 않으므로 “오래 실행해야 한다”는 이유만으로 선택하지 않는다.

### 값이 바뀌면 이전 요청을 바꾸기: `.task(id:)`

카테고리 A를 불러오는 중 사용자가 B를 선택했다면, A의 응답이 나중에 도착해 B 화면을 덮을 수 있다. `.task(id:)`는 뷰가 나타날 때 실행하고, `Equatable`인 `id`가 바뀌면 이전 작업에 취소를 요청한 뒤 새 작업을 시작한다.

```swift
.task(id: selectedCategory) {
    let category = selectedCategory
    let result = await fetchArticles(category: category)
    guard !Task.isCancelled, category == selectedCategory else { return }
    articles = result
}
```

취소 요청만으로 오래된 요청이 강제로 멈추지는 않는다. 비동기 함수가 취소에 협조해야 낭비되는 작업이 줄고, 결과를 적용하기 전의 검사로 오래된 응답을 막을 수 있다. 검색어나 필터처럼 빠르게 바뀌는 값에 같은 원칙을 적용한다.

### 취소는 중단 요청이다

Swift의 작업 취소는 협조적이다. 오래 도는 루프가 취소를 확인하지 않으면 계속 실행할 수 있다.

```swift
.task {
    for item in items {
        guard !Task.isCancelled else { return }
        process(item)
    }
}
```

`Task.sleep`처럼 취소에 반응하는 API는 오류를 던질 수 있다. `try? await Task.sleep(...)`으로 오류를 버린 뒤 상태를 바꾸면 **취소 후에도** 상태 변경이 일어날 수 있다. 반복 루프에서 같은 오류를 삼키면 빠른 반복까지 생길 수 있다.

```swift
.task {
    do {
        try await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        isPresented = false
    } catch is CancellationError {
        return
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

네트워크 취소가 항상 `CancellationError`라는 타입으로만 전달된다고 가정하지 않는다. 요청의 `catch`에서 `Task.isCancelled`도 확인해 취소와 실제 실패를 구분한다. `for await` 이벤트 구독이나 타이머 루프도 뷰와 연결할 수 있지만, 시퀀스와 루프가 취소에 반응하는지 확인해야 한다.

```swift
.task {
    for await event in client.events {
        guard !Task.isCancelled else { return }
        handle(event)
    }
}
```

주기적인 UI 갱신은 `onReceive`나 `TimelineView`가 더 알맞을 수도 있다([타이머 문서](./110-timer-publisher-and-onreceive.md)). `Task.sleep`을 직접 반복한다면 취소 오류에서 루프를 끝내고, 대기 뒤에도 취소 상태를 확인한다.

```swift
.task {
    while !Task.isCancelled {
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        updateTimer()
    }
}
```

## “화면에 보인다”는 하나의 사건이 아니다

뷰의 등장 외에도 앱·scene·표시 방식마다 관찰할 사건이 다르다.

| 알고 싶은 것 | 사용할 API |
| --- | --- |
| 앱 생성 시 초기 설정 | `App.init()` |
| scene의 활성·비활성·백그라운드 전환 | `@Environment(\.scenePhase)` + `onChange` |
| 값의 변화, 또는 처음 등장했을 때의 초기 반응 | `onChange(of:initial:)` |
| Combine publisher의 값 | `onReceive` |
| 스크롤 영역 안에서 실제로 보이는 정도 | `onScrollVisibilityChange` |
| 시트·전체 화면 표시가 닫힘 | `sheet`·`fullScreenCover`의 `onDismiss` |
| URL·Handoff 활동이 scene에 전달됨 | `onOpenURL`·`onContinueUserActivity` |
| 시스템이 백그라운드 작업을 제공함 | Scene의 `backgroundTask` |

### 앱이 뒤로 갔는가: `scenePhase`

`scenePhase`의 `.active`는 전면에서 상호작용하는 상태, `.inactive`는 전면에 있지만 작업을 잠시 멈춰야 하는 상태, `.background`는 UI에 보이지 않는 상태다. View 안에서 읽으면 소속 scene의 값이고, `App`에서 읽으면 여러 scene을 종합한 값이다. 홈으로 나가도 뷰 자체는 남을 수 있으므로 저장·재생 중지처럼 앱 상태에 반응할 일은 여기를 관찰한다.

```swift
@Environment(\.scenePhase) private var scenePhase

var body: some View {
    ContentView()
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { saveDraft() }
        }
}
```

`onDisappear`를 앱 종료 콜백으로 쓰지 않는다. 반대로 `scenePhase`가 바뀌었다고 뷰의 `.task`가 취소된다고 가정하지도 않는다. `backgroundTask(_:action:)`는 시스템이 특정 백그라운드 작업을 제공했을 때 Scene에서 실행하는 별도 API이지, 백그라운드 진입 때마다 실행되는 일반 콜백이 아니다.

### 무엇이 바뀌었는가: `onChange`와 `onReceive`

`onChange(of:initial:)`는 `Equatable` 값의 변화를 관찰한다. `initial: true`를 주면 첫 등장에도 액션을 실행한다. `onReceive`는 Combine publisher가 값을 보낼 때 실행한다. 둘 다 이전 비동기 요청을 `.task(id:)`처럼 취소하지 않는다.

```swift
.onChange(of: selectedID, initial: true) { _, newID in
    updateSelection(newID)
}
.onReceive(NotificationCenter.default.publisher(for: Notification.Name("ExampleEvent"))) { _ in
    refreshBadge()
}
```

`onGeometryChange`는 뷰의 크기·위치에서 뽑은 값이 바뀔 때 실행한다([화면 크기 문서](./070-uiscreen-main-deprecated.md)). 스크롤 중에는 기하 값이 자주 달라지므로 필요한 값만 추출한다. `onScrollPhaseChange`와 `onScrollGeometryChange`도 스크롤 상태·기하를 관찰하는 API이며 뷰의 등장 콜백은 아니다.

### 실제로 화면에 보이는가: 스크롤 가시성

`onAppear`는 행이 스크롤 영역에 몇 퍼센트 보이는지를 알려 주지 않는다. 동영상 자동 재생처럼 뷰포트 노출이 중요하면 iOS 18부터 제공하는 `onScrollVisibilityChange(threshold:_:)`를 쓴다. 기본 임계값은 0.5다. 여러 행의 ID를 함께 관찰할 때는 `scrollTargetLayout()`과 `onScrollTargetVisibilityChange(idType:threshold:_:)`를 쓴다([스크롤 위치 문서](./081-scroll-position-binding.md)).

```swift
VideoPlayer(player: player)
    .onScrollVisibilityChange(threshold: 0.2) { isVisible in
        if isVisible { player.play() } else { player.pause() }
    }
```

### 표시가 닫혔는가: `onDismiss`

시트를 열 때 필요한 일은 시트 **내용**의 `onAppear` 또는 `.task`에 둔다. 닫힌 뒤 상위 화면에서 할 일은 `sheet`나 `fullScreenCover`의 `onDismiss`에 둔다. 아래 화면이 시트에 가려졌다고 그 뷰의 `onDisappear`가 반드시 실행되는 것은 아니다.

```swift
.sheet(isPresented: $isPresented, onDismiss: { reloadSummary() }) {
    CheckoutView(cart: cart)
        .task { await loadCheckoutData() }
}
```

시트를 반쯤 끌어내렸다 되돌리는 제스처도 있다. 닫힘 결과는 표시 바인딩과 `onDismiss`로 판단하고, 입력을 반드시 끝내야 한다면 `interactiveDismissDisabled`를 검토한다([시트 문서](./080-sheet-ondismiss-and-result.md)). `onOpenURL`과 `onContinueUserActivity`는 URL·Handoff로 들어오는 **외부 사건**을 받는다. 이미 열린 scene에서 실행될 수도 있으므로 `onAppear`의 대체재가 아니다([URL 문서](./086-url-scheme-resolution-and-conflicts.md)).

## 이제 실제 전환에 대입해 보기

### 회전은 화면 퇴장인가?

Android의 Activity 재생성 모델을 SwiftUI View에 그대로 대입하면 안 된다. iPhone 회전과 iPad 창 크기 변경은 레이아웃·환경값을 바꾸고 `body`를 다시 평가할 수 있지만, **회전 자체가 `onDisappear` 다음 `onAppear`를 반드시 호출하는 사건은 아니다.** 같은 식별성이 유지되면 `@State`도 이어진다.

다만 크기에 따라 서로 다른 뷰를 만들거나 `.id`를 방향에 묶으면 식별성이 바뀔 수 있다.

```swift
if horizontalSizeClass == .compact {
    CompactEditor(draft: $draft)
} else {
    WideEditor(draft: $draft)
}
```

편집 초안은 두 분기보다 위의 안정적인 소유자에 둔다. `horizontalSizeClass`는 기기 회전뿐 아니라 iPad 멀티태스킹에 따라서도 달라질 수 있다. 회전 시험에서는 `body` 평가, View 생성, 상태 초기화, `onAppear`를 각각 따로 기록한다.

### 뒤로 가기 스와이프를 중간에 취소하면?

`NavigationStack`은 뒤로 버튼뿐 아니라 스와이프로도 이전 화면으로 돌아갈 수 있다. 사용자가 반쯤 밀고 되돌리면 이전 화면이 잠깐 보이더라도 전환은 취소된다. UIKit에는 대화형 전환의 취소 여부를 확인하는 API가 있다. 반면 SwiftUI의 `onAppear`·`onDisappear` 문서에는 그 제스처 중 콜백의 호출 횟수와 순서가 규정되어 있지 않다. 취소된 제스처가 반드시 `onDisappear`를 부른다는 뜻은 아니다.

따라서 상세 화면의 `onDisappear`를 “뒤로 이동 완료”로 해석해 결제·삭제·로그아웃을 수행하지 않는다. 확정된 사용자 동작은 버튼 액션에서 처리한다. 탐색 결과가 필요하다면 `NavigationStack(path:)`의 경로나 `navigationDestination(isPresented:)`의 바인딩을 관찰한다. 기본 `NavigationLink(destination:)`는 경로 상태를 앱에 직접 노출하지 않는다.

```swift
@State private var path: [Route] = []

NavigationStack(path: $path) {
    RouteList()
        .navigationDestination(for: Route.self) { route in
            RouteDetail(route: route)
        }
}
.onChange(of: path) { oldPath, newPath in
    recordNavigationChange(from: oldPath, to: newPath)
}
```

경로 변경은 **현재 탐색 상태**를 알려 준다. 제스처 진행률이나 애니메이션이 끝난 정확한 시각을 알려 주는 콜백은 아니다. 다음 로그를 임시로 붙이고, 스와이프 취소·완료·뒤로 버튼을 각각 시험한다. 실제 콜백 순서는 iOS 버전, 화면 컨테이너, modifier의 위치에 따라 확인한다.

```swift
.onAppear { print("Detail onAppear") }
.onDisappear { print("Detail onDisappear") }
.task {
    print("Detail task start")
    defer { print("Detail task end, cancelled:", Task.isCancelled) }
    do {
        try await Task.sleep(for: .seconds(10))
    } catch {
        return
    }
}
```

### 탭 복귀, 행 재사용, 백그라운드

| 상황 | 흔한 오해 | 확인할 상태 |
| --- | --- | --- |
| 탭을 바꿨다가 복귀 | `onAppear`는 최초 한 번뿐이다 | 복귀 때 다시 실행될 수 있다. 현재 탭은 `TabView(selection:)`으로 판단 |
| `List`를 스크롤 | 행의 `onAppear`는 정확한 픽셀 노출 신호다 | 행의 등장과 뷰포트 가시성을 구분 |
| 목록을 정렬·필터링 | 인덱스를 안정적인 행 ID로 써도 된다 | 항목 고유 ID를 유지해야 상태와 작업이 엉뚱한 행에 붙지 않음 |
| 홈으로 나감 | `onDisappear`가 앱 정리 작업을 해 준다 | `scenePhase`를 관찰 |
| 시트가 아래 화면을 덮음 | 아래 화면의 작업이 반드시 취소된다 | 시트와 아래 화면의 수명을 따로 판단 |

## 뉴스 화면에 적용하고 마무리하기

chapter-61의 현재 `fetchNews()`는 `onAppear`와 `refreshable`에서 호출되고, 내부에서 별도 `Task { }`를 만든다. 요청이 겹칠 수 있고 `refreshable`은 그 작업의 완료를 기다리지 못한다. `News.fetchNews()`는 현재 `News?`를 반환하며 빈 `catch { }`가 요청 실패와 취소를 모두 `nil`로 만든다.

실제 UI에서는 로딩·결과·실패를 구분한다. 아래는 `News.fetchNews()`를 **`async throws -> News`로 바꿨다고 가정한 개선 예시**다.

```swift
enum LoadState {
    case loading
    case loaded(News)
    case failed(String)
}

@State private var loadState: LoadState = .loading

var body: some View {
    NewsContent(state: loadState)
        .task { await loadNews() }
        .refreshable { await loadNews() }
}

func loadNews() async {
    loadState = .loading
    do {
        let result = try await News.fetchNews()
        guard !Task.isCancelled else { return }
        loadState = .loaded(result)
    } catch {
        guard !Task.isCancelled else { return }
        loadState = .failed(error.localizedDescription)
    }
}
```

`.task`가 등장 시 로딩하고, `.refreshable`은 사용자의 새로고침 요청을 직접 `await`한다. `.refreshable { Task { await loadNews() } }`처럼 새 작업을 만들고 바로 반환하면 표시가 실제 요청을 기다리지 못한다. 두 경로가 동시에 실행될 수 있으므로 중복 요청과 완료 순서는 별도로 관리해야 한다.

뷰의 생성자에서 무거운 초기값을 만드는 것도 비용을 따져야 한다. 한 화면에서만 필요한 객체를 등장 시 만들려면 옵셔널 상태에 보관하고 이미 만들었는지 확인할 수 있다.

```swift
@State private var library: Library?

var body: some View {
    LibraryView(library: library)
        .task {
            guard library == nil else { return }
            library = Library()
        }
}
```

이 코드는 `.task`의 실행 횟수를 한 번으로 보장하지 않는다. 같은 뷰의 상태가 남아 있는 동안 중복 생성을 피할 뿐이다. 앱 재실행 뒤에도 남아야 하는 데이터는 별도 영구 저장이 필요하다.

정리하면 **무엇이 바뀌었는지부터 묻는 것**이 안전하다. 뷰가 등장했는가, scene이 비활성화됐는가, 탐색 경로가 바뀌었는가, 스크롤 화면에 실제로 보이는가, 요청의 `id`가 바뀌었는가. 각각 다른 사건이며 같은 콜백 하나로 모두 처리할 수 없다.

### 직접 확인할 실험

- [ ] 같은 뷰에 `onAppear`, `onDisappear`, `.task` 로그를 붙이고 재등장과 탭 전환을 기록한다. 특정 순서를 정답으로 가정하지 않는다.
- [ ] `body` 평가, View 생성, `@State` 유지 여부를 기기 회전·iPad 창 크기 변경 때 각각 기록한다. 조건부 레이아웃과 `.id` 변경도 비교한다.
- [ ] 상세 화면에서 뒤로 가기 스와이프를 절반만 한 뒤 취소하고, 다시 완료한다. 콜백 로그와 탐색 경로를 따로 기록한다.
- [ ] 시트를 끌어내리다 되돌리고 실제로 닫아 `onDisappear`와 `onDismiss`를 비교한다.
- [ ] `List` 행에서 `onAppear`와 `onScrollVisibilityChange`를 비교하고, `Group`의 각 멤버도 관찰한다.
- [ ] `scenePhase`를 기록하며 앱을 홈으로 보냈다가 돌아와 `onDisappear`와 비교한다.
- [ ] `onChange(initial: true)`와 `onReceive`가 각각 언제 실행되는지 확인한다.
- [ ] `.task(id:)`의 값을 빠르게 바꾸고 오래된 응답이 현재 화면을 덮지 않는지 시험한다.
- [ ] `Task.sleep`의 취소 오류를 처리한 경우와 `try?`로 버린 경우를 비교한다. `Task.checkCancellation()`을 쓰는 루프도 시험한다.
- [ ] `onAppear { Task { ... } }`의 작업 핸들을 직접 취소하는 경우와 `.task`의 취소를 비교한다.
- [ ] `.refreshable`에서 작업을 바로 반환할 때와 직접 `await`할 때 표시 시간을 비교하고, 실패·취소 상태를 화면에 표시해 본다.

## 공식 참고 자료

- [Apple: View 생명주기 API 분류](https://developer.apple.com/documentation/SwiftUI/View-Input-and-Events)
- [Apple: View.onAppear(perform:)](https://developer.apple.com/documentation/swiftui/view/onappear(perform:))
- [Apple: View.onDisappear(perform:)](https://developer.apple.com/documentation/swiftui/view/ondisappear(perform:))
- [Apple: View.task](https://developer.apple.com/documentation/swiftui/view/task(name:priority:file:line:_:))
- [Apple: View.task(id:)](https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:))
- [Apple: Task and task cancellation](https://developer.apple.com/documentation/swift/task)
- [Apple: View.id(_:)](https://developer.apple.com/documentation/swiftui/view/id(_:))
- [Apple: StateObject](https://developer.apple.com/documentation/swiftui/stateobject)
- [Apple: Managing user interface state](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)
- [Apple: ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase)
- [Apple: EnvironmentValues.scenePhase](https://developer.apple.com/documentation/swiftui/environmentvalues/scenephase)
- [Apple: View.onChange(of:initial:_:)](https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:))
- [Apple: View.onReceive(_:perform:)](https://developer.apple.com/documentation/swiftui/view/onreceive(_:perform:))
- [Apple: View.onGeometryChange(for:of:action:)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:))
- [Apple: View.onScrollVisibilityChange(threshold:_:)](https://developer.apple.com/documentation/swiftui/view/onscrollvisibilitychange(threshold:_:))
- [Apple: View.onScrollTargetVisibilityChange(idType:threshold:_:)](https://developer.apple.com/documentation/swiftui/view/onscrolltargetvisibilitychange(idtype:threshold:_:))
- [Apple: Scroll views](https://developer.apple.com/documentation/swiftui/scroll-views)
- [Apple: View.sheet(isPresented:onDismiss:content:)](https://developer.apple.com/documentation/swiftui/view/sheet(isPresented:onDismiss:content:))
- [Apple: View.interactiveDismissDisabled(_:)](https://developer.apple.com/documentation/swiftui/view/interactivedismissdisabled(_:))
- [Apple: SwiftUI system events](https://developer.apple.com/documentation/swiftui/system-events)
- [Apple: Scene.backgroundTask(_:action:)](https://developer.apple.com/documentation/swiftui/scene/backgroundtask(_:action:))
- [Apple: NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack)
- [Apple: Understanding the navigation stack](https://developer.apple.com/documentation/swiftui/understanding-the-navigation-stack)
- [Apple: UIViewControllerTransitionCoordinator](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioncoordinator)
- [Apple: UIViewControllerTransitionCoordinator.notifyWhenInteractionChanges(_:)](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioncoordinator/notifywheninteractionchanges(_:))
- [Apple: UserInterfaceSizeClass](https://developer.apple.com/documentation/swiftui/userinterfacesizeclass)
- [Apple: Tab navigation](https://developer.apple.com/documentation/swiftui/enhancing-your-app-content-with-tab-navigation)
- [Apple: Group](https://developer.apple.com/documentation/swiftui/group)
- [Apple: View.refreshable(action:)](https://developer.apple.com/documentation/swiftui/view/refreshable(action:))
