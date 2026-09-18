# 6단계 — `@MainActor`와 전역 액터

[로드맵](./142-swift-concurrency-roadmap.md)의 6단계다. 5단계의 액터 개념을 **전역에 하나뿐인 액터**로 확장한다.

관련 기존 문서: [`MainActor`와 iOS 스레드 모델](./106-main-actor-and-ios-threading.md), [`nonisolated` 키워드](./108-nonisolated-keyword.md), [액터 격리 — 격리 도메인](./139-actor-isolation-domains.md)

## `@MainActor`는 특별한 문법이 아니라 액터다

> A global actor is a globally-unique actor identified by a type.

`@MainActor`는 전역 액터의 한 사례일 뿐이고, 직접 만들 수도 있다. 자세한 것은 [139 문서](./139-actor-isolation-domains.md)의 2부에 있다.

```swift
@MainActor
@Observable
final class UserViewModel {
    var user: User?
    func load() async { user = await api.fetchUser() }
}
```

타입에 붙이면 **그 안의 모든 프로퍼티와 메서드가 메인 액터에 격리**된다.

## 가장 중요한 오해 — 스레드가 아니라 액터다

```text
❌ "@MainActor = 항상 main thread 에서 실행"
✅ "@MainActor = MainActor 에 isolated 되어 있다"
```

실용적으로는 메인 스레드에서 도는 것이 맞지만, **개념을 스레드로 이해하면 나머지가 틀어진다.**

- 커스텀 전역 액터는 특정 스레드에 묶이지 않는다. 보장하는 것은 "동시에 하나만"이지 "항상 같은 스레드"가 아니다
- `await` 전후로 스레드가 바뀔 수 있지만 액터 격리는 유지된다
- 컴파일러가 검사하는 것은 스레드가 아니라 격리 도메인이다

**Swift Concurrency에서는 스레드와 액터를 분리해서 생각해야 한다.** 스레드는 실행 자원이고, 액터는 접근 권한 경계다.

## 격리를 어기면 나오는 에러

직접 재현한 결과다.

```swift
@MainActor final class VM { var name = "" }
func update(_ vm: VM) { vm.name = "x" }      // nonisolated 함수
```

```text
error: main actor-isolated property 'name' can not be mutated from a nonisolated context
```

**에러 문구에 도메인 이름이 그대로 나온다.** "main actor-isolated 프로퍼티를 nonisolated 문맥에서 바꿨다"는 뜻이다. 이 문장 구조를 읽을 줄 알면 대부분의 동시성 에러를 스스로 해결할 수 있다.

고치는 방법은 셋이다.

```swift
@MainActor func update(_ vm: VM) { vm.name = "x" }        // ① 함수도 메인 액터로
func update(_ vm: VM) async { await MainActor.run { vm.name = "x" } }  // ② 건너가기
```

## `MainActor.run`과 `assumeIsolated`의 차이

헷갈리기 쉬운 둘이다.

```swift
await MainActor.run { ui.text = "갱신됨" }     // 전환 — 메인으로 건너간다
MainActor.assumeIsolated { ui.text }           // 확인 — 이미 메인임을 단언
```

```text
③ detached 위치: 백그라운드
③ MainActor.run 이후 값: 갱신됨
```

| | `MainActor.run` | `MainActor.assumeIsolated` |
| --- | --- | --- |
| 하는 일 | 메인 액터로 **전환** | 이미 메인이라고 **단언** |
| `await` | 필요 | 불필요 |
| 메인이 아니면 | 전환해 준다 | **크래시** |
| 쓰는 곳 | 비격리 async 문맥 | 정적으로 증명 못 하는 델리게이트 콜백 |

`assumeIsolated`는 전환이 아니다. 잘못 쓰면 "가끔 죽는" 버그가 된다.

## `Task { }`의 액터 컨텍스트

3단계에서 측정한 결과가 여기서 의미를 갖는다.

```text
② 호출자: 메인 / 우선순위 TaskPriority.medium
   Task{}        : 메인 / TaskPriority.high
   Task.detached : 백그라운드 / TaskPriority.medium
```

**`Task { }`는 만들어진 자리의 액터를 상속한다.** 그래서 `@MainActor` 문맥에서 만든 `Task { }` 안에서는 UI 상태를 그냥 바꿀 수 있고, `MainActor.run`이 필요 없다.

```swift
@MainActor
func onTap() {
    Task {                       // 메인 액터를 상속
        let data = await load()  // 중단 — 이 사이 다른 일 진행
        self.items = data        // 다시 메인 액터, 그냥 대입 가능
    }
}
```

`Task.detached`는 상속을 끊으므로 같은 코드가 에러가 된다. **UI를 만지는 작업에 `Task.detached`를 쓰지 않는 이유다.**

## `nonisolated` — 액터에서 빠져나오기

기본 격리가 `MainActor`로 설정된 모듈(이 저장소의 69개 챕터)에서는 **아무것도 안 붙인 선언이 이미 `@MainActor`** 다. 그래서 반대 방향의 표시가 필요해진다.

```swift
nonisolated func pureCalculation(_ x: Int) -> Int { x * 2 }
```

`Shape.path(in:)`처럼 프로토콜 요구사항이 비격리인 경우 이것이 필수가 된다. 재현과 해결책은 [108 문서](./108-nonisolated-keyword.md)에 자세하다.

비동기 함수에서는 `nonisolated`가 두 갈래로 나뉜다 — 호출자를 따라가는 `nonisolated(nonsending)`과 떠나는 `@concurrent`다. 측정 결과와 설명은 [139 문서](./139-actor-isolation-domains.md)의 3부에 있다.

## 어디에 붙이나

| 대상 | 권장 |
| --- | --- |
| ViewModel (UI 상태 보유) | **타입 전체에 `@MainActor`** |
| SwiftUI `View` | 이미 `@MainActor` (붙일 필요 없음) |
| 네트워크·파일 서비스 | 붙이지 않음 (호출자를 따라가게) |
| 공유 가변 상태 | `actor` (5단계) |
| 순수 계산 함수 | `nonisolated` |

**타입 전체에 붙이는 편이 메서드마다 붙이는 것보다 낫다.** 격리가 타입의 성질이 되어 빠뜨릴 수 없다.

## 학습 체크리스트

- [ ] `@MainActor` 클래스의 프로퍼티를 비격리 함수에서 바꿔 에러 문구를 읽는다.
- [ ] 같은 코드를 `@MainActor` 함수로 바꿔 에러가 사라지는지 확인한다.
- [ ] `MainActor.run`으로 백그라운드에서 UI 상태를 갱신해 본다.
- [ ] `MainActor.assumeIsolated`를 메인이 아닌 곳에서 호출해 크래시하는 것을 확인한다.
- [ ] `@MainActor` 문맥에서 `Task { }`와 `Task.detached { }`의 차이를 `Thread.isMainThread`로 비교한다.
- [ ] `Task.detached` 안에서 UI 상태를 바꿔 에러를 확인한다.
- [ ] `@globalActor`로 커스텀 전역 액터를 만들어 본다.
- [ ] 순수 계산 함수에 `nonisolated`를 붙여 보고 무엇이 달라지는지 확인한다.
- [ ] 이 저장소의 `SWIFT_DEFAULT_ACTOR_ISOLATION` 설정을 확인하고 `nonisolated`로 바꿔 어떤 에러가 새로 나오는지 본다.

## 공식 참고 자료

- [Apple: MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Apple: MainActor.run(resultType:body:)](https://developer.apple.com/documentation/swift/mainactor/run(resulttype:body:))
- [Apple: MainActor.assumeIsolated(_:file:line:)](https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:))
- [Apple: GlobalActor](https://developer.apple.com/documentation/swift/globalactor)
- [SE-0316: Global actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md)
- [SE-0461: Run nonisolated async functions on the caller's actor by default](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)
- [SE-0466: Control default actor isolation inference](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)
- [WWDC25: Embracing Swift concurrency](https://developer.apple.com/videos/play/wwdc2025/268/)
