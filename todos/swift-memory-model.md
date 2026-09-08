# Swift의 메모리 구조 — JVM과 비교해서 이해하기

## 질문이 나온 코드

`chapter-47/chapter-47/ContentView.swift`

```swift
Color.clear
    .preference(
        key: SizePreferenceKey.self,
        value: proxy.size
    )
```

`SizePreferenceKey.self`처럼 타입 자체를 값으로 넘기는 코드를 보다 보면, 그 타입 정보가 어디에 어떻게 저장되는지가 궁금해진다. JVM의 힙·메서드 영역 같은 구분이 Swift에도 있는가?

## 공부할 내용

### 먼저 짚어야 할 것 — Swift에는 JVM 같은 "명세된 메모리 영역"이 없다

이 차이가 질문의 출발점이자 가장 중요한 답이다.

JVM은 **명세(specification)** 가 런타임 데이터 영역을 문서로 규정한다. Heap, Method Area, JVM Stack, PC Register, Native Method Stack이 명세에 이름으로 등장하고, 모든 JVM 구현이 이를 따른다.

Swift는 그렇지 않다. Swift 언어 문서 어디에도 "Swift 런타임은 다음 영역으로 구성된다"는 규정이 없다. 대신 Swift는 **의미론(semantics)** 을 정의하고, 실제 배치는 컴파일러와 런타임의 최적화에 맡긴다.

그래서 정확한 비교는 이렇게 된다.

| | JVM | Swift |
| --- | --- | --- |
| 메모리 영역 | **명세로 규정** | 명세 없음, 구현 세부사항 |
| 객체 배치 | 인스턴스는 원칙적으로 힙 | **타입의 성격**과 최적화가 결정 |
| 메모리 회수 | GC (추적 방식) | **ARC** (참조 카운팅, 컴파일 타임 삽입) |
| 회수 시점 | 비결정적 | **결정적** (참조가 0이 되는 즉시) |
| 순환 참조 | GC가 수거함 | **개발자가 끊어야 함** (`weak`/`unowned`) |
| 값 타입 | 원시 타입 8종뿐 | `struct`/`enum` 전부가 값 타입 |

**"Swift 메모리를 JVM처럼 영역으로 나눠 이해한다"는 접근 자체가 Swift에는 잘 맞지 않는다.** Swift에서 실질적으로 중요한 축은 영역 구분이 아니라 **값 타입이냐 참조 타입이냐**, 그리고 **ARC가 언제 해제하느냐**다.

### 축 ① 값 타입과 참조 타입 — Swift 메모리 이해의 출발점

ARC 문서의 첫 문장이 이 구분을 선언한다.

> Reference counting applies only to instances of classes. Structures and enumerations are value types, not reference types, and aren't stored and passed by reference.

즉 Swift의 타입은 두 부류로 갈리고, 메모리 동작이 완전히 다르다.

**값 타입 (`struct`, `enum`, 튜플)**

- 대입하면 **복사**된다. 원본과 사본이 독립적이다.
- 참조 카운팅 대상이 아니다. 오버헤드가 없다.
- 담긴 자리에 그대로 저장된다. 지역 변수면 스택, 클래스 프로퍼티면 그 클래스 인스턴스 안에.

```swift
var a = CGSize(width: 10, height: 10)
var b = a
b.width = 99
print(a.width)   // 10 — a는 영향 없음
```

`CGSize`, `CGRect`, `Int`, `String`, `Array`가 모두 값 타입이다. SwiftUI의 `View`들도 대부분 `struct`다.

**참조 타입 (`class`, actor, 클로저)**

- 대입하면 **같은 인스턴스를 가리킨다**. 한쪽을 고치면 다른 쪽에도 보인다.
- ARC가 참조 개수를 센다.

> Every time you create a new instance of a class, ARC allocates a chunk of memory to store information about that instance. This memory holds information about the type of the instance, together with the values of any stored properties associated with that instance.

인용문에 답이 하나 들어 있다. 클래스 인스턴스 메모리에는 **저장 프로퍼티 값뿐 아니라 타입 정보도 함께** 담긴다. JVM 객체 헤더가 클래스 포인터를 갖는 것과 비슷한 구조다.

값 타입과 참조 타입의 선택 기준은 [struct와 class](./struct-vs-class.md)에 정리했다.

### 축 ② ARC — GC가 아니다

이 차이가 JVM 경험자에게 가장 크게 다가오는 지점이다.

> Swift uses *Automatic Reference Counting* (ARC) to track and manage your app's memory usage. In most cases, this means that memory management "just works" in Swift, and you don't need to think about memory management yourself. ARC automatically frees up the memory used by class instances when those instances are no longer needed.

동작 방식은 이렇다.

> To make sure that instances don't disappear while they're still needed, ARC tracks how many properties, constants, and variables are currently referring to each class instance. ARC will not deallocate an instance as long as at least one active reference to that instance still exists.
>
> To make this possible, whenever you assign a class instance to a property, constant, or variable, that property, constant, or variable makes a *strong reference* to the instance.

**GC와의 결정적 차이 세 가지**

**1. 별도의 수거 스레드가 없다.** 컴파일러가 retain/release 호출을 코드에 끼워 넣는다. 런타임에 힙 전체를 훑는 단계가 없어서 GC pause가 없다. 대신 참조 카운트 증감 비용이 평소에 분산된다.

**2. 해제 시점이 결정적이다.** 참조가 0이 되는 그 순간 `deinit`이 불리고 메모리가 회수된다. JVM의 `finalize`가 언제 불릴지 모르는 것과 정반대다.

```swift
class Resource {
    deinit { print("해제됨") }   // 참조가 0이 되는 즉시 호출
}
```

**3. 순환 참조를 스스로 못 푼다.** 이게 가장 중요하다. GC는 루트에서 도달 불가능한 객체를 알아서 수거하지만, ARC는 서로를 가리키는 두 객체의 카운트가 각각 1로 남아 영원히 해제되지 않는다.

```swift
class Parent { var child: Child? }
class Child { var parent: Parent? }   // ⚠️ 강한 순환 참조

// 해결: 한쪽을 약한 참조로
class Child { weak var parent: Parent? }
```

| 키워드 | 카운트 증가 | nil 가능 | 쓰는 경우 |
| --- | --- | --- | --- |
| (기본) strong | O | 선택적 | 소유 관계 |
| `weak` | X | **항상 `Optional`** | 대상이 먼저 사라질 수 있음 |
| `unowned` | X | 아니오 | 대상이 자기보다 오래 산다고 확신할 때 |

클로저도 참조 타입이라 같은 함정이 있다. 클로저가 `self`를 캡처하고 그 클로저를 프로퍼티로 들고 있으면 순환이 생긴다. `[weak self]` 캡처 리스트가 이를 끊는다.

이 예제의 `@escaping (CGSize) -> Void`도 저장되는 클로저다. 지금 코드는 `struct` 안에서 값을 다뤄 문제가 없지만, `class` 기반 뷰 모델에서 같은 패턴을 쓸 때는 캡처를 신경 써야 한다.

### 축 ③ 타입 정보는 어디에 있나 — JVM 메서드 영역에 대응하는 것

질문의 `SizePreferenceKey.self`와 직접 연결되는 부분이다.

Swift 런타임도 각 타입에 대한 **type metadata**를 갖는다. 크기, 정렬, 프로퍼티 배치, 프로토콜 준수 정보 등이다. `SizePreferenceKey.self`가 값으로 다뤄질 수 있는 것은 이 메타데이터에 대한 참조를 넘기기 때문이다. 역할만 놓고 보면 JVM의 메서드 영역(클래스 메타데이터)과 비슷한 위치에 있다.

다만 **공식 문서가 이 저장소를 "영역"으로 규정하지는 않는다.** 컴파일 시점에 결정 가능한 대부분의 메타데이터는 실행 파일에 정적으로 박히고, 제네릭처럼 런타임에 필요한 경우에만 동적으로 만들어진다. `.self`의 언어 차원 의미는 [메타타입과 `.self`](./metatype-and-self.md)에 정리했다.

`static` 멤버도 여기 얹혀 있다. `SizePreferenceKey.defaultValue`는 인스턴스마다가 아니라 **타입당 하나**만 존재한다. JVM의 static 필드와 같은 발상이다. 이 예제의 키 타입이 인스턴스 없이 동작하는 이유이기도 하다.

### 축 ④ 메모리 배치를 직접 들여다보기 — `MemoryLayout`

추상적으로만 이해하지 말고 숫자로 확인할 수 있다.

```swift
struct Point {
    let x: Double
    let y: Double
    let isFilled: Bool
}
```

```swift
// MemoryLayout<Point>.size == 17
// MemoryLayout<Point>.stride == 24
// MemoryLayout<Point>.alignment == 8
```

세 값의 차이가 핵심이다.

- **`size`** — 실제로 값이 차지하는 바이트 수 (`8 + 8 + 1 = 17`)
- **`alignment`** — 정렬 요구치 (여기서는 8)
- **`stride`** — 배열에 연속으로 담을 때 한 원소가 차지하는 간격 (17을 8의 배수로 올림 → 24)

> Always use a multiple of a type's stride instead of its size when allocating memory or accounting for the distance between instances in memory.

이 예제에 대입해 보면 `MemoryLayout<CGSize>.size`는 16이다 (`CGFloat` 두 개). 값 타입이라 이만큼이 그대로 복사되어 다닌다.

클래스에 쓰면 다른 것이 나온다. `MemoryLayout<SomeClass>.size`는 인스턴스 크기가 아니라 **포인터 크기(8)** 다. 변수가 들고 있는 것이 참조이기 때문이다. 값 타입과 참조 타입의 차이를 숫자로 보여 주는 좋은 실험이다.

### 축 ⑤ 메모리 안전성 — 배타적 접근

Swift에는 JVM에 없는 규칙이 하나 더 있다.

> By default, Swift prevents unsafe behavior from happening in your code. For example, Swift ensures that variables are initialized before they're used, memory isn't accessed after it's been deallocated, and array indices are checked for out-of-bounds errors.
>
> Swift also makes sure that multiple accesses to the same area of memory don't conflict, by requiring code that modifies a location in memory to have exclusive access to that memory.

같은 메모리에 대한 쓰기 접근이 겹치면 컴파일 에러나 런타임 에러가 난다. 이 예제의 `reduce`가 쓰는 `inout`이 바로 이 규칙의 대상이다.

```swift
static func reduce(value: inout CGSize, nextValue: () -> CGSize)
```

`inout` 파라미터는 함수가 실행되는 동안 그 메모리에 **배타적 쓰기 접근**을 갖는다. 그래서 같은 변수를 두 `inout` 자리에 동시에 넘길 수 없다.

```swift
var size = CGSize.zero
someFunc(&size, &size)   // ⚠️ 겹치는 접근 — 에러
```

### JVM 개념을 Swift로 옮겨 읽는 대응표

완벽한 1:1은 없지만, 대응 관계를 잡아 두면 이해가 빠르다.

| JVM 개념 | Swift에서 대응하는 것 | 주의 |
| --- | --- | --- |
| Heap | 클래스 인스턴스가 놓이는 곳 | 명세된 영역이 아니라 구현 |
| Method Area / Metaspace | type metadata, `static` 멤버 | 상당 부분 실행 파일에 정적 배치 |
| JVM Stack (프레임, 지역변수) | 함수 호출 프레임, 값 타입 지역 변수 | 최적화로 배치가 달라질 수 있음 |
| Garbage Collector | **ARC** | 순환 참조를 못 푼다 — 핵심 차이 |
| `finalize` | `deinit` | ARC는 시점이 결정적 |
| 원시 타입 (`int`, `double`) | 모든 `struct`/`enum` | 값 타입의 범위가 훨씬 넓다 |
| 참조 타입 (모든 객체) | `class`, actor, 클로저 | Swift에서는 오히려 소수파 |
| `WeakReference` | `weak` | Swift는 언어 키워드 |
| — | `unowned` | JVM에 대응물 없음 |
| — | 배타적 접근 (`inout`) | JVM에 대응물 없음 |
| — | Copy-on-Write | 아래 참조 |

### 알아 두면 좋은 것 — Copy-on-Write

값 타입이 항상 복사된다면 큰 배열을 넘길 때마다 비싸지 않은가? Swift 표준 라이브러리의 `Array`, `String`, `Dictionary`, `Set`은 **copy-on-write**로 이 문제를 피한다. 대입 시점에는 내부 버퍼를 공유하고, 어느 한쪽이 **수정할 때** 비로소 복사한다.

```swift
var a = [1, 2, 3]
var b = a          // 아직 복사 안 됨 — 버퍼 공유
b.append(4)        // 이 순간 복사
```

의미론적으로는 값 타입이고 성능은 참조 타입에 가깝다. 이게 Swift가 "값 타입 우선"을 밀 수 있는 이유다.

### 정리

```text
Swift 메모리를 이해하는 순서

1. 이 타입은 값 타입인가 참조 타입인가?   ← 가장 중요
2. 참조 타입이라면 누가 소유하고, 순환은 없는가?  ← weak / unowned
3. 값 타입이라면 복사 비용은? (CoW가 처리하는가?)
4. static 멤버와 타입 메타데이터는 타입당 하나

"어느 영역에 있는가"를 먼저 묻는 JVM식 접근은
Swift에서는 답이 명세되어 있지 않다.
```

## 학습 체크리스트

- [ ] `MemoryLayout<CGSize>.size`, `.stride`, `.alignment`를 출력해 값을 확인한다.
- [ ] Apple 문서의 `Point` 구조체를 만들어 `size == 17`, `stride == 24`가 나오는지 확인한다.
- [ ] 같은 프로퍼티를 가진 `struct`와 `class`의 `MemoryLayout.size`를 비교한다 (참조는 8).
- [ ] `struct`를 복사해 한쪽을 바꾸고 원본이 그대로인지 확인한다.
- [ ] `class` 인스턴스를 두 변수에 담고 한쪽을 바꿔 양쪽에 반영되는지 확인한다.
- [ ] `deinit`에 `print`를 넣어 참조가 사라지는 즉시 호출되는 것을 확인한다.
- [ ] 서로를 강하게 참조하는 두 클래스를 만들어 `deinit`이 불리지 않는 것을 재현한다.
- [ ] 한쪽을 `weak`으로 바꿔 `deinit`이 다시 불리는 것을 확인한다.
- [ ] `weak var`가 왜 항상 `Optional`이어야 하는지 설명한다.
- [ ] 클로저가 `self`를 캡처해 순환이 생기는 예를 만들고 `[weak self]`로 끊는다.
- [ ] 같은 변수를 두 `inout` 자리에 넘겨 배타적 접근 에러를 직접 본다.
- [ ] 큰 배열을 대입한 뒤 수정 전후로 CoW가 일어나는 시점을 설명한다.
- [ ] `SizePreferenceKey.defaultValue`가 인스턴스 없이 접근되는 이유를 `static` 관점에서 설명한다.

## 공식 참고 자료

- [Swift 공식 문서: Automatic Reference Counting](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/)
- [Swift 공식 문서: ARC — Resolving Strong Reference Cycles Between Class Instances](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Resolving-Strong-Reference-Cycles-Between-Class-Instances)
- [Swift 공식 문서: ARC — Strong Reference Cycles for Closures](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting/#Strong-Reference-Cycles-for-Closures)
- [Swift 공식 문서: Memory Safety](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/memorysafety/)
- [Swift 공식 문서: Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/)
- [Swift 공식 문서: Structures and Classes — Choosing Between Structures and Classes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/#Choosing-Between-Structures-and-Classes)
- [Swift 공식 문서: Properties — Type Properties](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/properties/#Type-Properties)
- [Apple: MemoryLayout](https://developer.apple.com/documentation/swift/memorylayout)
- [Apple: MemoryLayout.stride](https://developer.apple.com/documentation/swift/memorylayout/stride)
- [Apple: Choosing Between Structures and Classes](https://developer.apple.com/documentation/swift/choosing-between-structures-and-classes)
