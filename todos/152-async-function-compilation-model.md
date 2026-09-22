# 비동기 실행 모델 (3) — 컴파일러가 `async` 함수를 무엇으로 바꾸는가

"Swift 비동기 실행 모델"은 **세 층**으로 나눠 보면 정리가 된다. 이 저장소에는 이미 두 층이 있고, 이 문서가 나머지 한 층을 채운다.

| 층 | 답하는 질문 | 문서 |
| --- | --- | --- |
| **의미론** | `await`는 무슨 뜻인가, JS와 무엇이 다른가 | [101](./101-swift-async-await-model.md), [143](./143-sync-vs-async-and-suspension.md), [144](./144-async-await-basics.md) |
| **런타임** | 실제로 누가 실행하는가 — Task, Job, Executor, 스레드 풀 | 블로그 「스위프트 비동기 처리 아키텍처」, 실측은 [151](./151-concurrency-runtime-architecture.md) |
| **컴파일** | `async` 함수는 어떤 코드로 바뀌는가 | **이 문서** |

세 층은 같은 것을 다른 배율로 보는 것이다. 런타임 층이 "잡(Job)이 실행자에 들어간다"고 말할 때, **그 잡이 어떻게 만들어지는지**가 여기에 있다.

측정은 **Swift 6.3.3**에서 `swiftc -emit-sil` / `-emit-ir`로 직접 확인했다. 6부에 재현 명령이 있다.

## 1부 — `async` 함수는 보통 함수가 아니다

SIL(Swift Intermediate Language)을 뽑아 보면 호출 규약부터 다르다.

```swift
func fetch() async -> Int { 1 }
func load() async -> Int { ... }
```

```text
sil hidden @$s3sil5fetchSiyYaF : $@convention(thin) @async () -> Int
sil hidden @$s3sil4loadSiyYaF  : $@convention(thin) @async () -> Int
```

`@async`가 붙어 있다. **동기 함수와 ABI가 아예 다르다.**

동기 함수는 "스택에 프레임을 쌓고, 끝나면 반환 주소로 돌아간다"는 모델이다. async 함수는 중간에 멈췄다가 **다른 스레드에서** 이어질 수 있어야 하므로 이 모델을 쓸 수 없다. 스레드를 반납하는 순간 그 스택은 다른 작업이 써 버리기 때문이다.

그래서 async 함수는 **코루틴**으로 컴파일된다.

## 2부 — 함수가 토막 난다

컴파일러는 `await`를 경계로 함수를 쪼갠다. 블로그 글에서 말한 **잡(Job)** 이 이 토막이다.

```text
func load() async -> Int {
    let a = await fetch()     ─┐ 토막 1: 시작 ~ 첫 await
    let b = await fetch()     ─┤ 토막 2: 첫 재개 ~ 둘째 await
    return a + b              ─┘ 토막 3: 둘째 재개 ~ 반환
}
```

LLVM IR에서 전환 호출이 실제로 나타난다.

```text
   2 swift_task_switch
   3 swift_task_alloc
   3 swift_task_dealloc
```

`await`가 두 개인 함수에서 `swift_task_switch`가 두 번이다. 이것이 "중단하고 재개 지점을 등록한다"에 해당하는 런타임 호출이다.

**함수 하나가 한 스레드에서 쭉 도는 것이 아니라, 토막들이 각각 스케줄링된다.** 블로그 글의 `await` 순서도가 이 토막 단위로 일어나는 일이다.

## 3부 — 프레임은 힙에 있고, 크기는 컴파일 타임에 정해진다

여기가 이 층에서 가장 실용적인 부분이다.

async 함수마다 **async context(비동기 프레임)** 의 크기가 심볼에 박힌다. `Tu` 접미사가 그 심볼이다.

```text
$s...5fetchSiyYaFTu = hidden global %swift.async_func_pointer <{ ..., i32 16 }>
$s...4loadSiyYaFTu  = hidden global %swift.async_func_pointer <{ ..., i32 80 }>
```

마지막 숫자가 **바이트 단위 프레임 크기**다. 지역 변수와 중단점을 늘려 가며 측정했다.

```text
noLocals    (await 0개, 지역변수 없음)  →  16 bytes
threeLocals (await 3개, 지역변수 3개)   →  96 bytes
manyLocals  (await 6개, 지역변수 7개)   → 224 bytes
```

동기 함수에는 이 심볼이 아예 없다.

```text
syncFunction 의 async_func_pointer 개수: 0
```

**여기서 세 가지가 설명된다.**

- **`await`를 가로질러 살아남아야 하는 값만 프레임에 들어간다.** 그래서 크기가 커진다. 블로그 글의 "비동기 프레임"이 바로 이것이고, 이 문서는 **그 크기를 측정한다**
- **크기가 컴파일 타임에 결정된다.** 런타임에 얼마나 필요할지 계산하지 않으므로 할당이 싸다
- 할당은 `swift_task_alloc` / `swift_task_dealloc`이 담당한다. 태스크마다 스택처럼 동작하는 **전용 할당자(bump allocator)** 라 일반 `malloc`보다 훨씬 가볍다

재귀 async 함수가 스레드 스택을 터뜨리지 않는 이유도 이것이다. 프레임이 스택이 아니라 태스크 할당자 위에 쌓인다.

## 4부 — 실행자 전환은 명령어다

액터 격리는 문법 장식이 아니라 **SIL 명령어로 내려간다.**

```swift
@MainActor func onMain() async -> Int { 1 }
func caller() async -> Int { await onMain() }
```

```text
hop_to_executor 개수: 1
  hop_to_executor %2
```

`hop_to_executor`가 "지금 실행자를 저쪽으로 바꿔라"는 지시다. 블로그 글의 그림에서 **잡이 다른 실행자 큐로 옮겨지는 지점**이 이 명령어다.

이 사실에서 성능 감각이 하나 생긴다. **격리 경계를 자주 넘나들면 `hop_to_executor`가 그만큼 늘어난다.** actor 메서드를 잘게 여러 번 호출하는 것보다 한 번에 묶는 편이 낫다는 [Swift 액터 완전 정복](./153-swift-actor-complete-guide.md)의 조언이 여기서 근거를 얻는다.

Swift 6.2에서 비격리 async 함수의 기본이 `nonisolated(nonsending)`(호출자를 따라감)으로 바뀐 것도 **불필요한 hop을 줄이려는 변경**이다. [Swift 액터 완전 정복](./153-swift-actor-complete-guide.md) 3.8절의 측정 결과와 연결된다.

## 5부 — 이 층을 알면 설명되는 것들

앞 문서들에서 "그렇다"고만 하고 넘어간 것들이 여기서 근거를 얻는다.

| 현상 | 컴파일 층의 이유 |
| --- | --- |
| `await` 앞뒤로 스레드가 다를 수 있다 | 토막마다 따로 스케줄링된다 (2부) |
| 중단해도 지역 변수가 살아 있다 | 프레임이 힙에 있다 (3부) |
| 재귀 async가 스택을 안 터뜨린다 | 태스크 할당자를 쓴다 (3부) |
| actor 재진입이 생긴다 | 토막 경계에서 실행자를 놓는다 (2·4부) |
| 블로킹이 치명적이다 | 토막이 끝나야 스레드가 반납된다 (2부) |
| `await`는 선점이 아니다 | 중단점은 컴파일 타임에 고정된다 (2부) |
| 격리 경계 통과에 비용이 있다 | `hop_to_executor` (4부) |

**`await`가 소스 코드에 반드시 보여야 하는 이유**도 여기서 나온다. 컴파일러가 그 자리에서 함수를 쪼개야 하므로, 중단점은 문법으로 표시되어야만 한다. 임의의 지점에서 멈추는 선점형 모델이 아니다.

## 6부 — 직접 확인하는 법

이 문서의 모든 수치는 아래로 재현할 수 있다.

```bash
# 1. async 함수의 SIL 시그니처와 실행자 전환
swiftc -emit-sil a.swift | grep -E "@async|hop_to_executor"

# 2. 코루틴 런타임 호출
swiftc -emit-ir a.swift | grep -oE "swift_task_switch|swift_task_alloc|swift_task_dealloc" | sort | uniq -c

# 3. async 프레임 크기 (마지막 i32 값이 바이트)
swiftc -emit-ir a.swift | grep "async_func_pointer"
```

지역 변수를 늘리거나 `await`를 추가하면서 3번 숫자가 어떻게 변하는지 보는 것이 가장 직관적이다.

> 주의: SIL과 IR은 **구현 세부 사항**이다. 최적화 수준과 컴파일러 버전에 따라 달라지므로, 앱 로직이나 테스트의 전제로 삼으면 안 된다. 이해를 돕는 관찰 도구로만 쓴다.

## 학습 체크리스트

- [ ] `swiftc -emit-sil`로 async 함수와 동기 함수의 시그니처 차이(`@async`)를 확인한다.
- [ ] `await` 개수를 늘려 가며 `swift_task_switch` 호출 수가 함께 느는지 본다.
- [ ] `async_func_pointer`의 크기 값을 찾아 읽는다.
- [ ] 지역 변수를 추가해 프레임 크기가 커지는 것을 확인한다.
- [ ] `await`를 가로지르지 않는 지역 변수를 추가하고 크기 변화를 비교한다.
- [ ] 동기 함수에는 `async_func_pointer`가 없는 것을 확인한다.
- [ ] `@MainActor` 함수를 호출하는 코드에서 `hop_to_executor`를 찾는다.
- [ ] 격리를 제거하고 `hop_to_executor`가 사라지는지 비교한다.
- [ ] 재귀 async 함수를 깊게 호출해 스택 오버플로가 나지 않는 것을 확인한다.
- [ ] 같은 깊이의 동기 재귀 함수와 비교한다.
- [ ] `-O` 최적화를 켜고 같은 관찰을 반복해 숫자가 달라지는 것을 확인한다.

## 공식 참고 자료

- [WWDC21: Swift concurrency — Behind the scenes](https://developer.apple.com/videos/play/wwdc2021/10254/)
- [SE-0296: Async/await](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0296-async-await.md)
- [swiftlang/swift: docs/SIL/Instructions.md (`hop_to_executor` 등)](https://github.com/swiftlang/swift/blob/main/docs/SIL/Instructions.md)
- [swiftlang/swift: docs/ABI/Mangling.rst (심볼 접미사)](https://github.com/swiftlang/swift/blob/main/docs/ABI/Mangling.rst)
- [swiftlang/swift: stdlib/public/Concurrency/Task.cpp](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/Task.cpp)
- [LLVM: Coroutines in LLVM](https://llvm.org/docs/Coroutines.html)
- [Swift Forums: How is the Cooperative Thread Pool integrated in Swift?](https://forums.swift.org/t/how-is-the-cooperative-thread-pool-integrated-in-swift/67466)
