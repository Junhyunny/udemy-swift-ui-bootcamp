# 5단계 — `actor`와 재진입(reentrancy)

[로드맵](./142-swift-concurrency-roadmap.md)의 5단계다. 여기부터가 Swift Concurrency의 핵심이고, Swift 6에서 가장 많은 에러를 만나는 지점이다.

관련 기존 문서: [`actor` 타입 — 무엇이고 왜 쓰는가](./107-swift-actor-type.md)

## 왜 필요한가 — data race를 직접 본다

평범한 `class`를 여러 작업이 동시에 건드리면 어떻게 되는지 실제로 측정했다. 100,000번 증가를 5회 반복한 결과다.

```swift
final class UnsafeCounter: @unchecked Sendable { var value = 0 }

await withTaskGroup(of: Void.self) { g in
    for _ in 0..<100_000 { g.addTask { u.value += 1 } }
}
```

```text
  1회차: 96779 / 100000 ← 유실
  2회차: 97604 / 100000 ← 유실
  3회차: 96950 / 100000 ← 유실
  4회차: 96916 / 100000 ← 유실
  5회차: 98117 / 100000 ← 유실
```

**매번 3% 안팎이 사라지고, 사라지는 양도 매번 다르다.** `value += 1`은 읽기·더하기·쓰기 세 단계라, 두 작업이 같은 값을 읽으면 증가 한 번이 없어진다.

여기서 배울 것은 숫자가 아니라 **비결정성**이다. 실행할 때마다 결과가 달라지므로 테스트로 잡을 수 없다. Swift가 이 문제를 런타임 검사가 아니라 **컴파일 타임 검사**로 옮긴 이유가 이것이다.

같은 코드를 `actor`로 바꾸면 이렇게 된다.

```swift
actor Counter {
    var value = 0
    func increment() { value += 1 }
}
```

```text
① actor 1000회 증가: 1000 (1000이면 정상)
```

## actor가 하는 일

> Swift guarantees that only code running on an actor can access that actor's local state. This guarantee is known as *actor isolation*.

actor는 자신의 가변 상태를 **한 번에 하나의 작업만** 만지도록 직렬화한다. 락을 직접 걸지 않아도 되고, 락을 빠뜨릴 수도 없다.

```swift
await counter.increment()     // 밖에서는 await 가 필요하다
```

**안과 밖의 규칙이 다르다.**

| | actor 안 | actor 밖 |
| --- | --- | --- |
| 프로퍼티 읽기 | 그냥 | `await` |
| 프로퍼티 쓰기 | 그냥 | **불가능** (메서드를 통해야 함) |
| 메서드 호출 | 그냥 | `await` |

밖에서 프로퍼티에 직접 대입할 수 없다는 점이 중요하다. `counter.value = 5`는 컴파일 에러다. 상태 변경은 actor가 제공하는 메서드를 통해서만 가능하다.

`class`, `struct`, `actor`의 비교와 언제 쓰는지는 [107 문서](./107-swift-actor-type.md)에 정리되어 있다.

## 재진입 — actor가 막아 주지 **않는** 것

가장 오해하기 쉬운 부분이다. **actor는 "한 번에 하나"를 보장하지만 "중간에 끼어들지 않음"을 보장하지 않는다.**

`await`를 만나면 actor는 중단되고, **그 사이 다른 호출이 actor에 들어올 수 있다.** 직접 재현했다.

```swift
actor Bank {
    var balance = 100
    func withdraw(_ amount: Int, tag: String) async -> Bool {
        guard balance >= amount else { return false }   // ① 검사
        try? await Task.sleep(for: .milliseconds(50))    // ② 중단 — 여기서 끼어든다
        balance -= amount                                 // ③ 반영
        return true
    }
}

async let w1 = bank.withdraw(100, tag: "A")
async let w2 = bank.withdraw(100, tag: "B")
```

```text
② 잔액 100에서 100씩 두 번 출금 → -100 (음수면 재진입 문제)
   A 검사통과 balance=100
   B 검사통과 balance=100     ← A 가 중단된 사이에 B 가 들어왔다
   A 차감후 balance=0
   B 차감후 balance=-100
```

**잔액 100에서 100씩 두 번 빠져나가 -100이 됐다.** actor를 썼는데도 논리가 깨졌다.

원인은 `await`가 있는 자리에서 **검사와 반영 사이가 벌어졌기** 때문이다. A가 검사를 통과하고 잠든 사이 B가 들어와 같은(이미 낡은) 잔액을 보고 검사를 통과했다.

### 어떻게 막나

**① 검사와 반영 사이에 `await`를 두지 않는다.** 가장 확실하다.

```swift
func withdraw(_ amount: Int) -> Bool {      // async 가 아니다 = 중단점이 없다
    guard balance >= amount else { return false }
    balance -= amount
    return true
}
```

**② `await` 이후에 상태를 다시 검사한다.**

```swift
try await someDelay()
guard balance >= amount else { return false }   // 다시 확인
balance -= amount
```

**③ 진행 중 표시를 둔다.**

```swift
var inFlight: Set<String> = []
guard !inFlight.contains(id) else { return false }
inFlight.insert(id)
defer { inFlight.remove(id) }
```

**경험칙 — actor 메서드에서 `await`를 만나면, 그 앞에서 읽은 모든 상태는 낡았다고 가정한다.**

## 성능과 설계 주의

- actor 호출마다 **격리 전환 비용**이 든다. 잘게 쪼갠 호출을 반복하면 느려진다. 한 번의 호출로 묶어서 처리하는 편이 낫다.
- actor에 **UI 상태를 넣지 않는다.** UI는 6단계의 `@MainActor` 영역이다.
- actor를 통과하는 값은 `Sendable`이어야 한다(7단계).

## 학습 체크리스트

- [ ] `class` 카운터를 `TaskGroup`으로 10만 번 증가시켜 값이 유실되는 것을 확인한다.
- [ ] 같은 코드를 여러 번 실행해 결과가 매번 다른 것(비결정성)을 확인한다.
- [ ] `actor`로 바꿔 값이 정확해지는 것을 확인한다.
- [ ] actor 밖에서 프로퍼티에 직접 대입해 컴파일 에러를 확인한다.
- [ ] actor 밖에서 `await` 없이 메서드를 호출해 에러 문구를 읽는다.
- [ ] `Bank` 재진입 예제를 재현해 잔액이 음수가 되는 것을 확인한다.
- [ ] `withdraw`에서 `await`를 제거해 문제가 사라지는지 확인한다.
- [ ] `await` 이후 재검사를 넣는 방식으로도 고쳐 본다.
- [ ] actor 메서드를 잘게 여러 번 호출하는 코드와 한 번에 처리하는 코드의 시간을 비교한다.
- [ ] actor에 비`Sendable` 타입을 넘겨 어떤 에러가 나는지 본다.

## 공식 참고 자료

- [Swift Book: Concurrency — Actors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)
- [Apple: Actor](https://developer.apple.com/documentation/swift/actor)
- [SE-0306: Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md)
- [SE-0306: Actor reentrancy (제안서 내 절)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md#actor-reentrancy)
- [WWDC21: Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [Swift 컴파일러 진단: actor-isolated call](https://docs.swift.org/compiler/documentation/diagnostics/actor-isolated-call/)
