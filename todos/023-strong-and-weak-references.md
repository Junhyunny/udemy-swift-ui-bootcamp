# Swift의 강한 참조와 약한 참조 — 객체가 사라지지 않는 이유

화면에서 나간 뷰 모델의 `deinit`이 호출되지 않는다면 어디부터 살펴봐야 할까? 해당 객체에 남아 있는 **강한 참조와 그 참조를 소유한 곳**을 확인하면 원인을 찾을 수 있다. 이 글은 객체와 참조의 관계부터 시작해 순환 참조가 생기는 과정과 약한 참조로 소유 관계를 수정하는 방법을 다룬다. ARC의 실행 흐름과 객체 수명 예제는 Apple의 [WWDC21 세션 「ARC in Swift: Basics and beyond」](https://developer.apple.com/videos/play/wwdc2021/10216/)를 참고해 새로 작성했다.

## 먼저: 객체와 참조는 무엇인가

클래스의 인스턴스를 생성하면 객체 하나가 만들어진다. 클래스 타입 변수에는 객체 자체가 복사되어 들어가는 것이 아니라, **그 객체를 참조하는 값**이 저장된다. 그 값을 다른 변수에 대입하면 새 객체를 생성하지 않고 두 변수가 같은 인스턴스를 참조한다.

```swift
final class Box {
    var number = 1
    deinit { print("Box 해제") }
}

var first: Box? = Box()   // Box 객체 한 개를 만든다
var second = first        // 새 Box를 만들지 않고 같은 객체를 가리킨다
print(first === second)   // true: 두 참조의 대상이 같다
first?.number = 10
print(second?.number ?? -1) // 10: 한 객체를 공유한다

first = nil               // first의 참조를 제거한다
print(second?.number ?? -1) // 10: 객체는 여전히 살아 있다
second = nil              // 마지막 강한 참조를 제거한다
```

```text
first  ──┐
         ├──→ Box(number: 10) 한 개
second ──┘
```

`first`와 `second`는 각각 같은 `Box` 인스턴스에 대한 참조를 저장한다. `first?.number = 10`으로 인스턴스의 프로퍼티를 변경하면 `second`를 통해 읽은 값도 10이다. `first = nil`은 `first`에 저장된 참조를 제거할 뿐 객체를 직접 해제하지 않는다. `second`의 강한 참조가 남아 있으므로 객체를 계속 사용할 수 있다. `second = nil`까지 실행해 강한 참조가 없어지면 객체가 해제된다. `===`는 두 클래스 참조가 같은 인스턴스를 가리키는지 확인한다.

## 1. 강한 참조가 객체의 수명을 유지한다

Swift의 클래스 인스턴스는 ARC(Automatic Reference Counting)가 수명을 관리한다. 변수나 프로퍼티에 인스턴스를 담으면 기본적으로 **강한 참조**가 생긴다. 강한 참조가 하나라도 남아 있으면 인스턴스는 해제되지 않는다. `struct`와 `enum`은 값 타입이므로 이 참조 카운팅의 대상이 아니다.

```swift
final class Person {
    let name: String

    init(_ name: String) { self.name = name }
    deinit { print("\(name) 해제") }
}

var first: Person? = Person("민수")
var second = first       // 같은 인스턴스를 강하게 참조
first = nil              // second의 강한 참조가 남아 있으므로 아직 해제되지 않는다
second = nil             // 마지막 강한 참조가 사라져 deinit 호출
```

`deinit`은 클래스 인스턴스가 해제되기 직전에 호출된다. 파일·타이머 같은 자원을 정리할 수 있고, 학습 중에는 객체 수명을 관찰하는 표식으로도 유용하다.

### ARC가 참조를 세는 흐름

**Retain**은 강한 참조 하나가 새로 시작될 때 대상 객체의 참조 카운트를 1 올리는 동작이다. **Release**는 그 강한 참조가 더는 필요하지 않을 때 카운트를 1 내리는 동작이다. `release` 한 번이 곧 객체 해제를 뜻하지는 않는다. 다른 강한 참조가 남아 있으면 객체도 남는다. 반대로 카운트가 0이 되면 `deinit`을 실행하고, 정리 후 객체의 메모리를 해제할 수 있다. ARC는 이 retain·release를 컴파일러가 배치해 자동으로 수행한다.

위의 `Person` 예제를 한 단계씩 따라가 보자. 아래 숫자는 **각 참조가 코드에 표시된 대입 시점까지 유지된다고 가정한 설명용 카운트**다.

| 단계 | 실행한 코드 | `Person("민수")`의 강한 참조 | 설명용 카운트 | 객체 상태 |
| --- | --- | --- | ---: | --- |
| 1 | `var first: Person? = Person("민수")` | `first` | 1 | 객체를 만들고 최초 참조를 얻는다. 생성 자체가 카운트 1을 마련하므로 별도 retain을 하나 더 더하지 않는다. |
| 2 | `var second = first` | `first`, `second` | 2 | 참조를 복사한다. 객체를 복사하는 것이 아니라 새 강한 참조가 시작되어 개념적으로 retain한다. |
| 3 | `first = nil` | `second` | 1 | `first`에 저장됐던 참조가 제거되므로 개념적으로 release한다. 카운트가 1이므로 `deinit`은 아직 호출되지 않는다. |
| 4 | `second = nil` | 없음 | 0 | 마지막 강한 참조가 끝난다. `deinit`이 호출되고 객체가 해제된다. |

그래서 `first = nil` 직후에도 `second?.name`을 읽을 수 있다. `first`를 다른 `Person`으로 다시 대입해도 이전 객체에 대한 참조는 제거된다. 새 객체에 대한 참조는 새로 시작된다. **retain은 새 강한 참조를 추가하고, release는 기존 강한 참조를 제거한다**고 이해하면 된다.

프로퍼티에서도 같은 일이 일어난다. 아래 부모·자식 예제에서 `parent.child = child`는 부모 객체의 프로퍼티에 자식 객체에 대한 **새 강한 참조**를 저장한다. 이후 `parent.child = nil` 또는 다른 자식으로 교체하면 이전 자식에 대한 참조가 제거된다. 함수가 실행되는 동안 필요한 참조나 클로저가 강하게 캡처해 보관한 참조도 수명에 영향을 준다. 이들 참조가 모두 끝나야 객체가 해제된다. `weak` 참조는 이 카운트에 참여하지 않는다.

### 컴파일러는 retain·release를 어디에 넣을까?

ARC의 핵심은 개발자가 소스에 `retain()`과 `release()`를 직접 쓰지 않아도, **컴파일할 때 참조의 시작과 마지막 사용을 분석해 필요한 연산을 생성한다**는 것이다. 프로그램을 실행하면 생성된 연산이 참조 카운트를 올리거나 내린다. 다음 예제는 [Apple의 WWDC21 설명](https://developer.apple.com/videos/play/wwdc2021/10216/)과 같은 흐름을 더 짧게 쓴 것이다.

```swift
final class Traveler {
    var destination = ""
}

func travel() {
    let traveler1 = Traveler()           // 최초 참조: 생성 결과가 이미 소유권을 가진다
    let traveler2 = traveler1            // 두 번째 강한 참조: 개념적으로 retain
    traveler2.destination = "Big Sur"    // traveler2의 마지막 사용
}
```

컴파일러가 이 함수의 참조 수명을 처리하는 방식을 **의사 코드**로 쓰면 다음과 같다. `RC`는 Reference Count(참조 카운트)다. 아래 `retain`, `release`, `RC` 표기는 이해를 위한 것이며 실제 Swift 문법이나 컴파일 결과를 그대로 옮긴 것이 아니다.

```text
func travel() {
    traveler1 = allocateAndInitialize(Traveler) // 객체 생성과 초기화: RC = 1

    retain(traveler1)                            // 새 강한 참조 준비: RC 1 → 2
    traveler2 = traveler1                        // 객체 복사 없이 참조만 복사
    release(traveler1)                           // traveler1의 마지막 사용 후: RC 2 → 1

    traveler2.destination = "Big Sur"           // traveler2의 마지막 사용
    release(traveler2)                           // RC 1 → 0: deinit 실행 후 메모리 해제
}
```

1. `Traveler()`가 객체를 생성해 최초의 소유 참조를 돌려준다. 이때 카운트는 개념적으로 1이며, 첫 참조를 위해 retain을 **추가로** 호출하지 않는다.
2. `traveler2 = traveler1`에서 같은 객체를 가리키는 강한 참조가 하나 더 필요하다. 컴파일러는 그 참조를 유지할 연산을 마련한다. 설명용 카운트는 2다.
3. `traveler1`의 마지막 사용은 참조를 복사한 순간이다. 그 뒤 `traveler1`의 소유권이 끝나면 release할 수 있다. 설명용 카운트는 1이다.
4. `traveler2.destination`을 마지막으로 사용한 뒤 두 번째 소유권도 끝난다. release로 카운트가 0이 되면 `deinit`을 거쳐 객체가 해제된다.

즉 **컴파일 시점에는** 필요한 소유권 연산을 생성하고, **런타임에는** 그 연산이 실행되어 RC가 변한다. 마지막 `release`로 RC가 실제로 0이 되면 `deinit`이 실행된 뒤 객체의 메모리가 해제된다. 다만 객체의 **보장된 최소 수명**은 초기화부터 마지막 사용까지이며, 의사 코드처럼 반드시 마지막 사용 직후 해제되는 것은 아니다.

이 연산은 **Swift 소스 코드에 새 줄로 삽입되어 보이는 것이 아니다.** 컴파일 결과의 중간 표현인 SIL(Swift Intermediate Language)을 출력하면 컴파일러가 만든 소유권 연산을 살펴볼 수 있다. 위 코드를 `ARCExample.swift`로 저장하고 다음 명령을 실행한다.

```sh
swiftc -emit-sil -Onone ARCExample.swift | grep -E 'strong_retain|strong_release'
```

예를 들어 이 예제를 `-Onone`으로 컴파일한 SIL에는 `strong_retain` 한 번과 `strong_release` 두 번이 나타난다. 두 release 중 하나는 최초 참조를, 다른 하나는 복사된 참조를 제거한다. **SIL에 나타난 위치와 소스 코드 한 줄을 항상 일대일로 연결할 수는 없다.** 실제로 이 예제의 SIL에서는 의사 코드와 달리 두 release가 `destination` 대입 뒤에 모여 있다. Swift 버전과 최적화 설정에 따라 `copy_value`·`destroy_value` 같은 다른 소유권 명령으로 표현되거나 불필요한 retain·release가 제거될 수도 있다. `deinit` 출력은 **최종 해제 시점**을 보여 줄 뿐, 중간의 모든 retain·release를 보여 주지는 않는다.

### 지역 변수의 마지막 사용과 실제 해제 시점

지역 변수의 강한 참조가 반드시 함수의 닫는 중괄호까지 유지되는 것은 아니다. WWDC 세션의 흐름처럼 다음 코드를 따라가 보자.

```swift
func editProfile() {
    let first = Person("지은")
    let second = first
    print(second.name)       // second를 마지막으로 사용
    print("편집 완료")
}
```

1. `Person("지은")`을 만들면 객체의 카운트가 개념적으로 1에서 시작하고 `first`가 가리킨다.
2. `let second = first`에서 새 강한 참조가 생기므로 개념적으로 retain하여 2가 된다. `first`의 **마지막 사용**은 이 복사다.
3. `first`가 더 필요 없어지면 release로 1이 된다. `second`가 남아 있으므로 객체는 살아 있다.
4. `print(second.name)`이 `second`의 마지막 사용이다. 이 참조도 끝나 release로 0이 되면 `deinit`이 호출되고 객체를 해제할 수 있다.
5. 마지막 줄의 `print("편집 완료")`는 `Person`을 사용하지 않는다. 따라서 이 줄까지 객체가 반드시 살아 있어야 하는 것은 아니다.

이는 **소유 관계를 이해하기 위한 단계**이지 각 소스 줄에 반드시 retain·release 명령 하나씩 대응한다는 뜻은 아니다. 컴파일러는 불필요한 연산을 합치거나 옮길 수 있다. Swift가 보장하는 최소 수명은 **초기화부터 마지막 사용까지**이고, 실제 관찰되는 수명은 그보다 길어질 수 있다. 그래서 `deinit`의 출력이 `"편집 완료"`보다 먼저 나올 수도, 뒤에 나올 수도 있다. `deinit`은 카운트가 실제로 0이 되어 해제될 때 한 번 호출되며, 중간 단계의 release마다 호출되지 않는다. 출력 순서에 꼭 필요한 작업이라면 `deinit`에 기대지 말고 명시적으로 실행한다.

## 2. 두 객체가 서로 강하게 참조하면

두 객체가 서로를 강하게 참조하면 순환 참조가 생긴다. 부모가 자식을 소유하는 관계에서 자식도 부모를 강하게 참조하면, 외부의 참조가 모두 사라진 뒤에도 두 객체의 참조 카운트가 0이 되지 않는다.

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

참조 카운트를 개념적으로 적으면 두 객체가 생성될 때는 각각 1이다. `parent.child = child`로 자식의 카운트가 2가 되고, `child.parent = parent`로 부모의 카운트도 2가 된다. 외부 변수 `parent`와 `child`를 `nil`로 바꿔도 각각 **1이 남는다**. 남은 참조는 두 객체의 프로퍼티에 저장되어 있다.

ARC는 참조 카운트를 관리하지만, 순환 참조에 포함된 객체가 외부에서 더는 사용되지 않는지는 판단하지 않는다. 객체를 해제하려면 **순환 참조에 포함된 강한 참조 하나를 제거하거나 약한 참조로 변경해야 한다**.

## 3. 약한 참조는 소유하지 않는다

이 관계에서 부모가 자식을 소유하고 자식은 부모를 가리키기만 한다면, 자식의 참조를 `weak`으로 바꾼다.

```swift
final class Child {
    weak var parent: Parent?
}
```

약한 참조는 대상의 참조 카운트를 늘리지 않는다. 대상이 해제되면 자동으로 `nil`이 되므로 `weak` 프로퍼티는 옵셔널이다. 위 코드에서는 다른 강한 참조가 없다면 `parent = nil`로 부모가 해제되고, `child = nil`로 자식도 해제된다.

이전 예제에서 자식의 `parent` 프로퍼티를 `weak`으로 바꾸면 해제 순서는 다음과 같다.

1. 외부의 `parent`와 `child`가 각각 객체를 강하게 가리킨다. 부모의 `child` 프로퍼티도 자식을 강하게 가리키지만, 자식의 `parent`는 약하므로 부모의 카운트를 늘리지 않는다.
2. `parent = nil`로 부모에 대한 마지막 강한 참조를 제거하면 부모의 `deinit`이 호출된다. 부모 객체가 해제되면서 `child` 프로퍼티에 저장된 강한 참조도 제거되고, 자식의 약한 `parent`는 `nil`이 된다.
3. 외부 변수 `child`의 강한 참조가 남아 있으므로 자식은 살아 있다. `child = nil`로 그 마지막 참조까지 제거하면 자식의 `deinit`이 호출된다.

이 번호는 **소유 관계를 따라가는 설명용 순서**이며, 최적화된 코드의 정확한 release 명령 위치를 뜻하지 않는다.

`weak` 프로퍼티는 대상 객체를 참조하지만 소유하지 않으며, 대상의 참조 카운트를 증가시키지 않는다. 부모·자식처럼 수명이 다른 두 객체 중 어느 쪽이 다른 쪽을 소유하는지 먼저 결정해야 한다.

| 참조 | 참조 카운트 | 대상이 해제되면 | 선택 기준 |
| --- | --- | --- | --- |
| 기본 강한 참조 | 증가 | 대상이 살아 있는 동안 접근 가능 | 이 쪽이 대상을 소유한다 |
| `weak` | 증가하지 않음 | 자동으로 `nil` | 대상이 먼저 사라질 수 있다 |
| `unowned` | 증가하지 않음 | 접근하면 런타임 오류 | 참조를 사용하는 동안 대상이 반드시 살아 있다 |

`unowned`도 소유하지 않지만, `weak`처럼 자동으로 `nil`이 되지 않는다. 대상의 수명 보장이 틀리면 프로그램이 중단된다. 예컨대 자식이 존재하는 동안 부모가 반드시 살아 있다는 관계를 설계로 보장할 수 있을 때 검토한다. 둘 중 무엇을 쓸지는 실행 속도보다 **대상이 먼저 사라질 가능성**으로 판단한다.

### 약한 참조를 읽을 때 객체가 살아 있으리라는 보장은 없다

`weak`으로 순환을 끊었더라도, 그 약한 참조를 **읽는 순간**에 대상이 살아 있는지는 별개의 문제다. 아래 예제에서 `profile`의 마지막 강한 사용은 `badge.owner = profile`이다. 이후 `badge`가 `owner`를 읽을 때 `profile`이 이미 해제됐을 수도 있다.

```swift
final class Profile {
    let name: String
    var badge: Badge?

    init(_ name: String) { self.name = name }

    func printSummary() {
        print("\(name): \(badge?.points ?? 0)점")
    }
}

final class Badge {
    weak var owner: Profile?
    let points: Int

    init(points: Int) { self.points = points }

    func printSummary() {
        guard let owner else {
            print("프로필이 없어 요약을 표시할 수 없음")
            return
        }
        print("\(owner.name): \(points)점")
    }
}

func showBadge() {
    let profile = Profile("지은")
    let badge = Badge(points: 100)
    profile.badge = badge
    badge.owner = profile      // profile의 마지막 강한 사용
    badge.printSummary()      // profile이 살아 있으면 출력, 아니면 건너뜀
}
```

`guard let`은 크래시를 막지만, 요약이 조용히 빠지는 버그까지 해결하지는 못한다. **프로필이 반드시 필요한 작업이라면 강한 참조로 접근하게 API를 설계하는 편이 낫다.** 예를 들어 `profile.printSummary()`를 호출하면 메서드가 실행되는 동안 `profile`이 필요하다는 관계가 코드에 드러난다.

기존 API를 바로 바꾸기 어렵다면 `withExtendedLifetime`으로 필요한 구간까지 수명을 명시할 수 있다. 위 함수의 마지막 줄을 다음 코드로 바꾸면, 클로저가 끝날 때까지 `profile`의 수명이 유지된다.

```swift
withExtendedLifetime(profile) {
    badge.printSummary()
}
```

다만 이 방법은 호출하는 모든 곳에서 수명 연장을 기억해야 한다. `Badge`가 프로필의 이름만 필요하다면 그 값을 직접 보관하도록 관계를 바꾸는 편이 더 단순할 수도 있다. **약한 참조로 순환을 제거하는 것과, 필요한 작업 동안 대상의 수명을 보장하는 것은 다른 문제**다.

## 4. 클로저도 객체를 강하게 참조할 수 있다

강한 참조는 객체의 프로퍼티 사이에서만 생기지 않는다. 클로저는 기본적으로 캡처한 클래스 인스턴스를 강하게 참조한다. 클래스가 그 클로저를 프로퍼티에 저장하고, 클로저가 다시 그 클래스의 `self`를 캡처하면 순환 참조가 생긴다.

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

이 저장소의 `chapter-80/chapter-80/ViewModels/ViewModel.swift`도 같은 구조다. 뷰 모델이 `AnyCancellable`을 보관하고, `sink` 콜백이 뷰 모델을 캡처한다. `[weak self]`로 콜백의 강한 참조를 없애 순환 참조를 방지한다. 구독 토큰이 해제될 때의 자동 취소는 [Combine 구독 수명](./112-combine-cancellable-and-store.md)에 정리했다.

```swift
.sink { [weak self] value in
    self?.exchangeRate = value
}
.store(in: &cancellableSet)
```

## 5. 언제 약한 참조를 사용해야 할까

모든 클로저에 `[weak self]`를 붙이면 콜백이 조용히 건너뛰어져야 하는지까지 불분명해진다. 다음 순서로 판단한다.

1. 캡처하는 대상이 클래스 인스턴스인가?
2. 클로저나 구독이 함수 호출 뒤에도 보관되는가?
3. 그 보관 주체를 대상 인스턴스가 다시 소유하는가?
4. 대상이 콜백 전에 해제되어도 되는가?

2·3번으로 순환 참조가 생기면 소유 관계를 바꾸거나 `[weak self]`를 사용한다. 4번의 답이 "아니오"라면 작업의 수명과 취소 방식을 다시 설계한다. 즉시 끝나는 `map` 같은 클로저에는 보통 순환이 없다. `Task`도 작업이 끝나면 캡처한 강한 참조를 제거하지만, 오래 실행되거나 끝나지 않는 반복이라면 객체의 수명이 계속 유지될 수 있다. SwiftUI `View` 자체는 값 타입이지만 클로저가 별도의 클래스 객체를 캡처한다면 그 객체의 소유 관계를 확인한다.

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

`strong` 객체는 지역 범위를 나간 뒤에도 순환 참조 때문에 해제되지 않는다. `callbacks.action = nil`로 순환을 제거하면 `deinit`이 호출된다. `weak` 객체는 범위를 벗어나며 해제된다. 마지막 외부 콜백을 실행해도 이미 해제된 객체는 다시 생성되지 않는다. 예제에서 `startWeak(in:)`의 `[weak self]`를 `[self]`로 바꾸려면 `guard let self`도 지워야 한다. 그 뒤 다시 실행하면 `weak 해제됨: false`로 바뀐다.

## 결론 — 강한 참조의 소유 관계를 확인한다

강한 참조는 대상 객체의 수명을 유지한다. 약한 참조는 객체를 소유하지 않으며 참조 카운트를 늘리지 않는다. 메모리 누수가 의심되면 **객체 → 저장된 클로저·구독 → 객체**처럼 강한 참조를 저장하는 위치를 확인한다. 순환 참조가 확인되면 소유 관계를 바꾸거나 한쪽을 약한 참조로 변경한다. `deinit` 호출 여부로 객체가 해제됐는지 확인할 수 있다.

## 학습 체크리스트

- [ ] 두 변수가 같은 클래스 인스턴스를 가리킬 때 마지막 강한 참조를 해제하고 `deinit`을 확인한다.
- [ ] `editProfile()`에서 마지막 사용과 닫는 중괄호의 차이를 설명한다.
- [ ] `travel()`의 의사 코드에서 생성 시 RC 1, 참조 복사 시 retain, 두 참조의 마지막 사용 후 release를 구분한다.
- [ ] 부모·자식이 서로를 강하게 참조하는 예제를 만들고 한쪽을 `weak`으로 바꾼다.
- [ ] `showBadge()`에서 약한 참조 접근이 건너뛰어질 수 있는 이유와 두 해결 방법을 설명한다.
- [ ] Playground에서 강한 캡처와 약한 캡처의 `deinit` 순서를 비교한다.
- [ ] `[weak self]` 이후 `guard let self`가 참조를 유지하는 범위를 설명한다.
- [ ] 클로저가 저장되는 위치와 그 저장 위치의 소유자를 그림으로 표시한다.
- [ ] `weak`과 `unowned` 중 대상이 먼저 해제될 가능성에 맞는 것을 고른다.

## 공식 참고 자료

- **1절 — 강한 참조와 ARC:** [The Swift Programming Language: Automatic Reference Counting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/) — 클래스 인스턴스의 참조 카운팅과 기본 강한 참조를 설명한다.
- **1절 — 객체 해제 시점:** [The Swift Programming Language: Deinitialization](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/deinitialization/) — `deinit`이 호출되는 시점과 용도를 설명한다.
- **2절 — 두 클래스 사이의 순환:** [ARC — Strong Reference Cycles Between Class Instances](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Strong-Reference-Cycles-Between-Class-Instances) — 두 객체가 서로를 강하게 참조하는 사례를 다룬다.
- **3절 — `weak`과 `unowned`:** [ARC — Weak References](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Weak-References), [ARC — Unowned References](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Unowned-References) — 대상 해제 후 동작과 수명 조건을 비교할 때 참고한다.
- **4절 — 클로저의 순환 참조:** [ARC — Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Strong-Reference-Cycles-for-Closures), [ARC — Resolving Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Resolving-Strong-Reference-Cycles-for-Closures) — 저장된 클로저와 인스턴스 사이의 순환 및 해결 방법을 설명한다.
- **4절 — 캡처 리스트 문법:** [The Swift Programming Language: Expressions — Capture Lists](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/#Capture-Lists) — `[self]`, `[weak self]`, `[unowned self]`의 캡처 방식을 확인할 수 있다.
- **4절 — Combine 구독 토큰:** [Apple: AnyCancellable](https://developer.apple.com/documentation/combine/anycancellable) — 토큰이 해제될 때 자동으로 구독을 취소하는 동작을 명시한다.
- **ARC의 실제 흐름과 수명 함정:** [WWDC21: ARC in Swift: Basics and beyond](https://developer.apple.com/videos/play/wwdc2021/10216/) — [ARC 예제 1:49](https://developer.apple.com/videos/play/wwdc2021/10216/?time=109), [순환 참조 6:37](https://developer.apple.com/videos/play/wwdc2021/10216/?time=397), [약한 참조 9:05](https://developer.apple.com/videos/play/wwdc2021/10216/?time=545), [약한 참조와 객체 수명 10:05](https://developer.apple.com/videos/play/wwdc2021/10216/?time=605), [안전한 수명 보장 11:45](https://developer.apple.com/videos/play/wwdc2021/10216/?time=705), [deinit 부작용 15:23](https://developer.apple.com/videos/play/wwdc2021/10216/?time=923) 순서로 보면 이 글의 예제와 연결된다.
- **컴파일러의 SIL과 ARC 최적화:** [Swift.org: Swift Compiler](https://www.swift.org/documentation/swift-compiler/) — SIL 단계에서 ARC를 최적화하는 과정을 소개한다.
- **필요한 구간의 수명 보장:** [Apple: withExtendedLifetime(_:_:)](https://developer.apple.com/documentation/swift/withextendedlifetime%28_%3A_%3A%29-4mmpv) — 클로저 실행이 끝날 때까지 객체 수명을 유지하는 API다.
