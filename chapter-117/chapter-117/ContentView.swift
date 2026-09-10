//
//  ContentView.swift
//  chapter-117
//
//  Created by 강준현 on 9/10/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var friends: [FriendModel]

    var body: some View {
        NavigationStack {
            List(self.friends) { friend in
                HStack(spacing: 5) {
                    Text(friend.firstName)
                    Text(friend.lastName)
                }
            }
            .navigationTitle("Contacts")
        }
    }
}

// TODO: [todos/preview-modifier-and-shared-context.md](../../todos/preview-modifier-and-shared-context.md)
#Preview(traits: .modifier(FriendModelPreviewModifier())) {
    ContentView()
}
