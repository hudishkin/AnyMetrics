import SwiftUI
import AnyMetricsShared
import VVSI

struct TopUpView: View {

    @StateObject
    private var viewState: ViewState<Interactor>
    @Environment(\.colorScheme)
    private var colorScheme
    @State
    private var errorMessage: String?
    @State
    private var didLoad = false
    private var onPurchased: () -> Void

    init(
        balance: Int,
        paid: Bool,
        store: CreditProductLoading = StoreKitCreditStore(),
        onPurchased: @escaping () -> Void = {}
    ) {
        _viewState = StateObject(wrappedValue: ViewState(Interactor(balance: balance, paid: paid, store: store)))
        self.onPurchased = onPurchased
    }

    var body: some View {
        screen
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(alignment: .top) {
                RobotGradientWash(
                    direction: .down,
                    softness: colorScheme == .dark ? 1 : 0.92,
                    opacity: colorScheme == .dark ? 0.24 : 0.5
                )
                .frame(height: Constants.glowHeight)
                .ignoresSafeArea(edges: .top)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(AnyMetricsStrings.Profile.topUp)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                purchaseBar
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                viewState.trigger(.load)
            }
            .onReceive(viewState.notifications) { notification in
                switch notification {
                case .error(let message):
                    if !message.isEmpty {
                        errorMessage = message
                    }
                case .purchased:
                    onPurchased()
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
    }

    private var screen: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                packs
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            RobotFaceView(size: Constants.robotSize, kind: .glance)
            Text(AnyMetricsStrings.TopUp.headline)
                .font(Constants.fontTitle)
                .foregroundColor(Constants.textColor)
            Text(AnyMetricsStrings.TopUp.subtitle)
                .font(Constants.fontSubtitle)
                .foregroundColor(Constants.secondaryColor)
                .fixedSize(horizontal: false, vertical: true)
            if showsBalance {
                Text(AnyMetricsStrings.TopUp.balance(GenerationCountLabel.text(viewState.state.balance)))
                    .font(Constants.fontBadge)
                    .foregroundColor(Constants.textColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Constants.chipFill)
                    .clipShape(Capsule())
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var showsBalance: Bool {
        viewState.state.paid || viewState.state.balance > 0
    }

    @ViewBuilder
    private var packs: some View {
        if viewState.state.isLoading && viewState.state.offers.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        } else if viewState.state.offers.isEmpty {
            VStack(spacing: 16) {
                Text(emptyMessage)
                    .font(Constants.fontSubtitle)
                    .foregroundColor(Constants.secondaryColor)
                    .multilineTextAlignment(.center)
                retryButton
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 10) {
                ForEach(viewState.state.offers) { offer in
                    offerCard(offer)
                }
            }
        }
    }

    private var emptyMessage: String {
        viewState.state.loadFailed
            ? AnyMetricsStrings.TopUp.loadFailed
            : AnyMetricsStrings.TopUp.empty
    }

    private func offerCard(_ offer: CreditOffer) -> some View {
        let selected = offer.id == viewState.state.selectedID
        return Button {
            guard !viewState.state.isPurchasing else { return }
            ImpactHelper.impactLight()
            viewState.trigger(.select(offer.id))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                if offer.isBest || offer.savingsPercent != nil {
                    badges(offer)
                        .padding(.leading, Constants.checkColumn)
                }
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(selected ? Constants.textColor : Constants.secondaryColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(GenerationCountLabel.text(offer.credits))
                            .font(Constants.fontRow)
                            .foregroundColor(Constants.textColor)
                        Text(AnyMetricsStrings.TopUp.perGeneration(offer.perCreditPrice))
                            .font(Constants.fontCaption)
                            .foregroundColor(offer.isBest ? Constants.textColor : Constants.secondaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(offer.displayPrice)
                        .font(Constants.fontPrice)
                        .foregroundColor(Constants.textColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Constants.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous))
            .overlay {
                cardStroke(selected: selected, best: offer.isBest)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("topup.product.\(offer.id)")
    }

    private func badges(_ offer: CreditOffer) -> some View {
        HStack(spacing: 6) {
            if offer.isBest {
                Text(AnyMetricsStrings.TopUp.best)
                    .font(Constants.fontBadge)
                    .lineLimit(1)
                    .foregroundColor(Constants.badgeInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LinearGradient(gradient: Constants.accent, startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
            if let savings = offer.savingsPercent {
                Text(AnyMetricsStrings.TopUp.save("\(savings)%"))
                    .font(Constants.fontBadge)
                    .lineLimit(1)
                    .foregroundColor(Constants.textColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Constants.chipFill)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private func cardStroke(selected: Bool, best: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Constants.cardCorner, style: .continuous)
        if selected, best {
            AIGradientBorder(cornerRadius: Constants.cardCorner)
        } else if selected {
            shape.strokeBorder(Constants.textColor.opacity(0.45), lineWidth: 1.5)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 8) {
            benefit(icon: "infinity", text: AnyMetricsStrings.TopUp.noExpiry)
            benefit(icon: "checkmark.seal", text: AnyMetricsStrings.TopUp.oneTime)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func benefit(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Constants.textColor)
                .frame(width: 22)
            Text(text)
                .font(Constants.fontBenefit)
                .foregroundColor(Constants.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var purchaseBar: some View {
        if let offer = selectedOffer {
            VStack(spacing: 14) {
                benefits
                VStack(spacing: 10) {
                    buyButton(offer)
                    legalLinks
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func buyButton(_ offer: CreditOffer) -> some View {
        Button {
            ImpactHelper.impactButton()
            viewState.trigger(.purchase)
        } label: {
            ZStack {
                Text(AnyMetricsStrings.TopUp.buy(offer.displayPrice))
                    .opacity(viewState.state.isPurchasing ? 0 : 1)
                if viewState.state.isPurchasing {
                    ProgressView()
                        .tint(Constants.buttonText)
                }
            }
            .font(Constants.fontButton)
            .foregroundColor(Constants.buttonText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Constants.textColor)
            .clipShape(RoundedRectangle(cornerRadius: Constants.buttonCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewState.state.isPurchasing)
        .accessibilityIdentifier("topup.buy")
    }

    private var legalLinks: some View {
        HStack(spacing: 8) {
            Link(AnyMetricsStrings.TopUp.terms, destination: AppConfig.Urls.terms)
            Text("·")
            Link(AnyMetricsStrings.Info.privacy, destination: AppConfig.Urls.privacyPolicy)
        }
        .font(Constants.fontLegal)
        .foregroundColor(Constants.secondaryColor)
        .tint(Constants.secondaryColor)
    }

    private var selectedOffer: CreditOffer? {
        viewState.state.offers.first { $0.id == viewState.state.selectedID }
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
    }
}

enum GenerationCountLabel {
    static func text(_ count: Int) -> String {
        let language = Locale.current.language.languageCode?.identifier
        let value = abs(count) % 100
        let last = value % 10
        if language == "ru" {
            if last == 1, value != 11 {
                return AnyMetricsStrings.TopUp.generationsOne(count)
            }
            if (2...4).contains(last), !(12...14).contains(value) {
                return AnyMetricsStrings.TopUp.generationsFew(count)
            }
            return AnyMetricsStrings.TopUp.generationsMany(count)
        }
        if count == 1 {
            return AnyMetricsStrings.TopUp.generationsOne(count)
        }
        return AnyMetricsStrings.TopUp.generationsMany(count)
    }
}

#Preview {
    NavigationStack {
        TopUpView(balance: 0, paid: false)
    }
}
