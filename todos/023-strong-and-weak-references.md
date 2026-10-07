# Swift의 강한 참조와 약한 참조 — 객체가 사라지지 않는 이유

화면에서 나간 뷰 모델의 `deinit`이 호출되지 않는다면 어디부터 살펴봐야 할까? 이 질문은 `weak` 키워드부터 외우는 것보다 **누가 객체를 붙잡고 있는지** 따라가면 풀린다. 이 글은 강한 참조로 시작해 순환 참조가 생기는 순간을 확인하고, 약한 참조로 소유 관계를 바로잡는 과정을 다룬다.

## 1. 강한 참조가 객체를 살린다

Swift의 클래스 인스턴스는 ARC(Automatic Reference Counting)가 수명을 관리한다. 변수나 프로퍼티에 인스턴스를 담으면 기본적으로 **강한 참조**가 생긴다. 강한 참조가 하나라도 남아 있으면 인스턴스는 해제되지 않는다. `struct`와 `enum`은 값 타입이므로 이 참조 카운팅의 대상이 아니다.

```swift
final class Person {
    let name: String

    init(_ name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

var first: Person? = Person("민수")
var second = first       // 같은 인스턴스를 강하게 참조
first = nil              // second가 붙잡고 있으므로 아직 해제되지 않는다
second = nil             // 마지막 강한 참조가 사라져 deinit 호출
```

`deinit`은 클래스 인스턴스가 해제되기 직전에 호출된다. 파일·타이머 같은 자원을 정리할 수 있고, 학습 중에는 객체 수명을 관찰하는 표식으로도 유용하다. 실제 수명은 최적화와 주변 코드의 참조에 영향을 받으므로, **마지막 강한 참조가 사라졌는지**를 기준으로 해석한다.

## 2. 두 객체가 서로를 붙잡으면

문제는 참조가 원을 그릴 때 생긴다. 부모가 자식을 소유하는 것은 자연스럽지만 자식까지 부모를 강하게 붙잡으면, 바깥의 참조가 사라져도 두 객체는 서로의 참조 카운트를 유지한다.

```swift
final class Parent {
    var child: Child?
    deinit { print("Parent 해제") }
}

final class Child {
    var parent: Parent?
    deinit { print("Child 해제") }
}

var parent: Parent? = Parent()
var child: Child? = Child()
parent?.child = child
child?.parent = parent
parent = nil
child = nil                // 두 deinit 모두 호출되지 않는다
```

```text
Parent ──강한 참조──→ Child
   ↑                    │
   └────강한 참조────────┘
```

ARC는 참조 개수를 셀 뿐, 이 고리가 외부에서 더는 필요하지 않은지는 판단하지 않는다. 추적 기반 GC와 달리 Swift에서는 **순환을 만드는 참조 중 하나를 끊어야 한다**.

## 3. 약한 참조는 소유하지 않는다

이 관계에서 부모가 자식을 소유하고 자식은 부모를 가리키기만 한다면, 자식의 참조를 `weak`으로 바꾼다.

```swift
final class Child {
    weak var parent: Parent?
}
```

약한 참조는 대상의 참조 카운트를 늘리지 않는다. 대상이 해제되면 자동으로 `nil`이 되므로 `weak` 프로퍼티는 옵셔널이다. 위 코드에서는 다른 강한 참조가 없다면 `parent = nil`로 부모가 해제되고, `child = nil`로 자식도 해제된다.

`weak`은 "메모리 문제를 막는 장식"이 아니라 **소유하지 않는 관계의 표시**다. 부모·자식처럼 수명이 다른 두 객체 중 어느 쪽이 다른 쪽을 소유하는지 먼저 결정해야 한다.

| 참조 | 참조 카운트 | 대상이 해제되면 | 선택 기준 |
| --- | --- | --- | --- |
| 기본 강한 참조 | 증가 | 대상이 살아 있는 동안 접근 가능 | 이 쪽이 대상을 소유한다 |
| `weak` | 증가하지 않음 | 자동으로 `nil` | 대상이 먼저 사라질 수 있다 |
| `unowned` | 증가하지 않음 | 접근하면 런타임 오류 | 참조를 사용하는 동안 대상이 반드시 살아 있다 |

`unowned`도 소유하지 않지만, `weak`처럼 자동으로 `nil`이 되지 않는다. 대상의 수명 보장이 틀리면 프로그램이 중단된다. 예컨대 자식이 존재하는 동안 부모가 반드시 살아 있다는 관계를 설계로 보장할 수 있을 때 검토한다. 둘 중 무엇을 쓸지는 실행 속도보다 **대상이 먼저 사라질 가능성**으로 판단한다.

## 4. 클로저도 객체를 붙잡을 수 있다

강한 참조는 프로퍼티 사이에서만 생기지 않는다. 클로저는 기본적으로 캡처한 클래스 인스턴스를 강하게 참조한다. 클래스가 그 클로저를 프로퍼티에 저장하고, 클로저가 다시 그 클래스의 `self`를 캡처하면 고리가 완성된다.

```swift
final class ViewModel {
    var onUpdate: (() -> Void)?
    var count = 0

    func start() {
        onUpdate = { self.count += 1 }
    }
}
```

```text
ViewModel ──→ onUpdate 클로저 ──→ ViewModel
```

`self.`는 현재 인스턴스를 사용한다는 표기이지 약한 참조를 뜻하지 않는다. `[self]`를 캡처 리스트에 적어도 강한 캡처다. 반대로 `onUpdate`가 다른 객체에 저장되어 있고 그 객체를 `ViewModel`이 소유하지 않는다면, `self`를 강하게 캡처해도 이 경로만으로는 순환이 되지 않는다. **클로저가 어디에 보관되는지**가 핵심이다.

순환을 끊어야 하고 콜백 시점에 뷰 모델이 이미 사라져도 괜찮다면 `[weak self]`를 쓴다.

```swift
onUpdate = { [weak self] in
    self?.count += 1
}
```

약하게 캡처한 `self`는 옵셔널이다. 위 `start()`의 대입을 여러 줄로 바꾸면 다음처럼 쓸 수 있다.

```swift
onUpdate = { [weak self] in
    guard let self else { return }
    self.count += 1
    print(self.count)
}
```

`guard let self`가 성공하면 **그 클로저가 실행되는 동안에는 강한 지역 참조**가 생긴다. 콜백이 끝나면 이 참조도 사라진다. 축약 문법 자체는 [옵셔널 바인딩](./158-conditional-statements-complete-guide.md)에 정리했다.

이 저장소의 `chapter-80/chapter-80/ViewModels/ViewModel.swift`도 같은 구조다. 뷰 모델이 `AnyCancellable`을 보관하고, `sink` 콜백이 뷰 모델을 캡처한다. `[weak self]`는 그 고리를 끊는다. 구독 토큰이 해제될 때의 자동 취소는 [Combine 구독 수명](./112-combine-cancellable-and-store.md)에 정리했다.

```swift
.sink { [weak self] value in
    self?.exchangeRate = value
}
.store(in: &cancellableSet)
```

## 5. 언제 약하게 잡아야 할까

모든 클로저에 `[weak self]`를 붙이면 콜백이 조용히 건너뛰어져야 하는지까지 불분명해진다. 다음 순서로 판단한다.

1. 캡처하는 대상이 클래스 인스턴스인가?
2. 클로저나 구독이 함수 호출 뒤에도 보관되는가?
3. 그 보관 주체를 대상 인스턴스가 다시 소유하는가?
4. 대상이 콜백 전에 해제되어도 되는가?

2·3번이 고리를 만들면 소유 관계를 바꾸거나 `[weak self]`로 끊는다. 4번의 답이 "아니오"라면 무조건 약하게 잡기보다 작업의 수명과 취소 방식을 다시 설계한다. 즉시 끝나는 `map` 같은 클로저에는 보통 순환이 없다. `Task`도 작업이 끝나면 캡처를 놓지만, 오래 실행되거나 끝나지 않는 반복이라면 객체가 계속 살아 있을 수 있다. SwiftUI `View` 자체는 값 타입이지만 클로저가 별도의 클래스 객체를 캡처한다면 그 객체의 소유 관계를 확인한다.

## 6. Playground에서 수명 확인하기

아래 코드 전체를 Xcode의 macOS 또는 iOS **Blank Playground**에 붙여 넣고 콘솔을 본다. SwiftUI와 Combine 없이 강한 참조, 순환 참조, 약한 캡처를 재현한다.

```swift
final class CallbackBox {
    var action: (() -> Void)?
    func fire() { action?() }
}

final class Owner {
    let name: String
    let callbacks = CallbackBox()

    init(_ name: String) { self.name = name }
    deinit { print("\(name) deinit") }
    func report() { print("\(name) 실행") }

    func startStrong() {
        callbacks.action = { self.report() }
    }

    func startWeak(in box: CallbackBox) {
        box.action = { [weak self] in
            guard let self else {
                print("소유자 없음")
                return
            }
            self.report()
        }
    }
}

weak var strongProbe: Owner?
do {
    let owner = Owner("strong")
    strongProbe = owner
    owner.startStrong()
    owner.callbacks.fire()
}
print("strong 살아 있음: \(strongProbe != nil)")
strongProbe?.callbacks.action = nil   // 순환을 직접 끊는다
print("strong 해제됨: \(strongProbe == nil)")

weak var weakProbe: Owner?
do {
    let owner = Owner("weak")
    weakProbe = owner
    owner.startWeak(in: owner.callbacks)
    owner.callbacks.fire()
}
print("weak 해제됨: \(weakProbe == nil)")

let externalBox = CallbackBox()
do {
    let owner = Owner("external")
    owner.startWeak(in: externalBox)
    externalBox.fire()
}
externalBox.fire()                  // owner가 사라졌으므로 "소유자 없음"
```

`strong`은 지역 범위를 나간 뒤에도 살아 있다. `callbacks.action = nil`로 고리를 끊으면 비로소 `deinit`이 나온다. `weak`은 범위를 벗어나며 해제된다. 마지막 외부 콜백은 이미 해제된 객체를 되살리지 않는다. 예제에서 `startWeak(in:)`의 `[weak self]`를 `[self]`로 바꾸려면 `guard let self`도 지워야 한다. 그 뒤 다시 실행하면 `weak 해제됨: false`로 바뀐다.

## 결론 — 참조의 방향을 그려 본다

강한 참조는 객체가 필요한 동안 살려 둔다. 약한 참조는 객체를 소유하지 않고 바라본다. 누수가 의심되면 `weak`을 기계적으로 추가하기 전에 **객체 → 저장된 클로저·구독 → 객체**처럼 참조의 방향을 그려 본다. 고리가 확인되면 소유 관계를 바꾸거나 한쪽을 약하게 만든다. `deinit`이 호출되는지 관찰하면 수정 결과를 확인할 수 있다.

## 학습 체크리스트

- [ ] 두 변수가 같은 클래스 인스턴스를 가리킬 때 마지막 강한 참조를 해제하고 `deinit`을 확인한다.
- [ ] 부모·자식이 서로를 강하게 참조하는 예제를 만들고 한쪽을 `weak`으로 바꾼다.
- [ ] Playground에서 강한 캡처와 약한 캡처의 `deinit` 순서를 비교한다.
- [ ] `[weak self]` 이후 `guard let self`가 참조를 유지하는 범위를 설명한다.
- [ ] 클로저가 저장되는 위치와 그 저장 위치의 소유자를 그림으로 표시한다.
- [ ] `weak`과 `unowned` 중 대상이 먼저 해제될 가능성에 맞는 것을 고른다.

## 공식 참고 자료

- [The Swift Programming Language: Automatic Reference Counting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)
- [The Swift Programming Language: Deinitialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/deinitialization/)
- [The Swift Programming Language: Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/)
- [The Swift Programming Language: Expressions — Capture Lists](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Capture-Lists)
- [Apple: AnyCancellable](https://developer.apple.com/documentation/combine/anycancellable)
