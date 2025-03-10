//
//  DailySpendsApp.swift
//  DailySpends
//
//  Created by Harmeet Singh on 06/12/24.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct DailySpendsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var limitsViewModel = UserLimitsViewModel() // Create a shared ViewModel
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                WelcomeView(limitsViewModel: limitsViewModel)
            }
        }
    }
}
