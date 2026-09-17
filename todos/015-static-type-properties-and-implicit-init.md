# `static` 타입 프로퍼티와 `.init` — 장단점과 함정

## 질문이 나온 코드

`chapter-34/chapter-34/ContentView.swift`의 `extension DTCourse { static var sample: [DTCourse] { [ .init(...), ... ] } }`

## 공부할 내용

### "정적 멤버 변수"가 맞다 — 다만 이건 **계산** 타입 프로퍼티다

> "You can also define properties that belong to the type itself, not to any one instance of that type. There will only ever be one copy of these properties, no matter how many instances of that type you create. These kinds of properties are called type properties."
>
> "You define type properties with the `static` keyword."

여기서 중요한 구분이 하나 있다.

> "Stored type properties can be variables or constants. Computed type properties are always declared as variable properties, in the same way as computed instance properties."

```swift
static var stored = [DTCourse]()        // 저장 타입 프로퍼티 — 값이 한 벌 유지된다
static var sample: [DTCourse] { [...] } // 계산 타입 프로퍼티 — 접근할 때마다 새로 만든다
```

지금 코드는 `{ }` 블록을 가진 **계산 타입 프로퍼티**다. 즉 **`DTCourse.sample`을 읽을 때마다 배열이 새로 생성된다.** 어디엔가 저장돼 공유되는 값이 아니다. 읽기 전용인데도 `let`이 아니라 `var`인 이유는 위 인용대로 계산 프로퍼티가 항상 `var`여야 하기 때문이다.

이 사실이 뒤에 나올 스레드 이야기의 답을 거의 정해 버린다.

### `.init(...)`은 무엇인가 — implicit member expression

> "An implicit member expression is an abbreviated way to access a member of a type, such as an enumeration case or a type method, in a context where type inference can determine the implied type. It has the following form: `.<member name>`"

**타입이 문맥에서 추론될 때 타입 이름을 생략하는 문법**이다. `.photo1`이 `ImageResource.photo1`인 것과 정확히 같은 원리다.

```swift
static var sample: [DTCourse] {
    [
        .init(image: .photo1, ...),   // = DTCourse.init(...)  = DTCourse(...)
    ]
}
```

반환 타입이 `[DTCourse]`라고 이미 적혀 있으니, 배열 리터럴 안의 원소 타입은 `DTCourse`로 추론된다. 그래서 `DTCourse`를 생략하고 `.init`만 쓴 것이다.

`init`은 특별한 이름이 아니라 초기화 메서드의 실제 이름이다. `DTCourse(...)`와 `DTCourse.init(...)`은 같은 뜻이고, 여기서 타입 이름을 생략하면 `.init(...)`이 된다. `DTCourse`가 초기화 메서드를 직접 정의하지 않았으므로 여기 쓰이는 것은 컴파일러가 만들어 준 **memberwise initializer**다.

취향의 문제이긴 하나, 코드를 읽는 사람 입장에서는 `DTCourse(...)`라고 명시하는 편이 무엇을 만드는지 바로 보인다. 반대로 타입 이름이 아주 길거나 문맥이 명확하면 `.init`이 깔끔하다.

### "싱글 스레드니까 static을 써도 되나" — 전제부터 점검이 필요하다

**iOS 앱은 싱글 스레드가 아니다.** UI 갱신이 main actor에서 일어날 뿐, 네트워킹·파일 IO·`Task`·`async let`은 다른 실행 문맥에서 돈다. 그래서 "클라이언트니까 안전하다"는 전제는 성립하지 않는다.

Swift의 규칙을 짚어 보자. **저장** 타입 프로퍼티에 대해서는 초기화 자체는 안전하다.

> "Stored type properties are lazily initialized on their first access. They're guaranteed to be initialized only once, even when accessed by multiple threads simultaneously, and they don't need to be marked with the `lazy` modifier."

즉 **초기화는 한 번만** 보장된다. 문제는 그 다음, **초기화된 뒤의 읽기/쓰기**다. Swift 6의 strict concurrency는 전역·정적 가변 상태를 데이터 레이스 위험으로 보고 컴파일 단계에서 막는다. SE-0412는 모든 전역 변수가 **global actor에 격리되거나, 불변이면서 `Sendable`** 이어야 한다고 요구한다. 전역은 어디서든 접근 가능해서 다른 격리 수단이 통하지 않기 때문이다.

이 기준으로 지금 코드를 보면 **안전하다.** `sample`은 계산 프로퍼티라 공유되는 저장소가 없고, 호출할 때마다 새 배열을 만들어 돌려준다. 쓰기도 불가능하다.

반면 아래처럼 바꾸면 이야기가 달라진다.

```swift
static var sample: [DTCourse] = [ ... ]   // 저장 + 가변 → 공유 가변 상태
```

이건 누구나 읽고 **쓸 수 있는** 한 벌의 값이다. 한 화면에서 `DTCourse.sample.append(...)`를 하면 다른 화면에도 영향이 간다. Swift 6에서는 오류로 잡힌다. 해결책은 셋 중 하나다.

- `static let`으로 불변화 (원소 타입이 `Sendable`이어야 함)
- `@MainActor static var`로 격리
- 정말 직접 동기화하겠다면 `nonisolated(unsafe)` (정적 검사를 끄는 것이므로 최후의 수단)

### 장단점 정리

**장점**

- 인스턴스 없이 `DTCourse.sample`로 바로 접근된다. 프리뷰와 테스트 더미 데이터에 편하다.
- 관련 값이 타입 안에 이름공간으로 묶인다. 전역 변수보다 낫다는 것이 Swift의 설계 의도다.
- 계산 프로퍼티로 두면 매번 새 값이라 공유 상태 문제가 없다.

**단점**

- 저장 + 가변이면 **전역 가변 상태**가 되어 데이터 레이스와 예측 불가한 부작용을 부른다.
- 의존성이 코드에 숨는다. `DTCourse.sample`을 직접 참조하는 뷰는 다른 데이터로 갈아끼우기 어려워 **테스트가 힘들다.** 파라미터로 받는 편이 낫다.
- 계산 프로퍼티는 접근할 때마다 다시 만든다. 지금처럼 작은 배열이면 무시할 만하지만, `body` 안에서 무거운 계산을 하는 static 프로퍼티를 반복 호출하면 낭비다.
- 저장 프로퍼티는 앱이 끝날 때까지 메모리에 남는다.

**실무 기준**

- 샘플·프리뷰 데이터, 상수 모음 → `static let` 또는 계산 `static var`가 적절하다. 지금 코드는 여기에 해당한다.
- 앱의 진짜 상태 → static이 아니라 `@State`, `@Observable` 모델, 명시적 주입으로 관리한다.

## 학습 체크리스트

- [ ] `DTCourse.sample`을 두 번 호출해 `print`로 각 원소의 `id`가 달라지는 것을 확인한다(매번 새로 만들어짐).
- [ ] `static var sample: [DTCourse] { ... }`를 `static let sample: [DTCourse] = [ ... ]`로 바꾸고 `id`가 고정되는지 비교한다.
- [ ] 계산 프로퍼티를 `let`으로 바꿔 보고 왜 안 되는지 오류로 확인한다.
- [ ] `.init(...)`을 `DTCourse(...)`로 바꿔 동일하게 동작하는지 확인한다.
- [ ] 반환 타입 annotation을 지우면 `.init`이 왜 추론에 실패하는지 확인한다.
- [ ] `static var sample: [DTCourse] = [...]`로 만든 뒤 어딘가에서 `append` 해 보고 다른 화면에 영향이 가는지 관찰한다.
- [ ] 그 상태에서 Swift 6 언어 모드로 빌드해 어떤 경고나 오류가 나오는지 본다.
- [ ] `@MainActor static var`로 바꾸면 오류가 사라지는지 확인한다.
- [ ] `CardView`가 `DTCourse.sample`을 직접 참조하도록 바꿔 보고, 파라미터 주입 방식과 테스트 난이도를 비교한다.

## 참고 자료

- [The Swift Programming Language: Properties — Type Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/)
- [The Swift Programming Language: Expressions — Implicit Member Expression](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/)
- [The Swift Programming Language: Initialization — Memberwise Initializers](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/)
- [The Swift Programming Language: Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift Evolution SE-0412: Strict concurrency for global variables](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md)
- [Swift.org: Data Race Safety](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/dataracesafety/)
- [Swift.org: Common Problems (Global and Static Variables)](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems/)
- [Apple: Sendable](https://developer.apple.com/documentation/swift/sendable)
- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
