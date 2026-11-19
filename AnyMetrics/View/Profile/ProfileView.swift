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
    private var confirmDeleteAccount = false
    @State
    private var didLoad = false
    @ObservedObject
    private var generation = GenerationJobService.shared

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
            Button(AnyMetricsStrings.Profile.deleteAccount, role: .destructive) {}
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
            VStack(spacing: 0) {
                ScrollView {
                    signedIn(account)
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
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        appIcon
                        Text(AnyMetricsStrings.Profile.signInHeading)
                            .font(Constants.fontTitle)
                            .foregroundColor(Constants.textColor)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 12) {
                        ForEach(viewState.state.providers, id: \.self) { provider in
                            signInButton(provider)
                        }
                    }
                }
                .padding(.horizontal, Constants.horizontalPadding)
                Spacer()
            }
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
                NavigationLink {
                    GenerateHistoryView()
                } label: {
                    accountRow(
                        icon: "sparkles",
                        title: AnyMetricsStrings.Profile.generatedItems,
                        value: String(generatedCount)
                    ) {
                        chevron
                    }
                }
                .buttonStyle(.plain)
                rowDivider
                accountRow(
                    icon: "square.stack.3d.up",
                    title: AnyMetricsStrings.Profile.balance,
                    value: MetricCountLabel.text(account.balance)
                ) {
                    topUpButton(balance: account.balance)
                }
            }
            .background(Constants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
        }
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

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Constants.secondaryColor)
    }

    private func topUpButton(balance: Int) -> some View {
        NavigationLink {
            TopUpView(balance: balance)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Constants.textColor)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AnyMetricsStrings.Profile.topUp)
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
            Text(AnyMetricsStrings.Common.close)
                .font(Constants.fontBody)
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

    private var appIcon: some View {
        AnyMetricsAsset.Assets.appIconInfo.swiftUIImage
            .resizable()
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .clipShape(RoundedRectangle(cornerRadius: Constants.iconCorner, style: .continuous))
            .accessibilityHidden(true)
    }

    private func signInButton(_ provider: BuilderAPI.SignInProvider) -> some View {
        let signingIn = viewState.state.signingIn
        let isBusy = signingIn != nil
        let showsLoader = signingIn == provider
        return Button {
            ImpactHelper.impactButton()
            viewState.trigger(.signIn(provider))
        } label: {
            ZStack {
                Text(providerTitle(provider))
                    .font(Constants.fontRow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                HStack {
                    providerIcon(provider)
                        .frame(width: 24, height: 24)
                    Spacer(minLength: 0)
                    if showsLoader {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .foregroundColor(Constants.textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Constants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isBusy)
        .opacity(isBusy && !showsLoader ? 0.45 : 1)
        .accessibilityLabel(providerTitle(provider))
    }

    private func avatar(for user: BuilderAPI.User) -> some View {
        Circle()
            .fill(Constants.avatarGradient)
            .frame(width: Constants.avatarSize, height: Constants.avatarSize)
            .overlay {
                Text(initial(for: user))
                    .font(Constants.fontTitle)
                    .foregroundColor(Constants.avatarInitial)
            }
            .accessibilityHidden(true)
    }

    private func accountRow<Trailing: View>(
        icon: String,
        title: String,
        value: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 24)
            Text(title)
                .font(Constants.fontRow)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(Constants.fontValue)
                .foregroundColor(Constants.secondaryColor)
            trailing()
        }
        .foregroundColor(Constants.textColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 54)
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
    static let iconSize: CGFloat = 96
    static let iconCorner: CGFloat = 22
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
    static let avatarInitial = Color(red: 0.18, green: 0.12, blue: 0.08)
    static let avatarGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.90, blue: 0.74),
            Color(red: 0.98, green: 0.82, blue: 0.32),
            Color(red: 1.0, green: 0.52, blue: 0.24),
            Color(red: 0.55, green: 0.84, blue: 0.94)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

#Preview {
    ProfileView()
}

enum MetricCountLabel {
    static func text(_ count: Int) -> String {
        let language = Locale.current.language.languageCode?.identifier
        if language == "ru" {
            let value = abs(count) % 100
            let last = value % 10
            if last == 1, value != 11 {
                return AnyMetricsStrings.Profile.metricCountOne(count)
            }
            if (2...4).contains(last), !(12...14).contains(value) {
                return AnyMetricsStrings.Profile.metricCountFew(count)
            }
            return AnyMetricsStrings.Profile.metricCountMany(count)
        }
        if count == 1 {
            return AnyMetricsStrings.Profile.metricCountOne(count)
        }
        return AnyMetricsStrings.Profile.metricCountMany(count)
    }
}
