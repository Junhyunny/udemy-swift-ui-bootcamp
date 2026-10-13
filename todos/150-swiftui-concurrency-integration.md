# 8단계 — SwiftUI와 연결하기

[로드맵](./142-swift-concurrency-roadmap.md)의 마지막 단계다. 1~7단계를 실제 화면에 연결한다.

관련 문서: [SwiftUI 화면 생명주기와 `.task`](./159-swiftui-view-and-task-lifecycle.md), [`Observation` 모듈과 `@Observable`](./050-observation-framework-and-observable.md), [상태 관리 래퍼 총정리](./049-state-wrapper-decision-guide.md)

## 전체 흐름

```text
SwiftUI View 등장
        │
        ▼
   .task { }                     ← 뷰 수명에 묶인 Task (3·8단계)
        │
        ▼
await viewModel.load()           ← 중단점 (1·2단계)
        │
        ▼
@MainActor ViewModel             ← 격리 (5·6단계)
        │
        ├─ isLoading = true      ← 메인 액터라 그냥 대입 가능
        ├─ await network         ← 중단, 스레드 반납
        └─ user = result         ← 다시 메인 액터
        │
        ▼
@Observable 변경 감지            ← 관찰 (050 문서)
        │
        ▼
View 다시 렌더링
```

**이 그림의 각 화살표가 앞 단계들에서 배운 개념이다.**

## ViewModel에 `@MainActor`를 붙인다

```swift
@MainActor
@Observable
final class UserViewModel {
    private(set) var isLoading = false
    private(set) var user: User?
    private let api: UserFetching

    init(api: UserFetching = APIClient.shared) { self.api = api }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        user = try? await api.fetchUser()
    }
}
```

포인트가 넷이다.

- **`@MainActor`를 타입 전체에** — 상태 대입마다 `MainActor.run`을 쓰지 않아도 된다
- **`@Observable`** — 변경 감지가 프로퍼티 단위로 이뤄진다 ([050 문서](./050-observation-framework-and-observable.md))
- **`private(set)`** — 상태 변경 경로를 메서드로 제한한다
- **의존성 주입** — 테스트에서 가짜 API를 넣을 수 있다 ([123 문서](./123-dependency-injection-for-testing.md))

`await api.fetchUser()`에서 중단되는 동안 메인 스레드는 풀려나 UI가 멈추지 않고, 재개되면 다시 메인 액터이므로 `user = ...`가 그냥 동작한다. **1단계의 중단 개념과 6단계의 격리 상속이 여기서 만난다.**

## View 쪽

```swift
struct UserView: View {
    @State private var viewModel = UserViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading { ProgressView() }
            else if let user = viewModel.user { Text(user.name) }
            else { Text("불러오지 못했습니다") }
        }
        .task { await viewModel.load() }
    }
}
```

`View`는 이미 `@MainActor`이므로 따로 붙일 필요가 없다. 옵셔널 상태를 `if let`으로 분기하는 방식은 [옵셔널 총정리](./141-optional-complete-guide.md)의 7부를 참조한다.

## 흔한 실수 네 가지

**① `Task.detached`로 UI 상태 만지기** — 액터 격리가 끊겨 에러가 난다. 백그라운드가 필요하면 무거운 계산만 분리하고 결과만 돌려받는다.

**② `init`에서 네트워크 호출 시작** — 객체 생성이 곧 통신 시작이 되어 프리뷰와 테스트에서도 실제 API를 때린다. 호출은 `.task`에서 시작한다.

**③ `@Observable`인데 `@MainActor`를 빼기** — 백그라운드에서 상태가 바뀌면 SwiftUI 갱신이 깨진다. Swift 6에서는 컴파일 에러가 된다.

**④ `Task { }`를 무심코 시작** — 작업을 만든 곳과 취소 관계를 확인해야 한다. `chapter-65`의 `init`에서 끝나지 않는 작업을 시작하는 사례는 [화면 생명주기 문서](./159-swiftui-view-and-task-lifecycle.md)의 비교와 함께 본다.

## 이 저장소에서 확인할 수 있는 사례

| 챕터 | 볼 것 |
| --- | --- |
| `chapter-65/ContentView.swift:116-137` | `init`에서 끝나지 않는 `Task` — 객체가 해제되지 않는다 |
| `chapter-94/HomeView.swift:128-130` | `body` 안에서 타이머 publisher 생성 |
| `chapter-09/ContentView.swift:20-34` | `invalidate` 없는 `Timer` — 구조적 동시성으로 바꿀 후보 |
| `chapter-88/Services/NetworkManager.swift:45` | `Task { @MainActor in }` 패턴 |
| `chapter-80/ViewModels/ViewModel.swift` | Combine 버전 — [114 문서](./114-combine-vs-async-await.md)로 비교 |

## 마무리 과제

로드맵의 마지막 항목이다. **작은 앱 하나에 1~8단계를 전부 연결**해 본다.

1. 콜백 API를 `withCheckedContinuation`으로 감싼다 (1단계)
2. `async throws` 서비스 계층을 만든다 (2단계)
3. `.task`로 호출하고 취소를 처리한다 (3·8단계)
4. 목록 여러 개를 `async let`으로 동시에 불러온다 (4단계)
5. 캐시를 `actor`로 만든다 (5단계)
6. ViewModel에 `@MainActor`를 붙인다 (6단계)
7. `SWIFT_VERSION`을 6으로 올려 남은 경고를 없앤다 (7단계)

통신·VoIP 쪽으로 확장한다면 여기에 WebSocket 스트림([`AsyncStream`](./154-async-stream.md)), CallKit 델리게이트 콜백(continuation), 타이머(`.task` + `Clock`)를 붙이면 실무 구조와 거의 같아진다.

## 학습 체크리스트

- [ ] ViewModel에서 `@MainActor`를 떼고 백그라운드에서 상태를 바꿔 본다.
- [ ] `Task.detached` 안에서 ViewModel 상태를 바꿔 에러를 확인한다.
- [ ] `init`에서 네트워크를 호출하는 ViewModel을 프리뷰에 띄워 실제 요청이 나가는지 확인한다.
- [ ] 목록 두 개를 순차 `await`와 `async let`으로 각각 불러와 체감 속도를 비교한다.
- [ ] 위 마무리 과제 7단계를 하나의 예제 앱으로 연결한다.

## 공식 참고 자료

- [Apple: View.task(priority:_:)](https://developer.apple.com/documentation/swiftui/view/task(id:name:executorpreference:priority:file:line:_:))
- [Apple: View.task(id:priority:_:)](https://developer.apple.com/documentation/swiftui/view/task(id:name:executorpreference:priority:file:line:_:))
- [Apple: Observable](https://developer.apple.com/documentation/observation/observable)
- [Apple: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Apple: Migrating from the Observable Object protocol to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Apple: AsyncStream](https://developer.apple.com/documentation/swift/asyncstream)
- [WWDC23: Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [WWDC25: Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
