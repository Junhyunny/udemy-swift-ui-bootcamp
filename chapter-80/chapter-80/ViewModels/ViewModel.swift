//
//  ViewModel.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Combine
import Foundation
import Observation

// FIXME: [Architecture] 타입 이름이 역할을 말하지 않고, 의존성이 하드코딩되어 있다.
// 1) 이름: 'ViewModel' 은 폴더명을 반복할 뿐이다. 화면이 두 개가 되는 순간 이름이 충돌한다.
//    -> ExchangeRateViewModel 처럼 어떤 화면의 상태인지 드러내는 이름을 쓴다.
// 2) 의존성: 아래 fetchRates() 가 ExchangeRateService.shared 를 직접 부른다.
//    ViewModel 이 "어떤 구현을 쓸지"까지 결정해버려서 가짜 구현으로 교체할 수 없다.
//    -> protocol ExchangeRateProviding { func getExchangeRate() -> AnyPublisher<ExchangeRate, Error> }
//       를 정의하고 init(service: ExchangeRateProviding = ExchangeRateService.shared) 로 주입받는다.
//       기본값을 두면 호출부는 그대로 두고 테스트/Preview 에서만 StubService 를 넣을 수 있다.
// 3) 계층: emojiFlag/countryName/formatRateForLocale 같은 표시용 변환이 ViewModel 에 있는 것은 맞지만,
//    View 가 행마다 이 함수들을 호출한다(ContentView 참고). 미리 [RateRow] 로 만들어 노출하는 편이 낫다.
@Observable
final class ViewModel {
    var exchangeRate: ExchangeRate? = nil
    // TODO: [todos/112-combine-cancellable-and-store.md](../../../todos/112-combine-cancellable-and-store.md)
    private var cancellableSet: Set<AnyCancellable> = []

    // FIXME: [Best Practice] init 에서 곧바로 네트워크 호출을 시작한다.
    // - 문제: 객체 생성 = 통신 시작이라 Preview 나 테스트에서도 실제 API 를 때린다.
    //         또 Service 를 싱글턴으로 직접 참조해 가짜 구현으로 갈아끼울 수 없다.
    // - 개선: 호출은 View 의 .task { await vm.fetchRates() } 에서 시작하고,
    //         서비스는 프로토콜로 추상화해 init(service:) 로 주입한다.
    init() {
        fetchRates()
    }

    func fetchRates() {
        ExchangeRateService.shared.getExchangeRate()
            // TODO: [todos/113-combine-operators.md](../../../todos/113-combine-operators.md)
            // FIXME: [Best Practice] 모든 에러를 빈 placeholder 로 바꿔 실패를 감춘다.
            // - 문제: 네트워크 실패, 인증 실패, 디코딩 실패가 전부 "빈 화면"으로 보인다.
            //         사용자도 개발자도 무엇이 잘못됐는지 알 수 없다.
            // - 개선: sink(receiveCompletion:receiveValue:) 로 실패를 받아 errorMessage 상태에 담고
            //         화면에 재시도 UI 를 노출한다.
            .replaceError(with: ExchangeRate.placeholder)
            // TODO: [todos/023-weak-self-and-deinit.md](../../../todos/023-weak-self-and-deinit.md)
            .sink { [weak self] in
                print($0)
                self?.exchangeRate = $0
            }
            // TODO: [todos/112-combine-cancellable-and-store.md](../../../todos/112-combine-cancellable-and-store.md)
            .store(in: &cancellableSet)
    }

    // TODO: [todos/023-weak-self-and-deinit.md](../../../todos/023-weak-self-and-deinit.md)
    deinit {
        cancellableSet.forEach { $0.cancel() }
    }
}

extension ViewModel {
    func validateOutput() -> [Dictionary<String, Double>.Keys.Element] {
        guard let output = exchangeRate?.rates?.keys.sorted() else {
            return []
        }
        return output
    }

    func emojiFlag(_ currencyCode: String) -> String {
        guard let country = Country.getCountryBy(currencyCode: currencyCode)
        else {
            return
                // TODO: [todos/138-flag-emoji-from-unicode-scalars.md](../../../todos/138-flag-emoji-from-unicode-scalars.md)
                currencyCode
                .dropLast()
                .unicodeScalars
                .map({ 127397 + $0.value })
                .compactMap(UnicodeScalar.init)
                .map(String.init)
                .joined()
        }
        return country.flagEmoji
    }

    func countryName(_ currencyCode: String) -> String? {
        Country.getCountryBy(currencyCode: currencyCode)?.countryName
    }

    // FIXME: [Best Practice] NumberFormatter 를 호출할 때마다 새로 만들고, 마지막엔 강제 언래핑한다.
    // - 문제1: NumberFormatter 생성은 비싼 작업인데 이 함수는 List 의 모든 행에서, 매 렌더마다 호출된다.
    // - 문제2: string(from:) 은 옵셔널을 돌려주는데 ! 로 풀고 있다.
    //          key 로 만든 Locale 식별자가 유효하지 않으면 그대로 크래시한다.
    // - 문제3: "USD".dropLast() + "_" + ... 로 로케일을 문자열 조합해 추측하고 있다.
    //          통화 코드에서 로케일을 역산하는 것은 일반적으로 성립하지 않는다.
    // - 개선: static let formatter 로 인스턴스를 재사용하거나 iOS 15+ 의
    //         rate.formatted(.currency(code: key)) 를 쓴다. 폴백 문자열도 준비한다.
    func formatRateForLocale(for key: String) -> String {
        guard let mainRates = exchangeRate?.rates else { return "" }
        let rate = mainRates[key] ?? 1.0
        // TODO: [todos/010-computed-property-with-closure-body.md](../../../todos/010-computed-property-with-closure-body.md)
        var formatter: NumberFormatter {
            let fm = NumberFormatter()
            fm.numberStyle = .currency
            fm.locale = Locale(
                identifier: key.dropLast() + "_" + key.dropLast().uppercased()
            )
            return fm
        }
        return formatter.string(from: NSNumber(value: rate))!
    }
}
