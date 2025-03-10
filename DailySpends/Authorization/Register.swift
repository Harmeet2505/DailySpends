//
//  Register.swift
//  DailySpends
//
//  Created by Harmeet Singh on 07/12/24.
//

import SwiftUI
import FirebaseAuth

struct Register: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSecure: Bool = true
    @State private var showingAlert = false
    @State private var errorMessage: String?
    @State private var isLoggedIn: Bool = false
    @State private var alertMessage: String = ""
    @StateObject private var authorization = AuthService()
    @ObservedObject var limitsViewModel: UserLimitsViewModel


    var body: some View {
        VStack {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 150, height: 150)
                .padding(.bottom, 25)
            
            Text("Register")
                .font(.largeTitle)
                .padding(.bottom, 40)
            
            TextField("Email", text: $email)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(30)
                .padding(.horizontal, 25)
            
            HStack {
                if isSecure {
                    SecureField("Password", text: $password)
                } else {
                    TextField("Password", text: $password)
                }
                Button(action: {
                    isSecure.toggle()
                }) {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(30)
            .padding(.horizontal, 25)
            .padding(.bottom, 80)
            
            Button(action: {
                if email.isEmpty || password.isEmpty {
                    alertMessage = "Please enter both email and password"
                    showingAlert = true
                } else {
                    authorization.register(email: email, password: password) { error in
                        if let error = error {
                            alertMessage = error.localizedDescription
                            showingAlert = true
                        } else {
                            isLoggedIn = true
                        }
                    }
                }            }) {
                Text("Register")
                    .foregroundColor(.white)
                    .frame(width: 300, height: 55)
                    .background(Color.blue)
                    .cornerRadius(30)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .navigationDestination(isPresented: $isLoggedIn) {
               Home(limitsViewModel: limitsViewModel)
            }
            
            NavigationLink(destination: Login(limitsViewModel: limitsViewModel)) {
                Text("Already have an account? Login")
                    .foregroundColor(.blue)
            }
            .padding(.top, 20)
        }
        .padding()
    }
}

