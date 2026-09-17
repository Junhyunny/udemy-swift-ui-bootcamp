//
//  ExchangeRateService.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import Combine
import Foundation

// FIXME: [Architecture] 싱글턴 + 전송 계층 노출 + 프로토콜 부재.
// 1) static let shared / private init 조합은 주입 지점을 원천 차단한다.
//    싱글턴 자체보다, 이 타입 말고는 대안이 없다는 점이 문제다.
//    -> 프로토콜을 두고 shared 는 '기본 구현을 얻는 편의 경로'로만 남긴다.
// 2) urlSession(_:with:) 이 internal 로 열려 있어 HTTP 전송 방식이 서비스 API 의 일부가 되었다.
//    -> private 으로 닫거나, 재사용이 필요하면 별도 NetworkClient 타입으로 분리한다.
//       그래야 Service 는 '환율을 가져온다'는 도메인 언어만 노출한다.
// 3) 디코딩 실패/HTTP 상태코드 검증이 없다. 도메인 에러(ExchangeRateError)로 감싸 올려야
//    ViewModel 이 사용자에게 보여줄 메시지를 결정할 수 있다.
final class ExchangeRateService {
    static let shared = ExchangeRateService()
    private init() {}

    // TODO: [todos/combine.md](../../todos/combine.md)
    func getExchangeRate() -> AnyPublisher<ExchangeRate, Error> {
        return urlSession(ExchangeRate.self, with: Endpoint.withSymbols.url!)
    }

    func urlSession<T: Codable>(
        _ type: T.Type,
        with url: URL
    ) -> AnyPublisher<T, Error> {
        URLSession
            .shared
            // TODO: [todos/combine-vs-async-await.md](../../todos/combine-vs-async-await.md)
            .dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: type.self, decoder: JSONDecoder())
            // TODO: [todos/combine-operators.md](../../todos/combine-operators.md)
            // FIXME: [Best Practice] RunLoop.main 은 스크롤 중(tracking mode)에 이벤트 전달이 지연된다.
            // - 개선: .receive(on: DispatchQueue.main) 을 쓴다. 바로 아래 .print() 는 디버깅 흔적이므로
            //         제품 코드에서는 제거하거나 #if DEBUG 로 감싼다.
            .receive(on: RunLoop.main)
            .print()
            .eraseToAnyPublisher()
    }
}
