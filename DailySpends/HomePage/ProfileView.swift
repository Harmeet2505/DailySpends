import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @State private var userEmail: String = ""
    @State private var dailyLimit: String = ""
    @State private var monthlyLimit: String = ""
    @State private var yearlyLimit: String = ""

    @State private var showLogoutAlert: Bool = false
    @State private var isLoggedOut = false
    @ObservedObject var limitsViewModel: UserLimitsViewModel

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    profileSection
                    limitInputSection
                    actionButtons
                    Spacer()

                    NavigationLink(destination: WelcomeView(limitsViewModel: limitsViewModel), isActive: $isLoggedOut) {
                        EmptyView()
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .onAppear {
                fetchUserEmail()
                fetchLimits() // ✅ Fetch previous limits when screen loads
            }
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("Logout"),
                    message: Text("Are you sure you want to logout?"),
                    primaryButton: .destructive(Text("Logout")) { logoutUser() },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email").font(.headline).foregroundColor(.gray)
            Text(userEmail).font(.title3).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 3)
    }

    private var limitInputSection: some View {
        VStack(spacing: 15) {
            limitField(title: "Daily Limit", value: $dailyLimit)
            limitField(title: "Monthly Limit", value: $monthlyLimit)
            limitField(title: "Yearly Limit", value: $yearlyLimit)
        }
    }

    private var actionButtons: some View {
        VStack {
            Button(action: saveLimitsToFirestore) {
                Text("Save Limits")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()

            Button(action: { showLogoutAlert = true }) {
                Text("Logout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding()
        }
    }

    private func limitField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundColor(.gray)
            TextField("Enter \(title.lowercased())", text: value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 3)
    }

    // MARK: - Firebase Functions

    private func fetchUserEmail() {
        userEmail = Auth.auth().currentUser?.email ?? "Not logged in"
    }

    private func fetchLimits() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        db.collection("userLimits").document(userId).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching limits: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                let data = document.data()
                DispatchQueue.main.async {
                    dailyLimit = data?["dailyLimit"].map { String(format: "%.2f", $0 as? Double ?? 0.0) } ?? ""
                    monthlyLimit = data?["monthlyLimit"].map { String(format: "%.2f", $0 as? Double ?? 0.0) } ?? ""
                    yearlyLimit = data?["yearlyLimit"].map { String(format: "%.2f", $0 as? Double ?? 0.0) } ?? ""
                }
            }
        }
    }

    private func saveLimitsToFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let limitsData: [String: Any] = [
            "dailyLimit": Double(dailyLimit) ?? 0.0,
            "monthlyLimit": Double(monthlyLimit) ?? 0.0,
            "yearlyLimit": Double(yearlyLimit) ?? 0.0
        ]

        db.collection("userLimits").document(userId).setData(limitsData) { error in
            if let error = error {
                print("❌ Error saving limits: \(error.localizedDescription)")
            } else {
                print("✅ Limits saved successfully!")
            }
        }
    }

    private func logoutUser() {
        do {
            try Auth.auth().signOut()
            print("✅ User logged out successfully")
            isLoggedOut = true  // Trigger navigation to WelcomeView
        } catch let signOutError {
            print("❌ Error signing out: \(signOutError.localizedDescription)")
        }
    }
}

