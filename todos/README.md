# 학습 TODO 복습 로드맵

프로젝트의 학습 TODO를 **Swift 언어 기초 → 타입과 추상화 → SwiftUI 상태와 화면 구성 → 동시성·네트워크 → 데이터 저장 → 개별 프레임워크 API** 순으로 재배치했다. 위에서 아래로 진행하면 뒤의 주제를 이해하는 데 필요한 개념을 먼저 만날 수 있다.

각 단계 안에서도 번호가 작은 문서를 먼저 학습한다. 처음부터 모든 문서를 암기하기보다, 문서의 학습 체크리스트를 수행하고 해당 챕터 코드에서 개념을 다시 확인한 뒤 다음 항목으로 넘어간다.

## 1. Swift 문법과 실행 모델

다른 모든 주제의 기반이다. 값과 타입, 제어 흐름, 함수, 객체의 수명 순서로 학습한다.

- [ ] [Swift의 기본 타입과 비교 방법](./001-swift-fundamental-types-and-comparison.md)
- [ ] [`let`과 `var`](./002-let-vs-var.md)
- [ ] [`if`의 조건 결합과 옵셔널 바인딩](./003-if-conditions-and-optional-binding.md)
- [ ] [`guard` 키워드 — 조기 탈출과 그 장점](./004-guard-keyword.md)
- [ ] [타입에 붙는 `!` — 암시적 언래핑 옵셔널](./005-implicitly-unwrapped-optional.md)
- [ ] [옵셔널 총정리 — 선언부터 언래핑, 강제 언래핑까지](./141-optional-complete-guide.md)
- [ ] [`var posts = [Post]()` — 컬렉션 초기화 표기들](./006-array-literal-and-initialization.md)
- [ ] [`$0`의 정체 — shorthand argument name과 클로저 축약 단계](./007-closure-shorthand-argument-names.md)
- [ ] [`at:` 문법의 정체와 `IndexSet`](./008-argument-labels-and-indexset.md)
- [ ] [Swift의 함수 오버로딩 — argument label이 시그니처의 일부다](./009-swift-function-overloading.md)
- [ ] [`var x: T { ... }` — 지역 계산 프로퍼티와 즉시 실행 클로저](./010-computed-property-with-closure-body.md)
- [ ] [`enum Foo: String`은 상속이 아니다 — raw value](./011-enum-raw-values.md)
- [ ] [백틱으로 예약어를 식별자로 쓰기](./012-backtick-reserved-keywords.md)
- [ ] [`subscript` 키워드 — `[ ]` 표기를 직접 정의하기](./013-subscript-keyword.md)
- [ ] [`extension` 키워드는 무엇이고 언제 쓰는가](./014-extension-keyword.md)
- [ ] [`static` 타입 프로퍼티와 `.init` — 장단점과 함정](./015-static-type-properties-and-implicit-init.md)
- [ ] [`static var { }`와 `static let = []`의 차이](./016-static-stored-vs-computed-property.md)
- [ ] [Swift 접근 제어](./017-access-control.md)
- [ ] [`final` 키워드 — 어디에 붙이고 무엇을 막는가](./018-final-keyword.md)
- [ ] [`struct`와 `class`](./019-struct-vs-class.md)
- [ ] [Swift의 타입 체계와 상속 구조](./020-swift-type-system-and-inheritance.md)
- [ ] [Swift의 형변환 — `as?`, `as!`, `as`, `is`](./021-swift-type-casting.md)
- [ ] [Swift의 메모리 구조 — JVM과 비교해서](./022-swift-memory-model.md)
- [ ] [`[weak self]`와 `deinit` — 객체가 언제 사라지나](./023-weak-self-and-deinit.md)
- [ ] [Swift 파일 명명 규칙 — `Type+Feature.swift`](./024-swift-file-naming-conventions.md)

## 2. 프로토콜, 제네릭과 타입 추상화

SwiftUI의 제네릭 뷰, 식별자, 프로토콜 기반 API를 읽기 위한 단계다.

- [ ] [`Identifiable` 프로토콜을 쓰는 이유와 쓰는 경우](./025-identifiable-protocol.md)
- [ ] [`id`에 쓰이는 `Hashable`과 해시 충돌 걱정](./026-hashable-id-and-collisions.md)
- [ ] [`hash(into:)`와 Java의 `equals()`·`hashCode()` 비교](./027-hash-into-and-java-comparison.md)
- [ ] [`enum`은 항상 `Hashable`이어야 하는가](./028-enum-hashable-conformance.md)
- [ ] [`CaseIterable`과 `Sequence` — 열거형 전체 사례 순회](./029-caseiterable-and-sequence.md)
- [ ] [Swift의 제네릭 — 선언, 사용, 주의사항](./030-swift-generics.md)
- [ ] [`where` 키워드 — 반복문 필터부터 연관 타입 제약까지](./031-where-clause-usages.md)
- [ ] [`typealias`는 왜 쓰는가 — associatedtype과의 관계](./032-typealias-and-associated-type.md)
- [ ] [타입을 `&`로 묶기 — 프로토콜 합성과 타입을 모으는 문법 총정리](./033-protocol-composition-and-type-combining.md)
- [ ] [`some` 키워드 — opaque type과 함께 공부할 개념들](./034-some-keyword-opaque-types.md)
- [ ] [`SomeType.self`의 정체 — 메타타입과 `.self`](./035-metatype-and-self.md)
- [ ] [`makeBody`는 override가 아니다 — protocol 요구사항과 style 프로토콜](./036-protocol-requirements-and-style-protocols.md)
- [ ] [Swift macro는 언제 코드가 추가되는가 — 빌드 파이프라인과 Java 비교](./037-swift-macros-and-build-pipeline.md)
- [ ] ["unable to type-check this expression in reasonable time" — 컴파일러가 타입 추론을 포기할 때](./038-type-checker-timeout-error.md)

## 3. SwiftUI 구조와 데이터 흐름

앱과 View의 구조를 먼저 잡고, 프로퍼티 래퍼와 상태 소유권을 학습한다.

- [ ] [SwiftUI 애플리케이션 아키텍처 — `App`, `Scene`, `WindowGroup`, `DocumentGroup`](./039-swiftui-application-architecture.md)
- [ ] [`ComponentName { }`의 정체 — 클로저, trailing closure, result builder](./040-closures-and-view-builders.md)
- [ ] [`@ViewBuilder` 함수 vs 별도 `View` 구조체](./041-viewbuilder-vs-view-struct.md)
- [ ] [`ViewModifier` 프로토콜과 `modifier(_:)`](./042-view-modifier-protocol.md)
- [ ] [`@State`를 붙이면 타입이 바뀌는가, `$`는 언제 쓸 수 있는가](./043-state-wrapper-type-and-binding.md)
- [ ] [프로퍼티 래퍼의 `$` 사용 기준](./044-property-wrapper-dollar-sign.md)
- [ ] [`mutating`은 무엇이고, `@State`는 왜 없어도 되는가](./045-mutating-and-state-mutation.md)
- [ ] [`@State`와 `_viewModel` — 프로퍼티 래퍼가 만드는 세 개의 이름](./046-state-property-wrapper-backing-storage.md)
- [ ] [`ForEach`에서 무엇이 `Binding`이고 무엇이 값인가](./047-binding-in-foreach.md)
- [ ] [`@Environment` — 언제 쓰고, 무엇을 받을 수 있는가](./048-environment-property-wrapper.md)
- [ ] [상태 관리 래퍼 총정리 — 왜 종류가 많은가](./049-state-wrapper-decision-guide.md)
- [ ] [`Observation` 모듈과 `@Observable` 매크로](./050-observation-framework-and-observable.md)
- [ ] [SwiftUI의 생명주기 — App, Scene, View](./051-view-lifecycle-hooks.md)
- [ ] [`onChange`의 `oldValue`, `newValue`](./052-onchange-old-new-value.md)

## 4. View, 컬렉션과 레이아웃

화면을 구성하는 기본 API에서 시작해 좌표와 레이아웃 정보 전달로 확장한다.

- [ ] [`ForEach`의 `id`와 `\.self` key path](./053-foreach-id-and-identity-keypath.md)
- [ ] [`List`에서 `id`가 중복되면 어떻게 되는가](./054-duplicate-id-in-list.md)
- [ ] [Asset catalog의 "Universal"과 배율 슬롯의 의미](./055-asset-catalog-universal-scale.md)
- [ ] [프리뷰의 파란 테두리와 Image 크기 조절 modifier](./056-image-layout-and-preview-bounds.md)
- [ ] [SF Symbol rendering mode의 종류와 차이](./057-symbol-rendering-mode.md)
- [ ] [`ImageResource`는 언제 등장했고, 그전에는 어떻게 했나](./058-image-resource-and-asset-symbols.md)
- [ ] [`scaledToFill()`이 레이아웃을 흔드는 이유와 `clipped()`](./059-scaled-to-fill-and-clipped.md)
- [ ] [`overlay`는 무엇이고, 왜 화면이 까맣게 덮였나](./060-overlay-and-shape-fill.md)
- [ ] [`CG`로 시작하는 타입들과 `CGFloat`](./061-coregraphics-types-and-cgfloat.md)
- [ ] [`LazyVStack`의 용도와 lazy 렌더링 시점](./062-lazy-stack-rendering.md)
- [ ] [`GridItem`으로 만들 수 있는 grid의 종류](./063-grid-item-sizing.md)
- [ ] [여러 행으로 grid를 구성하는 방법과 공식 예제](./064-multi-row-grid-composition.md)
- [ ] [`GeometryReader`를 언제, 왜 쓰는가](./065-geometry-reader-use-cases.md)
- [ ] [좌표 공간 — local, global, named와 부모·자식 뷰의 관계](./066-coordinate-space-local-global-named.md)
- [ ] [`PreferenceKey` — 자식이 조상에게 값을 올려 보내는 통로](./067-preference-key-and-onpreferencechange.md)
- [ ] [`GeometryReader`와 성능 — 중첩이 왜 문제가 되는가](./068-geometry-reader-performance.md)
- [ ] [`Canvas` 좌표계와 0~1 정규화 좌표](./069-canvas-coordinate-space-and-normalization.md)
- [ ] [`UIScreen.main`이 deprecated된 이유와 대안](./070-uiscreen-main-deprecated.md)
- [ ] [`mask` — 알파 채널로 뷰를 오려내기](./071-mask-and-alpha-channel.md)

## 5. 내비게이션, 화면 전환과 플랫폼 연동

화면 이동과 값 전달을 익힌 다음 URL, UIKit 등 앱 외부 경계로 나아간다.

- [ ] [`NavigationStack`의 역할과 `navigationTitle`을 붙이는 위치](./072-navigation-stack-and-title.md)
- [ ] [`NavigationStack`은 언제 등장했고 `NavigationView`와 무엇이 다른가](./073-navigation-stack-vs-navigation-view.md)
- [ ] [Swift · iOS · 기기 버전 호환성을 확인하는 방법](./074-swift-ios-device-compatibility.md)
- [ ] [`NavigationPath`와 타입 배열 — 무엇이 다르고 언제 쓰는가](./075-navigation-path-and-typed-array.md)
- [ ] [`NavigationLink`의 `value`와 `navigationDestination`의 `String.self`](./076-navigation-link-value-and-destination.md)
- [ ] [deprecated된 `NavigationLink` 이니셜라이저와 최신 대안](./077-deprecated-navigation-link-initializers.md)
- [ ] [`NavigationLink` 두 방식의 공존과 혼용](./078-navigation-link-two-styles-mixed.md)
- [ ] [값 기반 네비게이션의 장단점 — 그리고 라우팅 값 설계](./140-value-based-navigation-tradeoffs.md)
- [ ] [`presentationMode`와 `dismiss`의 차이](./079-presentation-mode-vs-dismiss.md)
- [ ] [`sheet`의 `onDismiss`와 결과 전달](./080-sheet-ondismiss-and-result.md)
- [ ] [`scrollPosition(id:)` — 무엇이 `currentIndex`를 바꾸고 있는가](./081-scroll-position-binding.md)
- [ ] [`toolbar` API — 배치, 종류, 사용 케이스 총정리](./082-toolbar-api-use-cases.md)
- [ ] [SwiftUI가 이미 제공하는 버튼들 — `EditButton`과 그 형제들](./083-builtin-swiftui-buttons.md)
- [ ] [`ZStack`에서 탭이 어디로 가는가 — 히트 테스트와 DOM 이벤트](./084-swiftui-hit-testing-vs-dom-events.md)
- [ ] [딥링크와 커스텀 URL 스킴 — 용도와 Info.plist 프로퍼티](./085-deep-link-and-url-scheme.md)
- [ ] [브라우저가 앱을 찾아가는 원리와 스킴 충돌](./086-url-scheme-resolution-and-conflicts.md)
- [ ] [`UIViewRepresentable`과 `UI` 접두사 — UIKit 컴포넌트 가져오기](./087-uiviewrepresentable-and-uikit-bridge.md)
- [ ] [SwiftUI와 UIKit 아키텍처 — 명령형·선언형 UI와 상호운용](./088-swiftui-and-uikit-architecture.md)

## 6. 애니메이션과 고급 렌더링

일반 애니메이션의 트리거와 범위를 이해한 뒤 전환, geometry 연결, 보간으로 진행한다.

- [ ] [`animation(_:value:)`의 `value`가 필요한 이유](./089-animation-value-trigger.md)
- [ ] [암시적 애니메이션과 `withAnimation`의 차이](./090-implicit-vs-explicit-animation.md)
- [ ] [`phaseAnimator`의 파라미터와 phase에 담을 수 있는 것](./091-phase-animator-parameters-and-phase-types.md)
- [ ] [애니메이션 API 세 가지 비교 — `animation`, `withAnimation`, `phaseAnimator`](./092-animation-api-comparison.md)
- [ ] [`.delay()`로 애니메이션을 미루는 방식의 원리](./093-animation-delay-scheduling.md)
- [ ] [SwiftUI `transition`의 효과와 조합 방법](./094-swiftui-transition-composition.md)
- [ ] [여러 `offset` modifier는 어떻게 합성되는가](./095-chained-offset-modifiers.md)
- [ ] [`rotation3DEffect`의 회전축과 카드 기울이기](./096-rotation3d-axis-and-card-tilt.md)
- [ ] [`@Namespace` — 두 뷰의 기하 정보를 잇는 이름표](./097-namespace-and-matched-geometry-effect.md)
- [ ] [`animatableData` — SwiftUI가 중간 프레임을 만들어 내는 원리](./098-animatable-data-and-interpolation.md)
- [ ] [`@Animatable`과 `@AnimatableIgnored` — 손으로 쓰던 것을 매크로가 대신 쓴다](./099-animatable-macro.md)

## 7. 오류 처리, 동시성과 이벤트 스트림

비동기 API를 사용하기 전에 오류 전파, 작업 수명, 액터 격리를 먼저 익힌다.

- [ ] [Swift의 오류 처리 방식들 — `try`, `try?`, `try!`, `do-catch`, `defer`](./100-swift-error-handling-forms.md)
- [ ] [`async throws`와 커스텀 에러](./102-async-throws-and-custom-errors.md)
- [ ] [`.task`는 무엇인가 — 뷰 생명주기와 비동기 작업](./103-task-modifier-and-async-lifecycle.md)
- [ ] [`TaskPriority` — 우선순위 값들과 실제 동작](./104-task-priority-and-scheduling.md)
- [ ] [`for await` — 비동기 시퀀스를 반복하기](./105-for-await-async-sequence.md)
- [ ] [`MainActor`는 왜 필요한가 — iOS의 스레드 모델](./106-main-actor-and-ios-threading.md)
- [ ] [`actor` 타입 — 무엇이고, 어떤 용도로 왜 쓰는가](./107-swift-actor-type.md)
- [ ] [`nonisolated` — "이 코드는 액터 밖에서도 안전하다"는 선언](./108-nonisolated-keyword.md)
- [ ] [`NotificationCenter` — 멀리 떨어진 컴포넌트끼리 통신하기](./109-notification-center.md)
- [ ] [`Timer.publish` + `onReceive` — 주기적·외부 이벤트](./110-timer-publisher-and-onreceive.md)
- [ ] [Combine 프레임워크](./111-combine.md)
- [ ] [`AnyCancellable`, `sink`, `store(in:)` — 구독의 수명 관리](./112-combine-cancellable-and-store.md)
- [ ] [Combine 연산자 — `replaceError`, `receive(on:)`, `map`, `decode`](./113-combine-operators.md)
- [ ] [액터 격리 — 격리 도메인, 전역 액터, `isolated` 파라미터](./139-actor-isolation-domains.md)

### Swift Concurrency 집중 과정

위 문서들이 개별 주제를 다룬다면, 아래 9개는 **하나의 실행 모델로 묶어 순서대로** 학습하는 과정이다. 로드맵부터 읽는다.

- [ ] [Swift Concurrency 학습 로드맵 — 전체 지도와 순서](./142-swift-concurrency-roadmap.md)
- [ ] [1단계 — 동기 vs 비동기, 중단(suspension)](./143-sync-vs-async-and-suspension.md)
- [ ] [2단계 — `async` / `await` / `try await`](./144-async-await-basics.md)
- [ ] [3단계 — `Task`와 취소](./145-task-basics-and-cancellation.md)
- [ ] [4단계 — 구조적 동시성: `async let`과 `TaskGroup`](./146-structured-concurrency.md)
- [ ] [5단계 — `actor`와 재진입](./147-actor-and-reentrancy.md)
- [ ] [6단계 — `@MainActor`와 전역 액터](./148-main-actor-and-global-actors.md)
- [ ] [7단계 — `Sendable`과 Swift 6 엄격 검사](./149-sendable-and-strict-concurrency.md)
- [ ] [8단계 — SwiftUI와 연결하기](./150-swiftui-concurrency-integration.md)
- [ ] [부록 — 동시성 런타임 아키텍처 (JavaScript 이벤트 루프와 비교)](./151-concurrency-runtime-architecture.md)

## 8. 네트워크와 외부 데이터

서버 데이터를 모델링하고 안전하게 요청하는 흐름을 익힌 뒤 테스트 가능한 구조까지 연결한다.

- [ ] [`Foundation` 모듈에는 무엇이 들어 있나](./115-foundation-framework.md)
- [ ] [`NS` 접두사가 붙은 타입들](./116-ns-prefix-foundation-classes.md)
- [ ] [`Codable`과 `CodingKeys`](./117-codable-and-codingkey.md)
- [ ] [API 응답 모델에 옵셔널을 써야 하나](./118-optional-in-api-models.md)
- [ ] [`URLComponents`로 URL 만들기](./119-urlcomponents-and-url-building.md)
- [ ] [`AsyncImage` — `Image`와 무엇이 다른가](./121-async-image.md)
- [ ] [URL 탐지의 원리와 `NSDataDetector`의 `matches` API](./122-nsdatadetector-and-url-detection.md)
- [ ] [테스트에서 외부 API를 모킹하고 주입하는 방법](./123-dependency-injection-for-testing.md)
- [ ] [`#if !targetEnvironment(simulator)` — 시뮬레이터와 실기기 차이](./124-simulator-vs-device-behavior.md)

## 9. 로컬 데이터와 SwiftData

저장 프레임워크의 큰 그림을 본 뒤 모델, 컨테이너, 조회, 관계, 동시성 순으로 깊게 들어간다.

- [ ] [Core Data와 SwiftData — 개념, 구조, 동시성, 마이그레이션과 선택 기준](./125-core-data-vs-swiftdata.md)
- [ ] [SwiftData `@Model`은 왜 class이고 `final`은 필수인가](./126-swiftdata-model-class-and-final.md)
- [ ] [SwiftData `ModelContainer`, `ModelContext`, configuration과 in-memory 저장소](./127-swiftdata-container-context-and-configuration.md)
- [ ] [SwiftData `@Query` — 실행 시점, 조건·정렬과 query 디버깅](./128-swiftdata-query-and-debugging.md)
- [ ] [SwiftData의 식별자 — `PersistentIdentifier`, 중복 데이터와 업데이트](./129-swiftdata-identity-and-updates.md)
- [ ] [SwiftData relationship과 연관 데이터 조회 — SQL JOIN과의 차이](./130-swiftdata-relationships-and-fetching.md)
- [ ] [SwiftData 저장 위치, 보안, 용량과 성능](./131-swiftdata-storage-security-and-performance.md)
- [ ] [SwiftData 동시성 — 메인 스레드, 동일 context, 데이터 충돌과 `@MainActor`](./132-swiftdata-concurrency-and-context-isolation.md)
- [ ] [Preview의 mock container — 무엇이 주입되고 `static var`는 매번 실행되는가](./133-swiftdata-preview-mock-container.md)
- [ ] [`PreviewModifier` — preview에 container가 주입되는 원리와 shared context](./134-preview-modifier-and-shared-context.md)

## 10. 기능별 Apple 프레임워크와 유틸리티

앞 단계의 언어·상태·동시성 지식을 실제 기능 API에 적용한다. 이 단계의 항목끼리는 의존성이 낮으므로 필요한 기능부터 골라도 된다.

- [ ] [`UserNotifications` 프레임워크와 delegate](./135-user-notifications-framework.md)
- [ ] [GameKit과 GameplayKit — 게임 서비스와 게임 로직 도구](./137-gamekit-and-gameplaykit.md)
- [ ] [통화 코드로 국기 이모지 만들기 — `compactMap`과 유니코드](./138-flag-emoji-from-unicode-scalars.md)
- [ ] [API 키를 앱에 넣는 방법과 그 한계 — xcconfig, Info.plist, CI/CD](./120-api-key-security-and-environment-variables.md)
- [ ] [AVFoundation은 무슨 모듈인가](./136-avfoundation-framework.md)
- [ ] [Swift의 async/await 실행 모델 — JavaScript·Python과 무엇이 다른가](./101-swift-async-await-model.md)
- [ ] [`dataTaskPublisher` vs `URLSession.data` — Combine과 async/await](./114-combine-vs-async-await.md)

## 완료 기준

각 문서의 학습 체크리스트를 마치고 현재 예제에 적용된 개념을 설명할 수 있으면 완료로 표시한다. 한 단계가 너무 길다면 모든 항목을 끝내기보다, 현재 학습 중인 챕터와 직접 연결된 문서를 우선 완료하고 다음 단계의 첫 항목을 미리 살펴봐도 된다.
