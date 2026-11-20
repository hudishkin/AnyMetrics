import SwiftUI

/// Avatar, name, and the account card: generated items and balance with top-up.
struct ProfileAccountView: View {
    private typealias Constants = ProfileView.Constants

    var account: BuilderAPI.Account
    var generatedCount: Int

    var body: some View {
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
                    value: balanceValue
                ) {
                    HStack(spacing: 8) {
                        if let free = BalanceLabel.freeCaption(balance: account.balance, paid: account.paid) {
                            Text(free)
                                .font(Constants.fontValue)
                                .foregroundColor(Constants.secondaryColor)
                        }
                        topUpButton
                    }
                }
            }
            .background(Constants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Constants.secondaryColor)
    }

    private var balanceValue: String {
        guard BalanceLabel.freeCaption(balance: account.balance, paid: account.paid) == nil else {
            return ""
        }
        return String(account.balance)
    }

    private var topUpButton: some View {
        NavigationLink {
            TopUpView(balance: account.balance, paid: account.paid)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Constants.textColor)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AnyMetricsStrings.Profile.topUp)
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
}
