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
            Button(action: {
                guard !textName.isEmpty && !textDesc.isEmpty else { return }
                let grocery = Grocery(name: textName, desc: textDesc)
                modelContext.insert(grocery)
                do {
                    try modelContext.save()
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
