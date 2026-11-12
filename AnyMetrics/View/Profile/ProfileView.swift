import SwiftUI
import AnyMetricsShared
import VVSI

struct ProfileView: View {

    @StateObject
    private var viewState: ViewState<Interactor> = .init(Interactor())
    @Environment(\.dismiss)
    private var dismiss
    @State
    private var errorMessage: String?
    @State
    private var confirmLogOut = false
    @State
    private var didLoad = false

    var body: some View {
        Group {
            if showsSpinner {
                centered {
                    ProgressView()
                    screenButtons
                }
            } else if let account = viewState.state.account {
                VStack(spacing: 0) {
                    ScrollView {
                        signedIn(account)
                            .padding(.horizontal, Constants.horizontalPadding)
                            .padding(.top, 32)
                            .padding(.bottom, 16)
                    }
                    screenButtons
                        .padding(.bottom, 16)
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
                        screenButtons
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 12) {
                        ForEach(viewState.state.providers, id: \.self) { provider in
                            signInButton(provider)
                        }
                        if viewState.state.isSubmitting {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal, Constants.horizontalPadding)
                    Spacer()
                    screenButtons
                        .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            viewState.trigger(.load)
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
    }

    private var showsSpinner: Bool {
        let state = viewState.state
        return state.isLoading
            && state.account == nil
            && state.providers.isEmpty
            && !state.loadFailed
    }

    private func signedIn(_ account: BuilderAPI.Account) -> some View {
        VStack(spacing: 20) {
            avatar(for: account.user)
            VStack(spacing: 8) {
                Text(displayName(account.user))
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)
                if let email = secondaryEmail(account.user) {
                    Text(email)
                        .font(Constants.fontBody)
                        .foregroundColor(Constants.secondaryColor)
                }
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 0) {
                detailRow(AnyMetricsStrings.Profile.id, value: account.user.id.uuidString)
                divider
                detailRow(AnyMetricsStrings.Profile.balance, value: String(account.balance))
                divider
                detailRow(
                    AnyMetricsStrings.Profile.paid,
                    value: account.paid ? AnyMetricsStrings.Profile.paidYes : AnyMetricsStrings.Profile.paidNo
                )
            }
            .background(Constants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
        }
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

    private var screenButtons: some View {
        VStack(spacing: 12) {
            if viewState.state.isSignedIn {
                actionButton(AnyMetricsStrings.Profile.logOut, role: .destructive) {
                    confirmLogOut = true
                }
                .disabled(viewState.state.isSubmitting)
            }
            actionButton(AnyMetricsStrings.Common.close) {
                dismiss()
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
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

    private func signInButton(_ provider: BuilderAPI.SignInProvider) -> some View {
        Button {
            ImpactHelper.impactButton()
            viewState.trigger(.signIn(provider))
        } label: {
            HStack(spacing: 14) {
                providerIcon(provider)
                    .frame(width: 24, height: 24)
                Text(providerTitle(provider))
                    .font(Constants.fontRow)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundColor(Constants.textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Constants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewState.state.isSubmitting)
        .accessibilityLabel(providerTitle(provider))
    }

    private func avatar(for user: BuilderAPI.User) -> some View {
        Circle()
            .fill(Constants.cardBackground)
            .frame(width: Constants.avatarSize, height: Constants.avatarSize)
            .overlay {
                Text(initial(for: user))
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.textColor)
            }
            .accessibilityHidden(true)
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(Constants.fontRow)
                .foregroundColor(Constants.textColor)
            Spacer(minLength: 12)
            Text(value)
                .font(Constants.fontValue)
                .foregroundColor(Constants.secondaryColor)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 16)
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

    private func displayName(_ user: BuilderAPI.User) -> String {
        if let name = trimmed(user.name) { return name }
        if let email = trimmed(user.email) { return email }
        return AnyMetricsStrings.Profile.nameUnknown
    }

    private func secondaryEmail(_ user: BuilderAPI.User) -> String? {
        guard trimmed(user.name) != nil else { return nil }
        return trimmed(user.email)
    }

    private func initial(for user: BuilderAPI.User) -> String {
        let source = displayName(user)
        return String(source.prefix(1)).uppercased()
    }

    private func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private func providerTitle(_ provider: BuilderAPI.SignInProvider) -> String {
        switch provider {
        case .apple:
            return AnyMetricsStrings.Profile.signInApple
        case .google:
            return AnyMetricsStrings.Profile.signInGoogle
        case .github:
            return AnyMetricsStrings.Profile.signInGithub
        }
    }

    @ViewBuilder
    private func providerIcon(_ provider: BuilderAPI.SignInProvider) -> some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .semibold))
        case .google:
            Text("G")
                .font(.system(size: 18, weight: .semibold))
        case .github:
            AnyMetricsAsset.Assets.gitHub.swiftUIImage
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }
}

private enum Constants {
    static let avatarSize: CGFloat = 72
    static let cardCorner: CGFloat = 18
    static let buttonCorner: CGFloat = 30
    static let horizontalPadding: CGFloat = 24
    static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
    static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
    static let cardBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
    static let fontTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let fontBody = Font.system(size: 16, weight: .regular, design: .default)
    static let fontRow = Font.system(size: 17, weight: .medium, design: .default)
    static let fontValue = Font.system(size: 15, weight: .regular, design: .default)
}

#Preview {
    ProfileView()
}
