//
//  CircularPickerViewModel.swift
//  chapter-94
//
//  Created by 강준현 on 9/9/26.
//

import Foundation
import Combine

final class CircularPickerViewModel: ObservableObject {
    @Published var selectedValue: Int = 5
    let totalValue: Int = 12
    
    func selectValue(_ value: Int) {
        selectedValue = value
    }
}
