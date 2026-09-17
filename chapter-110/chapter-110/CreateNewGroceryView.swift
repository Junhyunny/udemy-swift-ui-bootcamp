//
//  CreateNewGroceryView.swift
//  chapter-110
//
//  Created by 강준현 on 9/10/26.
//

import SwiftData
import SwiftUI

struct CreateNewGroceryView: View {
    @Environment(\.modelContext) var modelContext
    @State private var textName: String = ""
    @State private var textDesc: String = ""

    var body: some View {
        VStack {
            TextField("Name", text: $textName)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
            TextField("Description", text: $textDesc)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
            // FIXME: [Architecture] 생성/검증/저장 규칙이 버튼 클로저 안에 그대로 들어 있다.
            // - 현상: 빈 값 검증, Grocery 인스턴스 생성, insert, save 가 모두 익명 클로저 한 곳에 있다.
            // - 참고: SwiftData 에서 View 가 @Environment(\.modelContext) 를 직접 쓰는 것은 애플이 권장하는
            //         방식이라 '반드시 ViewModel 을 끼워야 한다'는 뜻은 아니다. 문제는 위치다.
            // - 개선: 최소한 private func createGrocery() 로 추출해 body 에서 분리한다.
            //         검증 규칙이 늘어나면(중복 이름 금지, 길이 제한 등) @Observable 입력 모델이나
            //         Grocery 의 정적 팩토리로 옮겨 테스트 가능한 자리에 둔다.
            //         지금은 View 를 띄우지 않고서는 저장 규칙을 검증할 방법이 없다.
            Button(action: {
                guard !textName.isEmpty && !textDesc.isEmpty else { return }
                let grocery = Grocery(name: textName, desc: textDesc)
                modelContext.insert(grocery)
                do {
                    try modelContext.save()
                // FIXME: [Best Practice] 저장 실패를 print 로만 흘려보내 사용자에게 아무것도 알리지 않는다.
                // - 개선: @State private var saveError: Error? 를 두고 .alert 로 노출하거나,
                //         최소한 로깅 프레임워크(os.Logger)를 사용한다. 저장 성공 시 입력 필드 초기화도 빠져 있다.
                } catch {
                    print(error.localizedDescription)
                }
            }) {
                Text("Create")
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    CreateNewGroceryView()
}
