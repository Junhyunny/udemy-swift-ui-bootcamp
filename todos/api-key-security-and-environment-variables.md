# API 키를 앱에 넣는 방법과 그 한계 — xcconfig, Info.plist, CI/CD

## 질문이 나온 코드

`chapter-61/chapter-61/ContentView.swift`

```swift
enum AppConfig {
    static let apiKey: String = {
        guard let value =
            Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String
        else {
            fatalError("API_KEY is missing")
        }
        return value
    }()
}
```

`chapter-61/Configuration/Secrets.xcconfig`

```
API_KEY = <실제 키>
```

`Secrets.xcconfig` → 빌드 설정 → `Info.plist` → `Bundle.main`으로 값이 흐르는 구조다.

## 1부 — 이 방법은 안전한가

### 짐작이 정확하다 — 키는 추출된다

**결론부터 말하면 이 구조에서 API 키는 반드시 추출된다.** 우려가 맞다.

이유는 단순하다. `Info.plist`는 **앱 번들 안의 평문 파일**이다. `.ipa` 파일은 사실상 zip이라 압축을 풀면 `Info.plist`가 그대로 나온다.

```text
MyApp.ipa (zip)
└── Payload/
    └── MyApp.app/
        ├── Info.plist        ← API_KEY가 여기 평문으로 들어 있다
        ├── MyApp             (실행 바이너리)
        └── ...
```

App Store에서 내려받은 앱은 FairPlay로 암호화되지만, **실행하려면 기기에서 복호화되어야 하므로** 메모리 덤프나 탈옥 기기에서 복호화된 바이너리를 얻을 수 있다. `Info.plist` 자체는 애초에 암호화 대상도 아니다.

`strings` 명령 한 줄로 바이너리의 문자열을 훑는 것도 흔한 방법이다.

**정리하면 이렇다.**

| 저장 위치 | 추출 난이도 |
| --- | --- |
| 소스 코드에 하드코딩 | 매우 쉬움 (`strings`) |
| `Info.plist` (현재 방식) | **매우 쉬움** (zip 해제) |
| 바이너리에 상수로 컴파일 | 쉬움 (`strings`, 디스어셈블) |
| 난독화 후 바이너리 | 보통 (시간이 더 걸릴 뿐) |
| Keychain | 앱 실행 후에만 존재 — 아래 참조 |

### `enum`으로 접근하는 방식 자체는 좋다

키를 어디에 두느냐와 별개로, **코드 구조는 잘 만들어져 있다.**

```swift
enum AppConfig {
    static let apiKey: String = { ... }()
}
```

**`enum`을 네임스페이스로 쓰는 것은 Swift의 관용적 패턴이다.**

- `case`가 없으므로 **인스턴스를 만들 수 없다.** `struct`라면 `AppConfig()`가 가능하지만 `enum`은 불가능하다
- `static let`이므로 [첫 접근 때 한 번만 초기화](./static-stored-vs-computed-property.md)되고 스레드 안전하다
- 즉시 실행 클로저(`{ ... }()`)로 `guard`를 쓸 수 있어 검증 로직을 담을 수 있다
- 접근 지점이 `AppConfig.apiKey` 한 곳으로 모여 나중에 저장 방식을 바꿀 때 이 파일만 고치면 된다

`fatalError`도 논쟁의 여지가 있지만 **설정 누락은 개발자 실수이므로 즉시 크래시가 낫다**는 판단은 합리적이다. 사용자에게 노출되는 런타임 오류가 아니라 빌드·개발 단계에서 잡히기 때문이다. 다만 릴리스 빌드에서 크래시하면 곤란하니, 릴리스에서는 빈 문자열이나 명시적 오류 처리로 바꾸는 편이 안전하다.

### 그래서 `.gitignore`는 의미가 있나

**있다. 다만 목적이 다르다.**

```
# Secrets configuration
Secrets.xcconfig
```

이것이 막는 것은 **"저장소에 키가 남는 것"** 이다. 이건 실질적으로 중요하다.

- 공개 저장소라면 키가 즉시 노출된다. GitHub은 커밋된 키를 자동 탐지해 알려 주기도 한다
- 비공개 저장소여도 히스토리에 영구히 남는다. 한 번 커밋하면 `git rm`으로 지워도 과거 커밋에 남아 있어, 완전히 제거하려면 히스토리 재작성이 필요하다
- 협업 시 각자 다른 키를 쓸 수 있다

**즉 `.gitignore`는 "소스 관리에서 키를 분리"하는 데는 성공하지만, "배포된 앱에서 키를 숨기는" 데는 아무 역할을 하지 않는다.** 두 문제를 구분해야 한다.

> **⚠️ 이 저장소의 현재 상태를 확인할 것**
>
> `.gitignore`에 `Secrets.xcconfig`를 추가했더라도, **이미 `git add`된 파일에는 적용되지 않는다.** Git은 한 번 추적을 시작한 파일을 `.gitignore`로 무시하지 않는다.
>
> ```bash
> git ls-files | grep Secrets        # 추적 중인지 확인
> git rm --cached path/to/Secrets.xcconfig   # 인덱스에서 제거
> ```
>
> 커밋 전이라면 위 명령으로 해결된다. 이미 커밋했다면 키를 **폐기하고 재발급**하는 것이 유일한 안전한 대응이다.

### 근본적인 해결 — 클라이언트에 키를 두지 않는다

**앱에 넣은 비밀은 비밀이 아니다.** 이것이 원칙이다. 난독화, Keychain, 암호화는 모두 **추출을 어렵게 할 뿐 막지 못한다.** 앱이 그 키로 요청을 보낼 수 있다면, 앱을 분석하는 사람도 보낼 수 있다.

**① 백엔드 프록시 — 정석**

```text
현재:  앱 ──[API 키 포함]──→ NewsAPI
개선:  앱 ──[내 앱 인증]──→ 내 서버 ──[API 키]──→ NewsAPI
                              (키는 서버에만 존재)
```

키가 서버에만 있으므로 앱을 분석해도 얻을 수 없다. 부가 이점도 있다.

- 사용량 제한과 로깅을 서버에서 통제
- 키를 교체할 때 앱 업데이트가 필요 없다
- 응답을 캐싱해 외부 API 호출을 줄일 수 있다
- 응답 형태를 앱에 맞게 가공할 수 있다

**② 서버에서 발급하는 단기 토큰**

프록시가 부담이라면, 서버가 짧은 유효기간의 토큰을 발급하고 앱이 그것으로 직접 호출하는 방식도 있다. 토큰이 유출되어도 피해가 시간으로 제한된다.

**③ 사용자 인증과 묶기**

키가 아니라 **로그인한 사용자의 토큰**으로 호출한다. 유출 시 해당 사용자만 영향을 받고, 서버에서 즉시 무효화할 수 있다.

**④ 키에 제약을 건다**

외부 서비스가 지원한다면 도메인·번들 ID·IP 제한, 호출량 상한, 읽기 전용 권한 등을 설정한다. 유출 자체를 막지는 못하지만 **피해를 줄인다.**

**⑤ App Attest — Apple이 제공하는 검증 수단**

`DeviceCheck` 프레임워크의 App Attest는 "이 요청이 진짜 내 앱에서 왔는지" 서버가 검증할 수 있게 해 준다. 키 은닉이 아니라 **요청 출처 검증**이므로, 프록시 방식과 함께 쓰면 효과가 있다.

### Keychain은 답이 아니다 — 흔한 오해

> The keychain services API helps you solve this problem by giving your app a mechanism to store small bits of **user data** in an encrypted database called a keychain.

핵심 단어가 **`user data`** 다. Keychain은 **사용자의 비밀**(비밀번호, 토큰, 인증서)을 안전하게 보관하는 곳이다.

문제는 **개발자의 API 키는 앱에 처음부터 들어 있어야 한다**는 점이다. Keychain에 넣으려면 그 값이 이미 앱 안에 있어야 하고, 그러면 원점이다. 서버에서 받아온 토큰을 **저장**하는 용도로는 Keychain이 정답이지만, 처음부터 박아 넣는 키에는 도움이 되지 않는다.

```text
Keychain이 적합:   서버에서 받은 사용자 토큰을 안전하게 보관
Keychain이 무의미: 앱에 처음부터 들어 있는 API 키를 "숨기기"
```

### 실무 판단 — 위험도에 따라

모든 키가 같은 수준의 위험은 아니다.

| 상황 | 판단 |
| --- | --- |
| 학습용 예제, 무료 API | **현재 방식으로 충분.** `.gitignore`만 확실히 |
| 무료 티어, 유출 시 쿼터만 소진 | 키 제약 + 모니터링. 프록시는 과할 수 있다 |
| 유료 API, 과금이 붙는 키 | **프록시 필수** |
| 결제·개인정보 접근 권한 | **절대 클라이언트에 두지 않는다** |

이 예제는 NewsAPI 무료 키이므로 학습 목적에는 문제가 없다. **다만 저장소에 커밋되지 않도록 하는 것은 여전히 중요하다.**

## 2부 — 환경 변수 관리와 빌드

### xcconfig 방식의 흐름

현재 구조를 단계별로 보면 이렇다.

```text
① Secrets.xcconfig
     API_KEY = abc123
        ↓ (Xcode 프로젝트 설정에서 Configuration File로 지정)
② 빌드 설정(Build Settings)에 API_KEY 변수로 등록
        ↓ (Info.plist에서 $(API_KEY)로 참조)
③ Info.plist
     <key>API_KEY</key>
     <string>$(API_KEY)</string>
        ↓ (빌드 시 치환되어 번들에 포함)
④ Bundle.main.object(forInfoDictionaryKey: "API_KEY")
```

이 방식의 **장점**은 코드에 키가 없고, 설정 파일만 `.gitignore`하면 되고, 빌드 구성(Debug/Release)별로 다른 값을 줄 수 있다는 것이다.

### 개발 환경 구성 — 팀에서 쓰는 방법

**① 예시 파일을 커밋한다**

```
Secrets.xcconfig          ← .gitignore (실제 키)
Secrets.xcconfig.example  ← 커밋 (형식만)
```

```
// Secrets.xcconfig.example
API_KEY = YOUR_API_KEY_HERE
```

새로 합류한 사람이 `.example`을 복사해 자기 키를 넣는다. **`.gitignore`한 파일이 있으면 반드시 `.example`을 함께 두는 것이 관례다.** 그렇지 않으면 새 팀원이 무엇을 만들어야 할지 모른다.

**② README에 설정 절차를 적는다**

```markdown
## 개발 환경 설정
1. `cp Secrets.xcconfig.example Secrets.xcconfig`
2. NewsAPI에서 키를 발급받아 `API_KEY`에 입력
3. Xcode에서 프로젝트를 열고 빌드
```

**③ 빌드 구성별로 나눈다**

```
Debug.xcconfig   → 개발 서버, 개발 키
Release.xcconfig → 운영 서버, 운영 키
```

### 터미널에서 빌드할 때

`xcodebuild`로 빌드하면서 값을 주입하는 방법이 몇 가지 있다.

**① 빌드 설정을 인자로 넘긴다**

```bash
xcodebuild -project chapter-61.xcodeproj \
           -scheme chapter-61 \
           -configuration Release \
           API_KEY="$API_KEY" \
           build
```

명령행에서 준 값이 xcconfig보다 우선한다. **가장 간단하고 CI에서 흔히 쓰는 방법이다.**

**② xcconfig 파일을 빌드 전에 생성한다**

```bash
cat > Configuration/Secrets.xcconfig <<EOF
API_KEY = ${API_KEY}
EOF

xcodebuild -scheme chapter-61 build
```

프로젝트 설정을 건드리지 않아도 되고, 로컬 빌드와 동일한 경로를 쓴다는 장점이 있다.

**③ xcconfig 파일 자체를 지정한다**

```bash
xcodebuild -xcconfig Configuration/CI.xcconfig -scheme chapter-61 build
```

**주의할 점**이 있다. 명령행 인자는 프로세스 목록(`ps`)에 노출될 수 있으므로, 공유 머신에서는 ②처럼 파일로 쓰거나 환경 변수를 쓰는 편이 안전하다.

### CI/CD 파이프라인

**기본 원리는 어디서나 같다.** CI 서비스의 **암호화된 시크릿 저장소**에 키를 넣고, 빌드 시점에 환경 변수로 꺼내 쓴다.

**GitHub Actions 예시**

```yaml
name: Build
on: [push]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create Secrets.xcconfig
        env:
          API_KEY: ${{ secrets.NEWS_API_KEY }}   # 저장소 Settings에서 등록
        run: |
          cat > chapter-61/Configuration/Secrets.xcconfig <<EOF
          API_KEY = ${API_KEY}
          EOF

      - name: Build
        run: |
          xcodebuild -project chapter-61/chapter-61.xcodeproj \
                     -scheme chapter-61 \
                     -destination 'platform=iOS Simulator,name=iPhone 16' \
                     build
```

**핵심 원칙 몇 가지**

- **시크릿을 로그에 출력하지 않는다.** `echo $API_KEY` 금지. CI 서비스가 자동 마스킹해 주더라도 의존하지 않는다
- **`set -x`를 쓰지 않는다.** 명령을 그대로 출력하므로 값이 노출된다
- **PR 빌드에는 시크릿을 주지 않는다.** 포크에서 온 PR이 시크릿을 탈취하는 공격 경로가 있다
- **키를 정기적으로 교체한다.** 유출 여부와 무관하게 회전(rotation) 정책을 둔다

**서명(signing)도 같은 문제다.** 배포용 빌드에는 인증서와 프로비저닝 프로파일이 필요한데, 이것도 시크릿이다. 일반적인 처리 방식은 이렇다.

- 인증서를 base64로 인코딩해 시크릿에 저장하고, 빌드 시 임시 keychain을 만들어 import
- Xcode Cloud를 쓰면 Apple 계정과 연동되어 서명을 자동 관리해 준다
- App Store Connect API 키로 업로드를 자동화

**Xcode Cloud**는 Apple의 공식 CI다. 환경 변수를 워크플로 설정에서 등록하고 **secret으로 표시**하면 로그에 노출되지 않는다. 서명 관리가 자동이라 설정 부담이 적다.

### 정리

```text
1부 — 안전성
  xcconfig → Info.plist 방식은
    저장소에서 키를 분리하는 데는 유효하다  ✅
    배포된 앱에서 키를 숨기는 데는 무효하다  ❌
  enum + static let 구조 자체는 좋은 패턴이다
  근본 해결은 백엔드 프록시. Keychain은 이 문제의 답이 아니다
  위험도에 따라 판단: 학습용이면 현재 방식으로 충분

2부 — 관리
  로컬:    Secrets.xcconfig (.gitignore) + .example 커밋
  터미널:  xcodebuild에 빌드 설정 인자로 주입 또는 파일 생성
  CI/CD:   암호화된 시크릿 → 환경 변수 → xcconfig 생성 → 빌드
  주의:    로그 출력 금지, PR 빌드에 시크릿 주지 않기, 정기 교체
```

## 학습 체크리스트

- [ ] `git ls-files | grep Secrets`로 시크릿 파일이 추적 중인지 확인한다.
- [ ] 추적 중이라면 `git rm --cached`로 인덱스에서 제거한다.
- [ ] `.gitignore`가 이미 추적 중인 파일에는 적용되지 않는 것을 직접 확인한다.
- [ ] `Secrets.xcconfig.example`을 만들어 커밋한다.
- [ ] 빌드된 `.app` 번들의 `Info.plist`를 열어 `API_KEY`가 평문인지 확인한다.
- [ ] `strings` 명령으로 빌드된 바이너리에서 문자열을 훑어본다.
- [ ] `AppConfig`를 `struct`로 바꿔 보고 인스턴스 생성이 가능해지는 차이를 확인한다.
- [ ] `fatalError`를 릴리스 빌드에서 다른 처리로 바꾸는 코드를 작성한다.
- [ ] `xcodebuild`에 `API_KEY=...`를 인자로 주어 빌드해 본다.
- [ ] 셸 스크립트로 `Secrets.xcconfig`를 생성하는 절차를 만들어 본다.
- [ ] Debug/Release용 xcconfig를 나누고 다른 값이 주입되는지 확인한다.
- [ ] NewsAPI 키에 걸 수 있는 제약(호출량, 도메인)이 있는지 문서를 확인한다.
- [ ] 백엔드 프록시 구조를 다이어그램으로 그려 키의 위치를 표시한다.
- [ ] Keychain이 왜 이 문제의 답이 아닌지 한 문단으로 설명한다.

## 공식 참고 자료

**빌드 설정과 시크릿**

- [Apple: Adding a build configuration file to your project](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project)
- [Apple: Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [Apple: Information Property List](https://developer.apple.com/documentation/bundleresources/information-property-list)
- [Apple: Bundle.object(forInfoDictionaryKey:)](https://developer.apple.com/documentation/foundation/bundle/object(forinfodictionarykey:))

**보안**

- [Apple: Keychain services](https://developer.apple.com/documentation/security/keychain-services)
- [Apple: Storing Keys in the Keychain](https://developer.apple.com/documentation/security/storing-keys-in-the-keychain)
- [Apple: DeviceCheck (App Attest)](https://developer.apple.com/documentation/devicecheck)
- [Apple: Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Apple: CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [Apple: Security](https://developer.apple.com/documentation/security)

**빌드와 CI/CD**

- [Apple: Building your app from the command line (xcodebuild)](https://developer.apple.com/documentation/xcode/building-your-app-from-the-command-line)
- [Apple: Xcode Cloud](https://developer.apple.com/documentation/xcode/xcode-cloud)
- [Apple: Setting environment variables in Xcode Cloud workflows](https://developer.apple.com/documentation/xcode/setting-environment-variables-in-xcode-cloud-workflows)
- [Apple: App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Apple: Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
