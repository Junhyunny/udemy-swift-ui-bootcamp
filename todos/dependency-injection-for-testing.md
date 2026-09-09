# 테스트에서 외부 API를 모킹하고 주입하는 방법

`chapter-80`에서 만든 `StubURLProtocol`이 이 문서의 실물 예다. 상태 래퍼 선택은 [별도 문서](./state-wrapper-decision-guide.md)에 정리했다.

## 질문이 나온 코드

`chapter-94/chapter-94/chapter_94App.swift`

```swift
@StateObject var viewModel = TimerViewModel()

WindowGroup {
    ContentView()
        // TODO, UI 테스트나 결합테스트에서 외부 API 를 호출하는 모듈들은 모킹해야 하는데
        //       어떻게 의존성 주입을 할 수 있지? 화면 전체를 시뮬레이터에 렌더링하는 방식이던데..
        //       이런 Environment 객체를 사용해서 주입하는거야?
        .environmentObject(viewModel)
}
```

## 공부할 내용

### 먼저 — 테스트 종류에 따라 방법이 완전히 다르다

질문이 "UI 테스트"와 "결합 테스트"를 함께 언급했는데, **이 둘은 주입 방식이 근본적으로 다르다.**

| | 유닛/통합 테스트 (XCTest) | **UI 테스트** (XCUITest) |
| --- | --- | --- |
| 실행 위치 | **앱과 같은 프로세스** | **별도 프로세스** |
| 앱 코드 접근 | `@testable import`으로 직접 | **불가능** |
| 주입 방법 | 생성자·프로퍼티로 직접 | **실행 인자·환경 변수** |
| 목 객체 전달 | 객체를 그대로 넘긴다 | **넘길 수 없다** |

**UI 테스트에서 목 객체를 직접 주입할 수 없다는 점이 핵심이다.** 별도 프로세스이므로 객체 참조를 공유할 방법이 없다.

### 질문 확인: `environmentObject`로 주입하는 것이 아니다

**유닛 테스트에서는 `environmentObject`가 필요 없고, UI 테스트에서는 쓸 수 없다.**

`environmentObject`는 **뷰 계층 안에서** 객체를 전달하는 수단이다. [상태 래퍼 문서](./state-wrapper-decision-guide.md)에서 다룬 대로 뷰 트리에 묶여 있어서, 테스트 프로세스가 개입할 지점이 아니다.

**뷰를 직접 만드는 테스트라면 주입할 수 있다.**

```swift
// 유닛 테스트에서 뷰를 만들 때
let view = ContentView()
    .environmentObject(MockTimerViewModel())
```

하지만 SwiftUI 뷰는 렌더링 없이 검증하기 어려워 **이 방식은 실용성이 낮다.** 뷰모델 로직을 따로 테스트하는 편이 낫다.

## 1부 — 유닛/통합 테스트: 생성자 주입

### 기본 — 프로토콜로 추상화하고 주입

`chapter-80`에서 만든 구조가 표준적인 형태다.

```swift
protocol ExchangeRateService: Sendable {
    func fetchLatest(base: String, symbols: [String]) async throws -> ExchangeRate
}

struct LiveExchangeRateService: ExchangeRateService { ... }   // 실제 네트워크
struct StubExchangeRateService: ExchangeRateService { ... }   // 목
```

**뷰모델이 프로토콜에 의존하고 생성자로 받는다.**

```swift
@Observable
final class ExchangeRateViewModel {
    private let service: ExchangeRateService

    init(service: ExchangeRateService = LiveExchangeRateService()) {
        self.service = service
    }
}
```

**기본값을 주는 것이 요령이다.** 앱 코드는 인자 없이 쓰고, 테스트만 목을 넘긴다.

```swift
// 앱
let vm = ExchangeRateViewModel()

// 테스트
let vm = ExchangeRateViewModel(service: StubExchangeRateService(result: .success(.sample)))
```

### 테스트 코드

```swift
@testable import chapter_80
import Testing

@Test func 성공하면_상태가_loaded가_된다() async throws {
    let stub = StubExchangeRateService(result: .success(.sample))
    let vm = ExchangeRateViewModel(service: stub)

    await vm.load()

    #expect(vm.state == .loaded(.sample))
}

@Test func 실패하면_에러_메시지가_담긴다() async throws {
    let stub = StubExchangeRateService(error: ExchangeRateError.invalidURL)
    let vm = ExchangeRateViewModel(service: stub)

    await vm.load()

    if case .failed = vm.state { } else {
        Issue.record("failed 상태가 아니다")
    }
}
```

`@testable import`가 `internal` 멤버까지 접근하게 해 준다. [extension의 접근 수준](./extension-keyword.md)에서 다룬 `internal`이 테스트 타깃에서 열리는 것이다.

**Swift Testing**(`@Test`, `#expect`)이 XCTest를 대체하는 최신 프레임워크다. XCTest도 계속 지원된다.

### 네트워크 계층까지 검증하려면 — `URLProtocol`

프로토콜 추상화는 **서비스 계층 전체를 대체**한다. URL 생성, 상태 코드 검사, 디코딩 같은 **실제 코드 경로는 검증하지 못한다.**

그럴 때 `chapter-80`의 `StubURLProtocol`을 쓴다.

```swift
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override func startLoading() { /* 미리 정한 응답을 돌려준다 */ }
}
```

**`URLSessionConfiguration.protocolClasses`에 등록한 세션을 주입한다.**

```swift
static func stubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}
```

```swift
@Test func 상태코드_401이면_requestFailed를_던진다() async throws {
    StubURLProtocol.handler = { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 401,
                                       httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }
    defer { StubURLProtocol.reset() }

    let service = LiveExchangeRateService(session: ExchangeRateServiceFactory.stubbedSession())

    await #expect(throws: ExchangeRateError.requestFailed(statusCode: 401)) {
        try await service.fetchLatest()
    }
}
```

**두 방식의 역할이 다르다.**

| | 프로토콜 추상화 | `URLProtocol` 스텁 |
| --- | --- | --- |
| 대체 범위 | **서비스 계층 전체** | **네트워크 전송만** |
| 검증 대상 | 뷰모델 로직 | URL 생성, 상태 코드, 디코딩 |
| 속도 | 매우 빠름 | 빠름 |
| 실제 코드 경로 | 타지 않는다 | **탄다** |

**둘을 함께 쓴다.** 뷰모델 테스트는 프로토콜 목으로 빠르게, 서비스 테스트는 `URLProtocol`로 실제 경로를 검증한다.

## 2부 — UI 테스트: 실행 인자로 주입

### 객체를 넘길 수 없으므로 "신호"를 보낸다

UI 테스트는 앱을 별도 프로세스로 띄우므로, **앱에게 "목을 써라"고 알리는 방법**이 필요하다.

**실행 인자와 환경 변수가 그 통로다.**

```swift
// UI 테스트
final class TimerUITests: XCTestCase {
    func testTimerCountsDown() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-UseStubAPI"]
        app.launchEnvironment = ["STUB_SCENARIO": "success"]
        app.launch()

        app.buttons["Start"].tap()
        XCTAssertTrue(app.staticTexts["00:59"].waitForExistence(timeout: 2))
    }
}
```

**앱은 시작 시점에 그 값을 읽어 구성을 바꾼다.** `chapter-80`의 `AppEnvironment`가 이 방식이었다.

```swift
enum AppEnvironment {
    static var current: AppEnvironment {
        if ProcessInfo.processInfo.arguments.contains("-UseStubAPI") {
            return .stub
        }
        if ProcessInfo.processInfo.environment["USE_STUB_API"] == "1" {
            return .stub
        }
        // ...
    }
}
```

```swift
@main
struct MyApp: App {
    @State private var viewModel = TimerViewModel(
        service: AppEnvironment.current == .stub
            ? StubService()
            : LiveService()
    )
}
```

**시나리오를 여러 개 준비할 수도 있다.**

```swift
enum StubScenario: String {
    case success, emptyResult, networkError, slowResponse

    static var current: StubScenario {
        ProcessInfo.processInfo.environment["STUB_SCENARIO"]
            .flatMap(StubScenario.init(rawValue:)) ?? .success
    }
}
```

에러 화면이나 로딩 상태를 UI 테스트로 검증할 수 있게 된다.

### 정리하면 통로가 셋이다

| 방법 | 설정 | 앱에서 읽기 |
| --- | --- | --- |
| **실행 인자** | `app.launchArguments = [...]` | `ProcessInfo.processInfo.arguments` |
| **환경 변수** | `app.launchEnvironment = [...]` | `ProcessInfo.processInfo.environment` |
| 로컬 서버 | 테스트가 서버를 띄운다 | 앱은 `localhost`를 호출 |

**실행 인자가 가장 간단하다.** 세 번째는 실제 HTTP 왕복을 검증해야 할 때 쓰지만 설정 비용이 크다.

### 릴리스 빌드에서 목이 들어가지 않게

**주의할 점이다.** 스텁 코드가 앱 스토어 빌드에 포함되면 위험하다.

```swift
#if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-UseStubAPI") {
        return .stub
    }
#endif
```

`#if DEBUG`로 감싸면 릴리스 빌드에서 컴파일되지 않는다. 목 구현 자체를 테스트 타깃에 두는 방법도 있다.

## 3부 — 프리뷰도 같은 문제를 공유한다

**SwiftUI 프리뷰는 사실상 "테스트의 사촌"** 이다. 네트워크에 의존하면 느려지고 불안정해진다.

```swift
#Preview("정상") {
    ExchangeRateView(viewModel: .init(service: StubExchangeRateService(result: .success(.sample))))
}

#Preview("오류") {
    ExchangeRateView(viewModel: .init(service: StubExchangeRateService(error: URLError(.notConnectedToInternet))))
}

#Preview("로딩") {
    var stub = StubExchangeRateService()
    stub.delay = .seconds(10)
    return ExchangeRateView(viewModel: .init(service: stub))
}
```

**같은 목 구현으로 프리뷰와 테스트를 모두 커버한다.** 이것이 프로토콜 추상화의 실질적 이점이다.

프리뷰 실행 여부는 환경 변수로 판별할 수 있다.

```swift
static var isRunningInPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}
```

`chapter-80`의 `AppEnvironment`가 프리뷰와 테스트를 자동으로 스텁으로 넘긴 것이 이 방식이다.

## `chapter-94`에 적용하면

현재 `TimerViewModel`은 **주입 지점이 없다.**

```swift
final class TimerViewModel: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    func performNotification() {
        UNUserNotificationCenter.current().add(request) { ... }   // ← 직접 호출
    }
}
```

`UNUserNotificationCenter.current()`를 직접 부르므로 **테스트에서 알림 발행을 검증할 수 없다.** 실제 알림이 등록되거나, 시뮬레이터 권한에 따라 실패한다.

**프로토콜로 추상화하면 검증 가능해진다.**

```swift
protocol NotificationScheduling {
    func schedule(after seconds: Int, title: String, body: String) async throws
}

struct LiveNotificationScheduler: NotificationScheduling { ... }

final class SpyNotificationScheduler: NotificationScheduling {
    var scheduledSeconds: [Int] = []
    func schedule(after seconds: Int, title: String, body: String) async throws {
        scheduledSeconds.append(seconds)      // 호출을 기록만 한다
    }
}
```

```swift
@Test func 시작하면_남은_시간으로_알림이_예약된다() async throws {
    let spy = SpyNotificationScheduler()
    let vm = TimerViewModel(notifications: spy)
    vm.time = 60

    await vm.start()

    #expect(spy.scheduledSeconds == [60])
}
```

[알림 문서의 아키텍처 절](./user-notifications-framework.md)에서 제안한 분리가 테스트 가능성으로도 이어진다.

**목·스텁·스파이의 구분**도 알아 둘 만하다.

| 종류 | 역할 |
| --- | --- |
| **Stub** | 정해진 값을 돌려준다 |
| **Spy** | 호출을 기록한다 (위 예제) |
| **Mock** | 기대한 호출인지 검증한다 |
| **Fake** | 간략한 실제 구현 (인메모리 DB 등) |

Swift에서는 프로토콜 하나로 이 모두를 만들 수 있다.

### 정리

```text
질문 확인: environmentObject로 주입하는 것이 아니다
  유닛 테스트 → 필요 없다 (생성자 주입)
  UI 테스트   → 쓸 수 없다 (별도 프로세스)

유닛/통합 테스트
  ① 프로토콜 추상화 + 생성자 주입 (기본값을 주면 앱 코드는 그대로)
  ② URLProtocol 스텁 — 네트워크만 대체, 실제 코드 경로 검증
  둘을 함께 쓴다

UI 테스트 (XCUITest)
  별도 프로세스라 객체를 넘길 수 없다
  app.launchArguments / launchEnvironment로 "신호"를 보낸다
  앱이 ProcessInfo로 읽어 구성을 바꾼다
  #if DEBUG로 릴리스 빌드에서 제외

프리뷰도 같은 목을 재사용한다
  정상/오류/로딩 시나리오를 프리뷰로 확인

chapter-94는 주입 지점이 없다
  UNUserNotificationCenter.current()를 직접 호출
  → NotificationScheduling 프로토콜로 추상화하면 검증 가능
```

## 학습 체크리스트

- [ ] `chapter-80`의 `StubExchangeRateService`로 뷰모델 테스트를 작성한다.
- [ ] `StubURLProtocol.handler`로 401 응답을 만들어 오류 처리를 검증한다.
- [ ] `@testable import` 없이 테스트를 작성해 접근 에러를 확인한다.
- [ ] 생성자에 기본값을 주고 앱 코드가 변경 없이 동작하는지 확인한다.
- [ ] UI 테스트에서 `app.launchArguments`로 `-UseStubAPI`를 넘겨 본다.
- [ ] 앱에서 `ProcessInfo.processInfo.arguments`를 출력해 인자가 전달되는지 확인한다.
- [ ] `launchEnvironment`로 시나리오를 바꿔 오류 화면을 UI 테스트로 검증한다.
- [ ] `#if DEBUG`로 스텁 경로를 감싸고 릴리스 빌드에서 제외되는지 확인한다.
- [ ] 같은 목으로 프리뷰 세 가지(정상/오류/로딩)를 만들어 본다.
- [ ] `XCODE_RUNNING_FOR_PREVIEWS` 환경 변수를 출력해 프리뷰를 판별한다.
- [ ] `TimerViewModel`에서 알림 발행을 프로토콜로 분리해 본다.
- [ ] Spy로 호출 횟수를 기록하는 테스트를 작성한다.
- [ ] Stub과 Spy의 차이를 각각 구현해 비교한다.

## 공식 참고 자료

- [Apple: Swift Testing](https://developer.apple.com/documentation/testing)
- [Apple: XCTest](https://developer.apple.com/documentation/xctest)
- [Apple: XCUIApplication](https://developer.apple.com/documentation/xctest/xcuiapplication)
- [Apple: XCUIApplication.launchArguments](https://developer.apple.com/documentation/xctest/xcuiapplication/launcharguments)
- [Apple: XCUIApplication.launchEnvironment](https://developer.apple.com/documentation/xctest/xcuiapplication/launchenvironment)
- [Apple: URLProtocol](https://developer.apple.com/documentation/foundation/urlprotocol)
- [Apple: URLSessionConfiguration.protocolClasses](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/protocolclasses)
- [Apple: ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo)
- [Apple: Testing your apps in Xcode](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)
- [Apple: Running tests and interpreting results](https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results)
- [Apple: Previews in Xcode](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
- [Swift 공식 문서: Access Control — Access Levels for Unit Test Targets](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/#Access-Levels-for-Unit-Test-Targets)
