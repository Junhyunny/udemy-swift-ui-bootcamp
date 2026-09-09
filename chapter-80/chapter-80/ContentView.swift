//
//  ContentView.swift
//  chapter-80
//
//  Created by 강준현 on 9/9/26.
//

import SwiftUI

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
