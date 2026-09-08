# `.task`는 무엇인가 — 뷰 생명주기와 비동기 작업

SwiftUI의 생명주기 전반은 [별도 문서](./view-lifecycle-hooks.md)에, `async/await` 실행 모델은 [여기](./swift-async-await-model.md)에 정리했다. 이 문서는 **`.task` modifier**에 집중한다.

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
VStack {
    Image(systemName: "globe")
    Text("Hello, world!")
}
.task {
    print(await News.fetchNews())
}
.padding()
```

## 공부할 내용

### 무엇을 하는 modifier인가

`.task`는 **뷰가 나타날 때 비동기 작업을 시작하고, 뷰가 사라질 때 그 작업을 자동으로 취소**한다.

```swift
nonisolated func task(
    priority: TaskPriority = .userInitiated,
    _ action: @escaping @Sendable () async -> Void
) -> some View
```

세 가지가 핵심이다.

- **`async` 클로저를 받는다.** 그래서 안에서 `await`을 쓸 수 있다
- **뷰가 나타날 때 시작**된다
- **뷰가 사라지면 취소**된다 — 이게 가장 중요한 성질

Apple의 설명은 "뷰의 수명과 일치하는 생명주기를 가진 비동기 작업을 수행한다"는 것이다.

### 왜 `onAppear`가 아니라 `.task`인가

이것이 핵심 질문이다. `onAppear`로도 비슷한 일을 할 수 있어 보이지만 차이가 크다.

```swift
// ⚠️ onAppear는 async 클로저를 받지 않는다
.onAppear {
    await News.fetchNews()      // 컴파일 에러
}

// 그래서 Task로 감싸야 한다
.onAppear {
    Task {
        print(await News.fetchNews())
    }
}

// ✅ .task는 그 자체로 async 문맥이다
.task {
    print(await News.fetchNews())
}
```

**차이는 취소 처리에 있다.**

| | `onAppear` + `Task { }` | `.task` |
| --- | --- | --- |
| async 클로저 | 직접 못 받음 (`Task`로 감싸야) | **받는다** |
| 뷰가 사라질 때 | **작업이 계속 실행된다** | **자동 취소** |
| 취소 코드 | 직접 관리해야 함 | 불필요 |
| 값 변경 시 재실행 | 직접 구현 | `task(id:)`로 가능 |

`onAppear` + `Task`는 뷰가 사라져도 작업이 계속 돈다. 사용자가 화면을 나갔는데 네트워크 요청이 진행되고, 완료 후 이미 사라진 뷰의 상태를 갱신하려 시도한다. 메모리 낭비이고 예상치 못한 동작의 원인이 된다.

`.task`는 이 문제를 구조적으로 없앤다.

### 어떤 생명주기 시점인가

`onAppear`와 거의 같은 시점이다.

```text
뷰가 뷰 계층에 추가된다
        ↓
onAppear 호출  ≈  task 시작
        ↓
   (화면 표시 중)
        ↓
뷰가 뷰 계층에서 제거된다
        ↓
onDisappear 호출  ≈  task 취소
```

[생명주기 문서](./view-lifecycle-hooks.md)에서 정리한 대로 SwiftUI에는 UIKit 같은 고정된 콜백 목록이 없고, `onAppear`/`onDisappear`/`task`가 그 역할을 나눠 갖는다.

**주의할 점**이 있다. "사라진다"는 것이 반드시 화면에서 안 보인다는 뜻은 아니다. 뷰가 **뷰 계층에서 제거**될 때를 말한다. 네비게이션으로 다른 화면을 밀어 올리면 아래 화면은 계층에 남아 있으므로 `task`가 취소되지 않을 수 있다.

### `priority` 파라미터

기본값이 `.userInitiated`다.

```swift
.task(priority: .background) {
    await preloadCache()
}
```

| 값 | 용도 |
| --- | --- |
| `.high` / `.userInitiated` | 사용자가 결과를 기다리는 작업 (기본값) |
| `.medium` | 보통 |
| `.low` / `.utility` | 진행 표시가 있는 긴 작업 |
| `.background` | 사용자가 모르는 준비 작업 |

화면에 바로 필요한 데이터를 가져오는 예제의 경우 기본값이 적절하다.

### `task(id:)` — 값이 바뀔 때 다시 실행

같은 계열의 변형이 있다.

```swift
.task(id: selectedCategory) {
    articles = await fetchArticles(category: selectedCategory)
}
```

`id` 값이 바뀌면 **기존 작업을 취소하고 새로 시작한다.** 검색어나 필터가 바뀔 때마다 재요청하는 패턴에 쓴다.

[`onChange`](./onchange-old-new-value.md)와 비슷해 보이지만 다르다. `onChange`는 동기 클로저이고 취소 처리가 없다. `task(id:)`는 async이고 이전 작업을 취소해 준다.

### 취소는 협조적이다 — 자동이 아니다

여기가 오해하기 쉬운 지점이다. **`.task`가 취소를 "요청"하지만, 작업이 실제로 멈추려면 그 코드가 취소를 확인해야 한다.**

Swift 동시성의 취소는 **협조적(cooperative)** 이다. 시스템이 강제로 스레드를 죽이지 않는다.

```swift
.task {
    for i in 0..<1_000_000 {
        heavyComputation(i)      // 취소 확인 없음 → 끝까지 돈다
    }
}
```

취소에 반응하려면 확인해야 한다.

```swift
.task {
    for i in 0..<1_000_000 {
        try Task.checkCancellation()   // 취소되면 에러를 던진다
        heavyComputation(i)
    }
}
```

```swift
.task {
    while !Task.isCancelled {
        await poll()
    }
}
```

**다행히 표준 API 대부분은 취소를 이미 지원한다.** `URLSession.data(for:)`, `Task.sleep`은 취소되면 에러를 던진다. 그래서 이 예제의 네트워크 요청은 별도 코드 없이 취소가 동작한다.

### 이 예제 코드의 문제

```swift
.task {
    print(await News.fetchNews())
}
```

**학습·디버깅 목적이라면 문제없지만, 실제 앱 코드로는 두 가지가 아쉽다.**

**① 결과를 상태에 담지 않는다**

`print`로 콘솔에 찍기만 하고 화면에는 아무것도 반영되지 않는다. 실제로는 `@State`에 저장해야 한다.

```swift
struct ContentView: View {
    @State private var news: News?

    var body: some View {
        VStack {
            if let news {
                Text("기사 \(news.articles.count)개")
            } else {
                ProgressView()
            }
        }
        .task {
            news = await News.fetchNews()
        }
    }
}
```

**② 오류가 조용히 사라진다**

`fetchNews()`의 구현을 보면 이렇다.

```swift
static func fetchNews() async -> News? {
    do {
        let news = try await NetworkingManager.shared.request(...)
        return news
    } catch {}          // ← 오류를 삼킨다
    return nil
}
```

`catch {}`가 비어 있어 **무슨 오류가 났는지 알 수 없다.** 요청 실패, 디코딩 실패, 취소가 모두 `nil`로 뭉개진다. 디버깅이 어려워지는 전형적인 패턴이다.

최소한 로그를 남기거나, 오류를 밖으로 전달하는 편이 낫다.

```swift
static func fetchNews() async throws -> News {
    try await NetworkingManager.shared.request(
        endpoint: "...",
        responseType: News.self
    )
}
```

```swift
@State private var news: News?
@State private var errorMessage: String?

.task {
    do {
        news = try await News.fetchNews()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

[오류 처리 방식들](./swift-error-handling-forms.md)과 [async throws 문서](./async-throws-and-custom-errors.md)에 관련 내용이 있다.

**③ 취소도 오류로 온다는 점을 알아 둘 것**

뷰가 사라져 작업이 취소되면 `URLSession`이 `CancellationError`나 그에 준하는 오류를 던진다. `catch`에서 이것을 실제 실패와 구분하지 않으면 "오류 발생" 메시지가 불필요하게 뜰 수 있다.

```swift
.task {
    do {
        news = try await News.fetchNews()
    } catch is CancellationError {
        // 취소는 정상 흐름이므로 무시
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### `Task { }`와 `.task { }` 구분

이름이 비슷해 헷갈린다.

| | 정체 | 취소 |
| --- | --- | --- |
| `Task { }` | **Swift 표준 라이브러리의 타입** — 비구조적 작업 생성 | 직접 관리 |
| `.task { }` | **SwiftUI의 view modifier** | 뷰 수명에 맞춰 자동 |

`.task`는 내부적으로 `Task`를 만들고 뷰 생명주기에 묶어 주는 편의 장치다.

#### `Task { }`를 자세히 — `chapter-61`의 사례

`chapter-61/chapter-61/ContentView.swift`가 두 방식을 한 파일에서 쓴다.

```swift
.task {
    print("fetching news")
}
```

```swift
func fetchNews() {
    Task {
        news = await News.fetchNews() ?? .init(status: "", totalResults: 0, articles: [])
    }
}
```

```swift
.onAppear { fetchNews() }
.refreshable { fetchNews() }
```

**`Task { }`가 무엇인가**

`Task`는 **비동기 작업 하나를 나타내는 표준 라이브러리 타입**이다. `Task { }`로 초기화하면 그 순간 새 작업이 만들어져 **즉시 실행이 시작된다.**

핵심 용도는 **동기 문맥에서 비동기 함수를 호출하는 다리**다.

```swift
func fetchNews() {          // 동기 함수 — await을 쓸 수 없다
    Task {                  // 여기서부터 async 문맥이 된다
        await News.fetchNews()
    }
}
```

`fetchNews()`는 `onAppear`와 `refreshable`에서 호출되는데, `onAppear`가 동기 클로저를 받으므로 `await`을 직접 쓸 수 없다. `Task { }`가 그 경계를 넘게 해 준다.

이런 작업을 **비구조적 작업(unstructured task)** 이라 부른다. `async let`이나 `TaskGroup`처럼 부모-자식 관계가 명확한 **구조적 동시성**과 달리, 만든 곳의 생명주기와 무관하게 독립적으로 살아간다.

**`.task { }`와의 차이를 다시 정리하면**

| | `Task { }` | `.task { }` |
| --- | --- | --- |
| 정체 | 표준 라이브러리 **타입** | SwiftUI **view modifier** |
| 어디서 쓰나 | 동기 코드 안 어디서나 | 뷰에 붙인다 |
| 시작 시점 | **생성 즉시** | 뷰가 나타날 때 |
| 취소 | **직접 관리** — 참조를 보관해 `cancel()` | 뷰가 사라지면 자동 |
| 앱 라이프사이클 | **무관** — 뷰가 사라져도 계속 실행 | 뷰 수명에 묶임 |
| 반환값 | `Task` 인스턴스 (보관 가능) | 없음 |
| 우선순위 | `Task(priority: .background) { }` | `.task(priority:)` |

**질문의 "앱 라이프사이클과 관련이 있는지"에 답하면 — 없다.** `Task { }`는 뷰나 앱의 상태를 전혀 모른다. 시작되면 완료될 때까지 돌고, 취소하려면 명시적으로 해야 한다.

```swift
@State private var loadTask: Task<Void, Never>?

func fetchNews() {
    loadTask?.cancel()          // 이전 작업 취소
    loadTask = Task {
        news = await News.fetchNews() ?? ...
    }
}
```

`Task`를 변수에 담아야 취소할 수 있다. 이 예제는 담지 않으므로 **취소할 방법이 없다.**

**이 코드에서 실제로 생기는 문제**

`onAppear`와 `refreshable`이 각각 `fetchNews()`를 호출하고, 그때마다 새 `Task`가 만들어진다. 사용자가 빠르게 여러 번 새로고침하면 **여러 요청이 동시에 진행되고, 완료 순서가 보장되지 않는다.** 늦게 시작한 요청이 먼저 끝나면 오래된 데이터가 최신 데이터를 덮어쓸 수 있다.

또한 `refreshable`은 원래 **async 클로저를 받는다.**

```swift
nonisolated func refreshable(action: @escaping @Sendable () async -> Void) -> some View
```

그래서 `Task { }`로 감쌀 필요가 없고, 감싸면 오히려 **당김 새로고침 인디케이터가 즉시 사라진다.** `refreshable`은 클로저가 끝날 때까지 인디케이터를 유지하는데, `Task { }`는 작업을 시작하고 바로 반환하므로 시스템이 "완료됐다"고 판단한다.

```swift
// ⚠️ 인디케이터가 즉시 사라진다
.refreshable {
    fetchNews()              // Task를 만들고 바로 끝난다
}

// ✅ 실제 완료까지 인디케이터가 유지된다
.refreshable {
    await loadNews()         // async 함수를 직접 await
}
```

**세 방식을 정리하면 이렇게 쓰는 것이 맞다.**

```swift
struct ContentView: View {
    @State private var news: News?

    var body: some View {
        NavigationStack {
            List(news?.articles ?? []) { article in ... }
        }
        .task {                     // 등장 시 1회, 사라지면 자동 취소
            await loadNews()
        }
        .refreshable {              // 당김 새로고침, 인디케이터 정상 동작
            await loadNews()
        }
    }

    func loadNews() async {         // async 함수로 통일
        news = await News.fetchNews()
    }
}
```

`onAppear`와 `Task { }`가 모두 사라진다. `.task`가 등장 시 로딩을 담당하고, `refreshable`이 새로고침을 담당한다.

**`Task { }`가 정말 필요한 경우**

- 동기 델리게이트 메서드 안에서 비동기 함수를 불러야 할 때
- 버튼 액션처럼 동기 클로저에서 비동기 작업을 시작할 때

```swift
Button("저장") {
    Task { await save() }       // 버튼 action은 동기 클로저다
}
```

- 뷰 생명주기와 무관하게 끝까지 실행되어야 할 때 (업로드 등)

```swift
Task.detached(priority: .background) { ... }
```

`Task.detached`는 현재 액터와 우선순위를 물려받지 않는 완전 독립 작업이다. 대부분의 경우 필요하지 않으므로 신중히 쓴다.

### 정리

```text
.task { }
  뷰가 나타날 때 async 작업 시작
  뷰가 사라질 때 자동 취소          ← 핵심 가치
  onAppear + Task { }로는 취소가 안 된다

시점: onAppear ≈ task 시작, onDisappear ≈ task 취소
변형: task(id:) — 값이 바뀌면 취소하고 재실행
주의: 취소는 협조적 — 표준 API는 대응하지만 직접 만든 루프는 확인 필요
```

## 학습 체크리스트

- [ ] `.task`를 `onAppear` + `Task { }`로 바꿔 동작이 같은지 확인한다.
- [ ] 네트워크 요청 중에 화면을 나가고 두 방식의 차이를 로그로 관찰한다.
- [ ] `.task` 안에 `print("시작")`과 `print("끝")`을 넣어 호출 시점을 확인한다.
- [ ] `onAppear`, `.task`, `onDisappear`에 각각 로그를 넣어 순서를 본다.
- [ ] `fetchNews()` 결과를 `@State`에 담아 화면에 표시해 본다.
- [ ] `ProgressView`로 로딩 상태를 표시해 본다.
- [ ] `catch {}`에 `print(error)`를 넣어 어떤 오류가 오는지 확인한다.
- [ ] 잘못된 URL로 바꿔 오류가 실제로 발생하는지 본다.
- [ ] `fetchNews()`를 `async throws`로 바꾸고 뷰에서 `do-catch`로 처리한다.
- [ ] `CancellationError`를 별도로 잡아 취소와 실패를 구분해 본다.
- [ ] `.task(priority: .background)`로 바꿔 보고 차이를 관찰한다.
- [ ] `task(id:)`로 값이 바뀔 때 재요청하는 코드를 작성한다.
- [ ] `Task.isCancelled`를 확인하는 루프를 만들고 화면을 나가 취소되는지 본다.
- [ ] `Task.checkCancellation()`을 쓰지 않는 무한 루프가 취소되지 않는 것을 확인한다.
- [ ] `Task { }`를 변수에 담아 `cancel()`로 취소해 본다.
- [ ] `refreshable`에서 `Task { }`를 쓸 때 인디케이터가 즉시 사라지는 것을 확인한다.
- [ ] `refreshable { await loadNews() }`로 바꿔 인디케이터가 유지되는지 비교한다.
- [ ] `onAppear` + `Task { }`를 `.task`로 통합해 본다.
- [ ] 새로고침을 빠르게 여러 번 해 요청이 동시에 진행되는지 로그로 확인한다.
- [ ] `Task.detached`와 `Task { }`의 차이를 현재 액터 관점에서 설명한다.

## 공식 참고 자료

- [Apple: view.task(priority:_:)](https://developer.apple.com/documentation/swiftui/view/task(priority:_:))
- [Apple: view.task(id:priority:_:)](https://developer.apple.com/documentation/swiftui/view/task(id:priority:_:))
- [Apple: view.onAppear(perform:)](https://developer.apple.com/documentation/swiftui/view/onappear(perform:))
- [Apple: view.onDisappear(perform:)](https://developer.apple.com/documentation/swiftui/view/ondisappear(perform:))
- [Apple: Task](https://developer.apple.com/documentation/swift/task)
- [Apple: Task.detached(priority:operation:)](https://developer.apple.com/documentation/swift/task/detached(priority:operation:))
- [Apple: Task.cancel()](https://developer.apple.com/documentation/swift/task/cancel())
- [Apple: view.refreshable(action:)](https://developer.apple.com/documentation/swiftui/view/refreshable(action:))
- [Apple: TaskPriority](https://developer.apple.com/documentation/swift/taskpriority)
- [Apple: Task.isCancelled](https://developer.apple.com/documentation/swift/task/iscancelled-swift.type.property)
- [Apple: Task.checkCancellation()](https://developer.apple.com/documentation/swift/task/checkcancellation())
- [Apple: CancellationError](https://developer.apple.com/documentation/swift/cancellationerror)
- [Swift 공식 문서: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Apple: URLSession.data(for:delegate:)](https://developer.apple.com/documentation/foundation/urlsession/data(for:delegate:))
- [Apple: WWDC21 — What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10018/)
