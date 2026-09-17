//
//  ContentView.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

// FIXME: [Architecture] View 가 ViewModel 의 변환 함수를 행마다 직접 호출한다.
// - 현상: 한 행을 그리려고 vm.emojiFlag(key), vm.countryName(key), vm.formatRateForLocale(key) 를
//         따로 부르고, navigationTitle 에서 한 번 더 부른다. 모두 매 렌더마다 재계산된다.
// - 문제: View 가 '키 -> 표시값' 변환 절차를 알고 있어야 한다. 표시 규칙이 바뀌면 View 도 바뀐다.
//         vm.validateOutput() 도 프로퍼티가 아닌 메서드라 body 에서 호출될 때마다 정렬을 다시 수행한다.
// - 개선: ViewModel 이 struct RateRow { let id, flag, countryName, formattedRate } 배열을
//         계산된 상태로 노출하고, View 는 ForEach(vm.rows) { row in ... } 로 그리기만 한다.
// - 구조: 이 프로젝트는 Models/ Services/ Utils/ ViewModels/ 는 나눴는데 View 만 루트에 있다.
//         Views/ 를 만들어 계층을 일관되게 맞춘다.
struct ContentView: View {
    @State var vm = ViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.validateOutput(), id: \.self) { key in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vm.emojiFlag(key))
                                .font(.system(size: 50))
                            Text(vm.countryName(key) ?? key)
                        }
                        Spacer()
                        Text(vm.formatRateForLocale(for: key))
                            .font(.largeTitle)
                            .bold()
                            .shadow(color: .secondary, radius: 3)
                    }
                }
                .padding(7)
                .background(
                    .gray.opacity(0.25),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .navigationTitle(
                "Exchange Rate: \(vm.formatRateForLocale(for: "EUR"))"
            )
        }
    }
}

#Preview {
    ContentView()
}
