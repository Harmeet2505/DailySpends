import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct AddExpenseView: View {
    @State private var expenses: [Int: [String: CGFloat]] = [:]
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    @State private var notes: [Int: String] = [:]
    @State private var selectedImageURLs: [Int: String] = [:]
    @State private var selectedImages: [Int: UIImage] = [:]
    @State private var showSuccessAlert = false
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

    @State private var selectedMonth: Date = Date() // Keeps track of the selected month

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private var currentMonthYear: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: selectedMonth)
    }

    private var numberOfDaysInMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        return range.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                // Month Navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                            .font(.title)
                    }
                    
                    Text(currentMonthYear)
                        .font(.title)
                        .bold()
                    
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                            .font(.title)
                    }
                }
                .padding()
                
                // Horizontal Scrollable Days
                TabView(selection: $selectedDay) {
                    ForEach(1...numberOfDaysInMonth, id: \.self) { day in
                        VStack {
                            Text("Day \(day)").font(.title2).bold()
                            
                            // Expense Inputs
                            ExpenseInputFields(day: day, expenses: $expenses)
                                .padding()
                            
                            // Notes
                            TextEditor(text: Binding(
                                get: { notes[day] ?? "" },
                                set: { notes[day] = $0 }
                            ))
                            .frame(height: 100)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            
                            // Display Saved Image
                            if let imageUrl = selectedImageURLs[day], let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                } placeholder: {
                                    ProgressView()
                                }
                                .padding()
                            } else if let image = selectedImages[day] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(10)
                                    .padding()
                            }
                            
                            // Save Button
                            Button("Save Expenses") {
                                saveExpenses(for: day)
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .alert(isPresented: $showSuccessAlert) {
                                Alert(title: Text("Success!"), message: Text("Expenses saved!"), dismissButton: .default(Text("OK")))
                            }
                        }
                        .padding()
                        .tag(day)
                        .onAppear { loadExpenses(for: day) }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            }
            
            // Floating Plus Button
            Button(action: {
                showActionSheet = true
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
            .actionSheet(isPresented: $showActionSheet) {
                ActionSheet(
                    title: Text("Add Bill"),
                    message: Text("Choose an option to add a bill"),
                    buttons: [
                        .default(Text("Take Photo")) {
                            imagePickerSourceType = .camera
                            showImagePicker = true
                        },
                        .default(Text("Choose from Gallery")) {
                            imagePickerSourceType = .photoLibrary
                            showImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imagePickerSourceType, selectedImage: Binding(
                    get: { selectedImages[selectedDay] ?? UIImage() },
                    set: { selectedImages[selectedDay] = $0 }
                ))
            }
        }
    }

    // MARK: - Month Navigation
    private func changeMonth(by months: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: months, to: selectedMonth) {
            selectedMonth = newMonth
            selectedDay = 1 // Reset to first day of the month
            expenses = [:]  // Clear old data
            notes = [:]
            selectedImageURLs = [:]
            selectedImages = [:]
            loadExpenses(for: selectedDay) // Load new month's data
        }
    }

    private func getUserID() -> String? {
        return Auth.auth().currentUser?.uid
    }

    private func loadExpenses(for day: Int) {
        guard let userID = getUserID() else { return }

        let dayDocRef = db.collection("expenses")
            .document(userID)
            .collection(currentMonthYear)
            .document("day_\(day)")

        dayDocRef.getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                DispatchQueue.main.async {
                    var loadedExpenses: [String: CGFloat] = [:]
                    for (key, value) in data {
                        if let amount = value as? Double {
                            loadedExpenses[key] = CGFloat(amount)
                        }
                    }
                    self.expenses[day] = loadedExpenses
                    self.notes[day] = data["notes"] as? String ?? ""
                    self.selectedImageURLs[day] = data["billImageURL"] as? String
                }
            }
        }
    }

    private func saveExpenses(for day: Int) {
        guard let userID = getUserID() else { return }

        let dayDocRef = db.collection("expenses")
            .document(userID)
            .collection(currentMonthYear)
            .document("day_\(day)")

        var dataToSave: [String: Any] = expenses[day]?.mapValues { Double($0) } ?? [:]
        dataToSave["notes"] = notes[day] ?? ""

        if let selectedImage = selectedImages[day] {
            uploadImageToFirebase(image: selectedImage) { imageURL in
                dataToSave["billImageURL"] = imageURL
                saveToFirestore(dayDocRef, dataToSave)
            }
        } else {
            saveToFirestore(dayDocRef, dataToSave)
        }
    }

    private func saveToFirestore(_ docRef: DocumentReference, _ data: [String: Any]) {
        docRef.setData(data) { error in
            if let error = error {
                print("❌ Error saving data: \(error.localizedDescription)")
            } else {
                print("✅ Expenses saved successfully!")
                showSuccessAlert = true
            }
        }
    }

    private func uploadImageToFirebase(image: UIImage, completion: @escaping (String) -> Void) {
        guard let userID = getUserID(), let imageData = image.jpegData(compressionQuality: 0.75) else { return }

        let imageName = UUID().uuidString
        let imageRef = storage.reference().child("bills/\(userID)/\(imageName).jpg")

        imageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("❌ Upload failed: \(error.localizedDescription)")
                return
            }
            imageRef.downloadURL { url, _ in
                if let url = url {
                    completion(url.absoluteString)
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

//import FirebaseAuth
//import FirebaseFirestore
//import FirebaseStorage
//import PhotosUI
//import UIKit
//
//struct AddExpenseView: View {
//    // State to store expenses for each day
//    @State private var expenses: [Int: [String: CGFloat]] = [:]
//    
//    // State to store the selected day (default to current day)
//    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
//    
//    // State to store notes about the day
//    @State private var notes: String = ""
//    
//    // State to control the image picker
//    @State private var showImagePicker: Bool = false
//    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
//    
//    // State to store the selected image
//    @State private var selectedImage: UIImage? = nil
//    
//    // State to control the action sheet
//    @State private var showActionSheet: Bool = false
//    
//    // Dynamic month and year
//    private var currentMonthYear: String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "MMMM yyyy" // Format: "February 2025"
//        return dateFormatter.string(from: Date())
//    }
//    
//    // State for the success alert
//    @State private var showSuccessAlert = false
//
//    var body: some View {
//        ZStack(alignment: .bottomTrailing) {
//            VStack {
//                // Dynamic Month and Year Header
//                Text(currentMonthYear)
//                    .font(.title)
//                    .bold()
//                    .padding(.top, 20)
//                
//                // TabView for Days of the Month
//                TabView(selection: $selectedDay) {
//                    ForEach(1..<32, id: \.self) { day in
//                        VStack {
//                            // Day Header
//                            Text("Day \(day)")
//                                .font(.title2)
//                                .bold()
//                                .padding(.top, 10)
//                            
//                            // Expense Input Fields
//                            ExpenseInputFields(day: day, expenses: $expenses)
//                                .padding()
//                            
//                            // Notes Section
//                            TextEditor(text: $notes)
//                                .frame(height: 100)
//                                .padding()
//                                .background(Color(.systemGray6))
//                                .cornerRadius(10)
//                                .padding(.horizontal)
//                            
//                            // Display Selected Image
//                            if let selectedImage = selectedImage {
//                                Image(uiImage: selectedImage)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(height: 200)
//                                    .cornerRadius(10)
//                                    .padding()
//                            }
//                            
//                            Spacer()
//                        }
//                        .tag(day)
//                        .background(Color(.systemBackground))
//                        .cornerRadius(10)
//                        .shadow(radius: 5)
//                        .padding()
//                        .transition(.opacity)
//                        .animation(.easeInOut(duration: 0.5), value: selectedDay)
//                    }
//                }
//                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
//                
//                // Save Button
//                Button(action: {
//                    saveExpenses()
//                }) {
//                    Text("Save Expenses")
//                        .fontWeight(.bold)
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(Color.blue)
//                        .cornerRadius(10)
//                }
//                .padding(.bottom, 20)
//                .alert(isPresented: $showSuccessAlert) {
//                    Alert(
//                        title: Text("Success!"),
//                        message: Text("Your expenses, notes, and bill have been saved."),
//                        dismissButton: .default(Text("OK"))
//                    )
//                }
//            }
//            .navigationTitle("Add Expense")
//            
//            // Plus Button at Bottom-Right Corner
//            Button(action: {
//                showActionSheet = true
//            }) {
//                Image(systemName: "plus")
//                    .font(.system(size: 24))
//                    .foregroundColor(.white)
//                    .padding(16)
//                    .background(Color.blue)
//                    .clipShape(Circle())
//                    .shadow(radius: 5)
//            }
//            .padding(20)
//            .actionSheet(isPresented: $showActionSheet) {
//                ActionSheet(
//                    title: Text("Add Bill"),
//                    message: Text("Choose an option to add a bill"),
//                    buttons: [
//                        .default(Text("Take Photo")) {
//                            imagePickerSourceType = .camera
//                            showImagePicker = true
//                        },
//                        .default(Text("Choose from Gallery")) {
//                            imagePickerSourceType = .photoLibrary
//                            showImagePicker = true
//                        },
//                        .cancel()
//                    ]
//                )
//            }
//            .sheet(isPresented: $showImagePicker) {
//                ImagePicker(sourceType: imagePickerSourceType, selectedImage: $selectedImage)
//            }
//        }
//    }
//    
//    // Function to get the current user's UID
//    private func getUserID() -> String? {
//        if let user = Auth.auth().currentUser {
//            return user.uid
//        } else {
//            print("❌ No user is logged in.")
//            return nil
//        }
//    }
//    
//    private func saveExpenses() {
//        guard let userID = getUserID() else {
//            print("❌ Error: No user logged in")
//            return
//        }
//
//        let db = Firestore.firestore()
//
//        // Save the monthYear field (this part is already correct)
//        db.collection("expenses").document(userID).setData(["monthYear": currentMonthYear], merge: true)
//
//        // Save daily expenses
//        for (day, expenseDetails) in expenses {
//            print("📌 Saving expenses for Day \(day): \(expenseDetails)") // Debugging
//
//            // Create or get document for the day inside the collection for the month
//            let dayDocument = db.collection("expenses")
//                .document(userID)
//                .collection(currentMonthYear)
//                .document("day_\(day)")
//
//            // Ensure we're storing the correct format (convert to Double)
//            var dataToSave: [String: Any] = expenseDetails.mapValues { Double($0) } // Convert CGFloat to Double
//
//            // Add notes to the data being saved (as a String)
//            dataToSave["notes"] = notes
//
//            // Upload the image to Firebase Storage and save the URL
//            if let selectedImage = selectedImage {
//                uploadImageToFirebase(image: selectedImage) { imageURL in
//                    dataToSave["billImageURL"] = imageURL
//                    saveDataToFirestore(dayDocument: dayDocument, dataToSave: dataToSave)
//                }
//            } else {
//                saveDataToFirestore(dayDocument: dayDocument, dataToSave: dataToSave)
//            }
//        }
//    }
//    
//    private func saveDataToFirestore(dayDocument: DocumentReference, dataToSave: [String: Any]) {
//        dayDocument.setData(dataToSave) { error in
//            if let error = error {
//                print("❌ Error saving data: \(error.localizedDescription)")
//            } else {
//                print("✅ Expenses, notes, and bill saved successfully!")
//                showSuccessAlert = true
//            }
//        }
//    }
//    
//    private func uploadImageToFirebase(image: UIImage, completion: @escaping (String) -> Void) {
//        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
//            print("❌ Failed to convert image to data")
//            return
//        }
//        
//        guard let userID = Auth.auth().currentUser?.uid else {
//            print("❌ No user logged in.")
//            return
//        }
//        
//        let imageName = UUID().uuidString  // Unique image name
//        let imageRef = Storage.storage().reference().child("bills/\(userID)/\(imageName).jpg")
//
//        imageRef.putData(imageData, metadata: nil) { metadata, error in
//            if let error = error {
//                print("❌ Error uploading image: \(error.localizedDescription)")
//                return
//            }
//
//            imageRef.downloadURL { url, error in
//                if let error = error {
//                    print("❌ Error getting download URL: \(error.localizedDescription)")
//                    return
//                }
//
//                if let downloadURL = url {
//                    print("✅ Uploaded bill for user \(userID): \(downloadURL)")
//                    completion(downloadURL.absoluteString)
//                }
//            }
//        }
//    }
//}
//
//struct ImagePicker: UIViewControllerRepresentable {
//    var sourceType: UIImagePickerController.SourceType
//    @Binding var selectedImage: UIImage?
//
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.sourceType = sourceType
//        picker.delegate = context.coordinator
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
//        var parent: ImagePicker
//
//        init(_ parent: ImagePicker) {
//            self.parent = parent
//        }
//
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
//            if let image = info[.originalImage] as? UIImage {
//                parent.selectedImage = image
//            }
//            picker.dismiss(animated: true)
//        }
//
//        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//            picker.dismiss(animated: true)
//        }
//    }
//}
