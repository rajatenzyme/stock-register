import Foundation
import SwiftUI
import Combine
import GoogleSignIn
import FirebaseCore

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var currentUser: GIDGoogleUser?
    @Published var userDisplayName: String = ""
    @Published var userEmail: String = ""
    @Published var userProfileImageURL: URL?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    static let shared = AuthenticationManager()
    
    private init() {
        checkCurrentUser()
    }
    
    func checkCurrentUser() {
        if let user = GIDSignIn.sharedInstance.currentUser {
            self.currentUser = user
            self.isSignedIn = true
            self.userDisplayName = user.profile?.name ?? "User"
            self.userEmail = user.profile?.email ?? ""
            self.userProfileImageURL = user.profile?.imageURL(withDimension: 100)
        }
    }
    
    func signIn() async {
        isLoading = true
        errorMessage = nil
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            errorMessage = "Unable to get root view controller"
            isLoading = false
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = result.user
            
            self.currentUser = user
            self.isSignedIn = true
            self.userDisplayName = user.profile?.name ?? "User"
            self.userEmail = user.profile?.email ?? ""
            self.userProfileImageURL = user.profile?.imageURL(withDimension: 100)
            
            isLoading = false
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        
        currentUser = nil
        isSignedIn = false
        userDisplayName = ""
        userEmail = ""
        userProfileImageURL = nil
        errorMessage = nil
    }
    
    func restorePreviousSignIn() async {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            self.currentUser = user
            self.isSignedIn = true
            self.userDisplayName = user.profile?.name ?? "User"
            self.userEmail = user.profile?.email ?? ""
            self.userProfileImageURL = user.profile?.imageURL(withDimension: 100)
        } catch {
            self.isSignedIn = false
        }
    }
}
