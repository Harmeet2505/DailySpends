//
//  ExpenseInputFields.swift
//  DailySpends
//
//  Created by Harmeet Singh on 01/02/25.
//
import SwiftUI

struct ExpenseInputFields: View {
    let day: Int
    @Binding var expenses: [Int: [String: CGFloat]]
    
    private let categories = ["Grocery", "Travel", "Miscellaneous", "Savings"]

    var body: some View {
        VStack(spacing: 20) {
            ForEach(categories, id: \.self) { category in
                HStack {
                    Text(category)
                        .font(.headline)
                        .frame(width: 100, alignment: .leading)
                    
                    TextField("Amount", value: Binding(
                        get: { expenses[day]?[category] ?? 0 },
                        set: { newValue in
                            if expenses[day] == nil {
                                expenses[day] = [:]
                            }
                            expenses[day]?[category] = newValue
                        }
                    ), formatter: NumberFormatter())
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
        }
    }
}
