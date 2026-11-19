import Foundation
import VVSI

extension ProfileView {

    struct VState: StateProtocol {
        var account: BuilderAPI.Account?
        var isSignedIn = false
        var providers: [BuilderAPI.SignInProvider] = []
        var isLoading = true
        var isSubmitting = false
        var signingIn: BuilderAPI.SignInProvider?
        var loadFailed = false
    }

    enum VAction: ActionProtocol {
        case load
        case logOut
        case signIn(BuilderAPI.SignInProvider)
    }

    enum VNotification: NotificationProtocol {
        case error(String)
    }
}
