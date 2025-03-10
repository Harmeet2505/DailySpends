

import SwiftUI

struct WelcomeView: View {
    
    @State private var showSignIn: Bool = false
    @State private var showSignUp: Bool = false
    @ObservedObject var limitsViewModel: UserLimitsViewModel

    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Image
                Image("app_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: .screenWidth, height: .screenHeight)
                    .ignoresSafeArea()

                VStack {
                    // App Icon
                    Image("NewAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: .widthPer(per: 0.5))
                        .padding(.top, .topInsets + 8)

                    Spacer()

                    // Get Started Button with NavigationLink
                    NavigationLink(destination: Register(limitsViewModel: limitsViewModel), isActive: $showSignUp) {
                        PrimaryButton(title: "Get Started", onPressed: {
                            showSignUp.toggle()
                        })
                    }
                    .padding(.bottom, 15)

                    // I have an account Button with NavigationLink
                    NavigationLink(destination: Login(limitsViewModel: limitsViewModel), isActive: $showSignIn) {
                        PrimaryButton(title: "I have an account", onPressed: {
                            showSignIn.toggle()
                        })
                    }
                    .padding(.bottom, .bottomInsets)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
    }
}
