import SwiftUI
import AnyMetricsShared
import VVSI

struct ProfileView: View {

    /// Closes this screen as soon as sign-in succeeds. The profile sheet from the dashboard stays open.
    var dismissOnSignIn = false

    @StateObject
    private var viewState: ViewState<Interactor> = .init(Interactor())
    @Environment(\.dismiss)
    private var dismiss
    @State
    private var errorMessage: String?
    @State
    private var confirmLogOut = false
    @State
    private var confirmDeleteAccount = false
    @State
    private var didLoad = false
    @ObservedObject
    private var generation = GenerationJobService.shared
    @ObservedObject
    private var session = AuthSession.shared

    var body: some View {
        NavigationStack {
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        closeButton
                    }
                    if viewState.state.isSignedIn {
                        ToolbarItem(placement: .topBarTrailing) {
                            accountMenu
                        }
                    }
                }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            viewState.trigger(.load)
        }
        .onChange(of: viewState.state.isSignedIn) { signedIn in
            guard signedIn, dismissOnSignIn else { return }
            dismiss()
        }
        .onReceive(viewState.notifications) { notification in
            if case .error(let message) = notification, !message.isEmpty {
                errorMessage = message
            }
        }
        .alert(AnyMetricsStrings.Common.error, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(AnyMetricsStrings.Common.ok, role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(AnyMetricsStrings.Profile.logOut, isPresented: $confirmLogOut) {
            Button(AnyMetricsStrings.Profile.logOut, role: .destructive) {
                viewState.trigger(.logOut)
            }
            Button(AnyMetricsStrings.Common.close, role: .cancel) {}
        } message: {
            Text(AnyMetricsStrings.Profile.logOutConfirm)
        }
        .alert(AnyMetricsStrings.Profile.deleteAccount, isPresented: $confirmDeleteAccount) {
            Button(AnyMetricsStrings.Profile.deleteAccount, role: .destructive) {
                viewState.trigger(.deleteAccount)
            }
            Button(AnyMetricsStrings.Common.close, role: .cancel) {}
        } message: {
            Text(AnyMetricsStrings.Profile.deleteAccountConfirm)
        }
    }

    private var navigationTitle: String {
        viewState.state.isSignedIn
            ? AnyMetricsStrings.Profile.title
            : AnyMetricsStrings.Profile.signInHeading
    }

    @ViewBuilder
    private var screen: some View {
        if showsSpinner {
            centered {
                ProgressView()
            }
        } else if let account = viewState.state.account {
            let account = displayed(account)
            VStack(spacing: 0) {
                ScrollView {
                    ProfileAccountView(account: account, generatedCount: generatedCount)
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }
                logoutButton
            }
            .task {
                guard !isPreview else { return }
                await GenerationJobService.shared.resume()
            }
        } else if viewState.state.providers.isEmpty {
            ZStack {
                Text(emptyMessage)
                    .font(Constants.fontBody)
                    .foregroundColor(Constants.secondaryColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, Constants.horizontalPadding)
                VStack(spacing: 12) {
                    Spacer()
                    if viewState.state.loadFailed || viewState.state.isSignedIn {
                        retryButton
                    }
                    logoutButton
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ProfileSignInView(
                providers: viewState.state.providers,
                signingIn: viewState.state.signingIn,
                onSignIn: { viewState.trigger(.signIn($0)) }
            )
        }
    }

    private var showsSpinner: Bool {
        let state = viewState.state
        return state.isLoading
            && state.account == nil
            && state.providers.isEmpty
            && !state.loadFailed
    }

    /// A purchase updates the shared account before this screen loads again.
    private func displayed(_ account: BuilderAPI.Account) -> BuilderAPI.Account {
        guard let live = session.account, live.user.id == account.user.id else { return account }
        return live
    }

    private var generatedCount: Int {
        generation.jobs.filter { record in
            guard record.jobId != nil else { return false }
            switch record.status {
            case .completed:
                return record.job?.result != nil
            case .failed:
                return true
            case .queued, .running, .needsInput, .cancelled, .none:
                return false
            }
        }.count
    }

    private var emptyMessage: String {
        if viewState.state.loadFailed || viewState.state.isSignedIn {
            return AnyMetricsStrings.Profile.loadFailed
        }
        return AnyMetricsStrings.Profile.signInUnavailable
    }

    private func centered<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 20) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var closeButton: some View {
        Button {
            ImpactHelper.impactButton()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Constants.textColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AnyMetricsStrings.Common.close)
    }

    private var accountMenu: some View {
        Menu {
            Button(role: .destructive) {
                confirmDeleteAccount = true
            } label: {
                Text(AnyMetricsStrings.Profile.deleteAccount)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Constants.textColor)
                .frame(width: 44, height: 44)
        }
        .disabled(viewState.state.isSubmitting)
        .accessibilityLabel(AnyMetricsStrings.Profile.more)
    }

    @ViewBuilder
    private var logoutButton: some View {
        if viewState.state.isSignedIn {
            actionButton(AnyMetricsStrings.Profile.logOut, role: .destructive) {
                confirmLogOut = true
            }
            .disabled(viewState.state.isSubmitting)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.bottom, 16)
        }
    }

    private var retryButton: some View {
        Button {
            viewState.trigger(.load)
        } label: {
            Text(AnyMetricsStrings.Profile.retry)
                .font(Constants.fontRow)
                .foregroundColor(Constants.textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Constants.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Constants.horizontalPadding)
    }

    private func actionButton(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: {
            ImpactHelper.impactButton()
            action()
        }) {
            Text(title)
                .foregroundColor(role == .destructive ? .red : Constants.textColor)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .background(Constants.cardBackground)
        .cornerRadius(Constants.buttonCorner)
    }
}

#Preview {
    ProfileView()
}

enum BalanceLabel {
    /// Unpaid balance is the free remainder. After a purchase the same number is the credit balance.
    static func text(balance: Int, paid: Bool) -> String {
        if let free = freeCaption(balance: balance, paid: paid) {
            return free
        }
        return String(balance)
    }

    /// Shown only while the account still has complimentary attempts.
    static func freeCaption(balance: Int, paid: Bool) -> String? {
        guard !paid, balance > 0 else { return nil }
        return AnyMetricsStrings.Profile.freeAttempts(balance)
    }
}
