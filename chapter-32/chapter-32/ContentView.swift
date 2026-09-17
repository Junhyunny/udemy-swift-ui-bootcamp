//
//  ContentView.swift
//  chapter-32
//
//  Created by 강준현 on 9/7/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TodoListApp()
    }
}

struct Todo: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var completed: Bool
}

struct CheckBox: View {
    @Binding var isChecked: Bool
    
    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack {
                Image(
                    systemName: isChecked
                      ? "checkmark.square.fill"
                      : "square")
                .foregroundColor(isChecked ? .blue : .gray)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TodoListApp: View {
    @State private var todos: [Todo] = [
        // TODO: [todos/argument-labels-and-indexset.md](../../todos/argument-labels-and-indexset.md)
        Todo(title: "Buy groceries", completed: false),
        Todo(title: "Wash Car", completed: false),
    ]
    @State private var newTask: String = ""
    
    var body: some View {
        NavigationStack {
            HStack {
                TextField("New task", text: $newTask)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading)
                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
                .padding(.trailing)
            }
            .padding()
            List {
                // TODO: [todos/hashable-id-and-collisions.md](../../todos/hashable-id-and-collisions.md)
                // TODO: [todos/binding-in-foreach.md](../../todos/binding-in-foreach.md)
                // FIXME: [Best Practice] Identifiable 을 이미 채택했는데 id: \.self 로 덮어쓰고 있다.
                // - 문제: Todo 의 Hashable 합성 해시에 completed 가 포함되므로 체크박스를 토글하는 순간
                //         "같은 행"의 식별자가 바뀐다. SwiftUI 는 삭제 후 재삽입으로 보고 애니메이션이
                //         튀거나 포커스/스크롤 상태가 초기화된다.
                // - 개선: ForEach($todos) { $todo in ... } 처럼 id 인자를 빼고 Identifiable 의 id(UUID)를 쓴다.
                //         식별에 쓰일 값은 변하지 않아야 한다는 것이 핵심이다.
                ForEach($todos, id: \.self) { $todo in
                    HStack {
                        CheckBox(isChecked: $todo.completed)
                        Text(todo.title)
                    }
                }
                .onDelete(perform: deleteTask(at:))
            }
            .navigationTitle(Text("Todo List"))
        }
        // TODO: [todos/view-lifecycle-hooks.md](../../todos/view-lifecycle-hooks.md)
        .onAppear {
            print("rendering first time")
        }
        .onChange(of: todos) { oldValue, newValue in
            print("completed: \n", oldValue, "\n", newValue)
        }

    }
    
    func addTask() {
        if !newTask.isEmpty {
            todos.append(Todo(title: newTask, completed: false))
            newTask = ""
        }
    }
    
    func deleteTask(at offset: IndexSet) {
        todos.remove(atOffsets: offset)
    }
}

#Preview {
    ContentView()
}
