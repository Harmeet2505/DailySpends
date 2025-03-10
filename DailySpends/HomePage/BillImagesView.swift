import SwiftUI
import FirebaseStorage
import FirebaseAuth

struct BillImagesView: View {
    @State private var billImages: [String] = []
    private let storage = Storage.storage()
    
    var body: some View {
        VStack {
            if billImages.isEmpty {
                Text("No bills found")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(billImages, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image.resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                                    .cornerRadius(10)
                            } placeholder: {
                                ProgressView()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Bills")
        .onAppear {
            fetchBillImages()
        }
    }
    
    private func fetchBillImages() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("❌ No user logged in.")
            return
        }

        let userBillsRef = storage.reference().child("bills/\(userID)/")  // Fetch only this user's bills

        userBillsRef.listAll { result, error in
            if let error = error {
                print("❌ Error fetching bill images: \(error.localizedDescription)")
                return
            }
            
            // ✅ Properly unwrap result before accessing items
            guard let result = result else {
                print("⚠️ No results found in Firebase Storage.")
                return
            }

            var imageUrls: [String] = []
            let group = DispatchGroup()

            for item in result.items {
                group.enter()
                item.downloadURL { url, error in
                    if let url = url {
                        imageUrls.append(url.absoluteString)
                    } else {
                        print("⚠️ Failed to get download URL for \(item.name)")
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.billImages = imageUrls
                print("📸 Successfully fetched \(imageUrls.count) bill images for user \(userID).")
            }
        }
    }
}

