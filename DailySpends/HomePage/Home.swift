import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct Home: View {
    @State private var spendingData: [String: [String: CGFloat]] = [:]
    @State private var selectedTimeFrame: String = "Daily"
    @State private var showAddExpenseView: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @ObservedObject var limitsViewModel: UserLimitsViewModel
    @State private var limits: [String: CGFloat] = [:]


    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Time Frame Buttons
                        HStack {
                            ForEach(["Daily", "Monthly", "Yearly"], id: \.self) { timeFrame in
                                Button(action: {
                                    selectedTimeFrame = timeFrame
                                    fetchData(for: timeFrame)
                                }) {
                                    Text(timeFrame)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(selectedTimeFrame == timeFrame ? Color.blue : Color.gray)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding()
                        
                        // Circular Progress View for Spending
                        CircularProgressView(
                            used: averageSpent,
                            limit: selectedTimeFrame == "Daily" ? limits["dailyLimit"] ?? 0 :
                                   selectedTimeFrame == "Monthly" ? limits["monthlyLimit"] ?? 0 :
                                   limits["yearlyLimit"] ?? 0,
                            timeFrame: selectedTimeFrame
                        )



                        // Category Boxes
                        ForEach(["Grocery", "Travel", "Miscellaneous", "Savings"], id: \.self) { category in
                            let budget = selectedTimeFrame == "Daily" ? limits["dailyLimit"] ?? 0 :
                                             selectedTimeFrame == "Monthly" ? limits["monthlyLimit"] ?? 0 :
                                             limits["yearlyLimit"] ?? 0
                                
                            let spentAmount = adjustedSpent(for: category)

                            CategoryBox(
                                category: category,
                                spent: adjustedSpent(for: category),
                                budget: selectedTimeFrame == "Daily" ? limits["dailyLimit"] ?? 0 :
                                        selectedTimeFrame == "Monthly" ? limits["monthlyLimit"] ?? 0 :
                                        limits["yearlyLimit"] ?? 0,
                                color: colorForCategory(category)
                            )
                            .onAppear {
                                if spentAmount > budget {
                                    alertMessage = "⚠️ You have exceeded your \(selectedTimeFrame.lowercased()) budget for \(category)!"
                                    showAlert = true
                                }
                                print("🏁 Home View Appeared")
                                limitsViewModel.fetchLimits() // Fetch limits when Home appears
                                fetchData(for: selectedTimeFrame) // Fetch expenses separately
                            }

                        }
                        NavigationLink(destination: BillImagesView()) {
                            Text("View All Bills")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                        .padding()
                    }
                    .padding()
                }
                
                // Plus Button at Bottom-Right Corner
                Button(action: {
                    showAddExpenseView = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(20)
            }
            .navigationTitle("DailySpends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView(limitsViewModel: limitsViewModel)) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddExpenseView) {
                AddExpenseView()
            }
            .onAppear {
                fetchData(for: selectedTimeFrame)
            }
            .onChange(of: showAddExpenseView) { newValue in
                if !newValue {
                    fetchData(for: selectedTimeFrame)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Budget Exceeded!"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func fetchData(for timeFrame: String) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("❌ No user is logged in.")
            return
        }

        let monthYear = getCurrentMonthYear()
        let userExpensesRef = db.collection("expenses").document(userID).collection(monthYear)

        userExpensesRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching spending data: \(error.localizedDescription)")
                return
            }

            var spending: [String: CGFloat] = [:]

            for document in snapshot?.documents ?? [] {
                let data = document.data()
                for (category, amount) in data {
                    if category != "notes", let value = amount as? Double {
                        spending[category, default: 0] += CGFloat(value)
                    }
                }
            }

            DispatchQueue.main.async {
                self.spendingData[timeFrame] = spending
                self.checkBudgetLimits(for: timeFrame)
            }
        }

        // Fetch budget limits separately
        let userBudgetRef = db.collection("userLimits").document(userID)

        userBudgetRef.getDocument { document, error in
            if let error = error {
                print("❌ Error fetching budget data: \(error.localizedDescription)")
                return
            }

            if let data = document?.data() {
                print("📊 Raw Firestore Data: \(data)")  // Debugging: Print raw data

                var fetchedLimits: [String: CGFloat] = [:]
                for (category, limit) in data {
                    if let value = limit as? Double {
                        print("✅ Category: \(category), Limit: \(value)") // Debugging: Print each value
                        fetchedLimits[category] = CGFloat(value)
                    } else {
                        print("⚠️ Warning: Could not cast \(category) value to Double")
                    }
                }

                DispatchQueue.main.async {
                    self.limits = fetchedLimits  // ✅ Store fetched limits in @State variable
                }

                print("📈 Processed Limits: \(fetchedLimits)")  // Debugging: Print final limits dictionary
            }
        }

    }
//    
    private func checkBudgetLimits(for timeFrame: String) {
        let spent = spendingData[timeFrame]?.values.reduce(0, +) ?? 0
        let limit = totalBudget

        if spent > limit && limit > 0 {
            alertMessage = "You have exceeded your \(timeFrame.lowercased()) budget limit!"
            showAlert = true
        }
    }
    
    private func getCurrentMonthYear() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: Date())
    }
    
    private var averageSpent: CGFloat {
        let total = spendingData[selectedTimeFrame]?.values.reduce(0, +) ?? 0
        switch selectedTimeFrame {
        case "Daily":
            return total / CGFloat(daysInCurrentMonth())
        case "Monthly":
            return total / 12
        case "Yearly":
            return total
        default:
            return total
        }
    }
    
    private func daysInCurrentMonth() -> Int {
        let calendar = Calendar.current
        let date = Date()
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }
    
    private var totalBudget: CGFloat {
        switch selectedTimeFrame {
        case "Daily": return limitsViewModel.dailyLimit
        case "Monthly": return limitsViewModel.monthlyLimit
        case "Yearly": return limitsViewModel.yearlyLimit
        default: return 0
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Grocery": return .green
        case "Travel": return .blue
        case "Miscellaneous": return .orange
        case "Savings": return .purple
        default: return .gray
        }
    }
    
    private func adjustedSpent(for category: String) -> CGFloat {
        let total = spendingData[selectedTimeFrame]?[category] ?? 0
        switch selectedTimeFrame {
        case "Daily":
            return total / CGFloat(daysInCurrentMonth())
        case "Monthly":
            return total / 12
        case "Yearly":
            return total
        default:
            return total
        }
    }
}

// 🔵 Circular Progress View for Spending
struct CircularProgressView: View {
    var used: CGFloat
    var limit: CGFloat
    var timeFrame: String

    private var progress: CGFloat {
        return limit > 0 ? used / limit : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: progress)

            VStack {
                Text("\(timeFrame) Avg Spent")
                    .font(.headline)
                Text("₹\(Int(used)) of \(Int(limit))") // ✅ Display correct values
                    .font(.title)
                    .bold()
            }
        }
        .frame(width: 150, height: 150)
        .padding()
        .onAppear {
            print("📊 Circular Bar Debug: Used = \(used), Limit = \(limit)") // Debugging
        }
    }
}



struct CategoryBox: View {
    var category: String
    var spent: CGFloat
    var budget: CGFloat
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category)
                .font(.headline)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 10)
                        .opacity(0.3)
                        .foregroundColor(color)
                    
                    Rectangle()
                        .frame(width: min(CGFloat(spent / budget) * geometry.size.width, geometry.size.width), height: 10)
                        .foregroundColor(color)
                }
                .cornerRadius(5)
            }
            .frame(height: 10)
            
            // Spent and Budget Text
            HStack {
                Text("Spent: ₹\(Int(spent))")
                Spacer()
            }
            .font(.subheadline)
            
            
            
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

