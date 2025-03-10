import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class UserLimitsViewModel: ObservableObject {
    @Published var dailyLimit: CGFloat = 0
    @Published var monthlyLimit: CGFloat = 0
    @Published var yearlyLimit: CGFloat = 0
    
    private let db = Firestore.firestore()
    
    func fetchLimits() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("❌ No user is logged in.")
            return
        }
        
        let userRef = db.collection("users").document(userID)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("❌ Error fetching user limits: \(error.localizedDescription)")
                return
            }
            
            if let data = document?.data() {
                DispatchQueue.main.async {
                    self.dailyLimit = CGFloat(data["dailyLimit"] as? Double ?? 0)
                    self.monthlyLimit = CGFloat(data["monthlyLimit"] as? Double ?? 0)
                    self.yearlyLimit = CGFloat(data["yearlyLimit"] as? Double ?? 0)
                }
            }
        }
    }
    
    func saveLimits() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let userRef = db.collection("users").document(userID)
        let limitsData: [String: Any] = [
            "dailyLimit": dailyLimit,
            "monthlyLimit": monthlyLimit,
            "yearlyLimit": yearlyLimit
        ]
        
        userRef.setData(limitsData, merge: true) { error in
            if let error = error {
                print("❌ Error saving limits: \(error.localizedDescription)")
            } else {
                print("✅ Limits saved successfully")
            }
        }
    }
}

