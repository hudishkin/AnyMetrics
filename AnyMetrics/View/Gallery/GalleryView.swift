import SwiftUI
import MessageUI
import AnyMetricsShared
import VVSI

struct GalleryView: View {

    enum CatalogTab: Hashable {
        case personal
        case gallery
    }

    @State
    var mailResult: Result<MFMailComposeResult, Error>? = nil

    @StateObject
    private var viewState: ViewState<Interactor> = .init(Interactor())
    @Binding
    var allowDismissed: Bool
    var onPickMetric: ((Metric) -> Void)? = nil
    @State 
    var searchText: String = ""
    @State
    var catalogTab: CatalogTab
    @State
    var showAddMenu: Bool = false
    @State
    var showImportMenu: Bool = false
    @State
    var showEmailForm: Bool = false
    @State
    var showGenerate: Bool = false
    @State
    private var showSignInForGenerate = false
    @State
    private var generateJobID: UUID?
    @State
    private var generateRoute = "new"
    /// Same instance the open screen observes. A list link does not rebuild that screen.
    @StateObject
    private var generateReopen = GenerateReopen()
    /// Set by Generate New. The finished card stays until then.
    @State
    private var resultDismissed = false
    /// Job started on the open screen. The route id cannot change while that screen is up.
    @State
    private var restoreJobID: UUID?
    @State
    var personalPendingDelete: Metric?
    @State
    private var didLogOpen = false
    @State
    private var formSession = MetricFormSession(tracksFunnel: true)

    init(allowDismissed: Binding<Bool>, onPickMetric: ((Metric) -> Void)? = nil) {
        _allowDismissed = allowDismissed
        self.onPickMetric = onPickMetric
        _catalogTab = State(initialValue: onPickMetric == nil ? .personal : .gallery)
    }
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>
    @EnvironmentObject
    var mainState: ViewState<MainView.Interactor>
    @ObservedObject
    private var session = AuthSession.shared

    let columns = [
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ZStack {
                        NavigationLink(isActive: $showGenerate) {
                            GenerateMetricView(
                                jobID: generateJobID,
                                reopen: generateReopen,
                                onDismissResult: { resultDismissed = true },
                                onRememberJob: { jobID in
                                    resultDismissed = false
                                    restoreJobID = jobID
                                }
                            )
                            .id(generateRoute)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)

                        Button(action: openGenerate) {
                            HStack(spacing: 12) {
                                GenerateAIAnimation()
                                Text(AnyMetricsStrings.Metric.Add.generateAi)
                                    .font(Constants.itemTitleFont)
                                Spacer(minLength: 8)
                                if let freeAttempts {
                                    Text(freeAttempts)
                                        .font(Constants.itemDefaultFont)
                                        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .accessibilityIdentifier("catalog.generateByAI")
                    .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                    .listRowSeparator(.hidden)
                    .modifier(GenerateAIBorder())

                    NavigationLink(isActive: $showAddMenu) {
                        MetricFormView(
                            allowDismissed: $allowDismissed,
                            formSession: formSession,
                            action: { metric in
                                formSession.markSaved()
                                addCustomMetric(metric)
                            }
                        )
                        .navigationTitle(AnyMetricsStrings.Addmetric.titleNew)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        actionLabel(
                            icon: Image(systemName: "plus"),
                            title: AnyMetricsStrings.Metric.Add.manual
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .galleryActionRow()

                    NavigationLink(isActive: $showImportMenu) {
                        ImportMetricView(onImported: { metric in
                            showImportMenu = false
                            saveMetric(
                                metric,
                                source: AnalyticsEvents.Source.imported,
                                dismissGallery: true,
                                storeInPersonal: true
                            )
                        })
                        .navigationTitle(AnyMetricsStrings.Import.title)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        actionLabel(
                            icon: Image(systemName: "square.and.arrow.down"),
                            title: AnyMetricsStrings.Metric.Add.importRow
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .galleryActionRow()

                    Picker(AnyMetricsStrings.Catalog.personal, selection: $catalogTab) {
                        Text(AnyMetricsStrings.Catalog.personal).tag(CatalogTab.personal)
                        Text(AnyMetricsStrings.Gallery.title).tag(CatalogTab.gallery)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowSeparator(.hidden)
                    .galleryListRowSurface()
                    .accessibilityIdentifier("catalog.tabs")

                    if isSearching {
                        personalRows
                        galleryRows
                    } else if catalogTab == .personal {
                        personalRows
                    } else {
                        galleryRows
                    }
                }
                if viewState.state.showLoading {
                    ProgressView()
                }

                if showsNoResults {
                    VStack(alignment: .center) {
                        Text(AnyMetricsStrings.Gallery.noMetricMessage)
                            .font(Constants.itemDefaultFont)
                            .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button {
                            presentGalleryMail()
                        } label: {
                            Text(AnyMetricsStrings.Gallery.Button.send)
                                .font(Constants.itemTitleFont)
                                .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }

            }
            .padding(0)
            .navigationTitle(isPicker ? AnyMetricsStrings.Gallery.title : AnyMetricsStrings.Metric.Add.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPicker {
                    Button(AnyMetricsStrings.Common.close) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(
                AnyMetricsStrings.Metric.Actions.sure,
                isPresented: Binding(
                    get: { personalPendingDelete != nil },
                    set: { if !$0 { personalPendingDelete = nil } }
                )
            ) {
                Button(AnyMetricsStrings.Metric.Actions.confirmDelete, role: .destructive) {
                    if let metric = personalPendingDelete {
                        mainState.trigger(.deletePersonalMetric(metric.id))
                    }
                    personalPendingDelete = nil
                }
                Button(AnyMetricsStrings.Common.close, role: .cancel) {
                    personalPendingDelete = nil
                }
            } message: {
                Text(AnyMetricsStrings.Metric.Actions.deleteMessage)
            }
            .sheet(isPresented: $showEmailForm) {
                MailView(result: self.$mailResult) { compose in
                    compose.setSubject(AnyMetricsStrings.Gallery.Message.subject)
                    compose.setToRecipients([AppConfig.emailForReport])
                }
            }
            .sheet(isPresented: $showSignInForGenerate, onDismiss: finishSignInForGenerate) {
                ProfileView(dismissOnSignIn: true)
            }


        }
        .listStyle(PlainListStyle())
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: catalogDetailIsOpen ? .automatic : .always)
        )
        .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
        .onChange(of: searchText, perform: { newValue in
            viewState.trigger(.search(newValue.trimmingCharacters(in: .whitespacesAndNewlines)))
        })
        .onAppear {
            viewState.trigger(.onAppear)
            mainState.trigger(.migratePersonalCatalog)
            adoptGenerateRouteIfNeeded()
            if !didLogOpen {
                didLogOpen = true
                AnalyticsEvents.galleryOpened(
                    entry: isPicker ? AnalyticsEvents.GalleryEntry.onboarding : AnalyticsEvents.GalleryEntry.main
                )
            }
        }
        .background {
            // Observing the job here, not on the gallery, keeps a poll from rebuilding the open screen.
            GenerateLiveRouteMonitor(screenOpen: showGenerate) { jobID in
                syncGenerateRoute(liveJobID: jobID)
            }
        }
        .onChange(of: showGenerate) { shown in
            if shown, !session.isSignedIn {
                showGenerate = false
                allowDismissed = false
                showSignInForGenerate = true
                return
            }
            if !shown, showSignInForGenerate {
                return
            }
            // The sheet stays put while Generate or its history is open. Back is the only way out.
            allowDismissed = !shown
            guard !shown else { return }
            publishClosedJob()
            // Let the pop finish, then keep a finished metric or open a blank screen.
            Task { @MainActor in
                guard !showGenerate else { return }
                syncGenerateRoute(liveJobID: GenerationJobService.shared.live?.jobId)
            }
        }
        .onChange(of: showAddMenu, perform: { shown in
            if shown {
                formSession.begin()
            } else {
                formSession.abandonIfNeeded()
            }
        })
    }

    private var isPicker: Bool { onPickMetric != nil }

    private func openGenerate() {
        guard session.isSignedIn else {
            allowDismissed = false
            showSignInForGenerate = true
            return
        }
        showGenerate = true
    }

    /// The chat opens only after the sign-in sheet is gone, so the push is not dropped mid-dismiss.
    private func finishSignInForGenerate() {
        guard session.isSignedIn else {
            if !catalogDetailIsOpen {
                allowDismissed = true
            }
            return
        }
        Task { @MainActor in
            guard session.isSignedIn else { return }
            showGenerate = true
        }
    }

    /// A session still in progress, or the metric waiting for Generate New.
    private func adoptGenerateRouteIfNeeded() {
        guard !showGenerate else { return }
        if let jobID = GenerationJobService.shared.live?.jobId {
            restoreJobID = jobID
            if generateJobID == nil {
                generateJobID = jobID
                publishGenerateRoute()
            }
            return
        }
        guard !resultDismissed else { return }
        if let current = restoreJobID ?? generateJobID, shouldKeepGenerateJob(current) {
            adoptGenerateJob(current)
        }
    }

    private func syncGenerateRoute(liveJobID: UUID?) {
        if let liveJobID {
            resultDismissed = false
            restoreJobID = liveJobID
            if generateJobID == nil {
                generateJobID = liveJobID
                publishGenerateRoute()
            } else if generateJobID != liveJobID {
                adoptGenerateJob(liveJobID)
            }
            return
        }
        if resultDismissed {
            resultDismissed = false
            restoreJobID = nil
            dropGenerateRoute()
            return
        }
        if let candidate = restoreJobID ?? generateJobID, shouldKeepGenerateJob(candidate) {
            adoptGenerateJob(candidate)
            return
        }
        dropGenerateRoute()
    }

    private func adoptGenerateJob(_ jobID: UUID) {
        generateJobID = jobID
        generateRoute = jobID.uuidString
        publishGenerateRoute()
    }

    private func dropGenerateRoute() {
        generateJobID = nil
        generateRoute = UUID().uuidString
        publishGenerateRoute()
    }

    /// Tells the open screen which job to show. The link keeps the old conversation until this updates.
    private func publishClosedJob() {
        var next = generateReopen.state
        if resultDismissed {
            next.jobID = nil
        } else if let liveID = GenerationJobService.shared.live?.jobId {
            next.jobID = liveID
        } else if let candidate = restoreJobID ?? generateJobID, shouldKeepGenerateJob(candidate) {
            next.jobID = candidate
        } else {
            next.jobID = nil
        }
        generateReopen.state = next
    }

    private func publishGenerateRoute() {
        generateReopen.state = GenerateReopenState(jobID: generateJobID, token: generateRoute)
    }

    private func shouldKeepGenerateJob(_ jobID: UUID) -> Bool {
        guard let record = GenerationJobService.shared.record(jobID: jobID) else { return false }
        if record.isOpen { return true }
        guard let job = record.job else { return false }
        return GeneratedMetricAdapter.metric(from: job) != nil
    }

    /// `.always` stays pinned on pushed screens, so drop it while a catalog page is open.
    private var catalogDetailIsOpen: Bool {
        showGenerate || showAddMenu || showImportMenu
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !trimmedSearch.isEmpty }

    private var filteredPersonal: [Metric] {
        let metrics = mainState.state.personalMetrics.values.sorted { $0.created > $1.created }
        let query = trimmedSearch.lowercased()
        guard !query.isEmpty else { return metrics }
        return metrics.filter { metric in
            metric.title.lowercased().contains(query)
                || metric.measure.lowercased().contains(query)
                || metric.description?.lowercased().contains(query) == true
        }
    }

    private var showsNoResults: Bool {
        if viewState.state.showLoading { return false }
        if isSearching {
            return filteredPersonal.isEmpty && viewState.state.galleryItems.isEmpty
        }
        return catalogTab == .gallery && viewState.state.showSendRequestMetric
    }

    private var freeAttempts: String? {
        guard let account = session.account else { return nil }
        return BalanceLabel.freeCaption(balance: account.balance, paid: account.paid)
    }

    private func actionLabel(icon: Image, title: String) -> some View {
        HStack(spacing: 12) {
            icon
                .font(.system(size: Constants.createNewIcon, weight: .thin))
                .frame(width: Constants.createNewIcon, height: Constants.createNewIcon)
            Text(title).font(Constants.itemTitleFont)
        }
    }

    @ViewBuilder
    private var personalRows: some View {
        if filteredPersonal.isEmpty && !isSearching && catalogTab == .personal {
            personalEmptyState
                .listRowSeparator(.hidden)
                .galleryListRowSurface()
        } else if isSearching && !filteredPersonal.isEmpty {
            Section {
                ForEach(filteredPersonal, id: \.id) { metric in
                    personalRow(metric)
                }
            } header: {
                Text(AnyMetricsStrings.Catalog.personal).font(Constants.sectionFont)
            }
        } else if !filteredPersonal.isEmpty {
            ForEach(filteredPersonal, id: \.id) { metric in
                personalRow(metric)
            }
        }
    }

    private var personalEmptyState: some View {
        VStack(spacing: Constants.emptySpacing) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: Constants.emptyIconSize, weight: .light))
                .accessibilityHidden(true)
            Text(AnyMetricsStrings.Catalog.empty)
                .font(Constants.emptyFont)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, Constants.emptyHorizontalPadding)
        .padding(.vertical, Constants.emptyVerticalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("catalog.personal.empty")
    }

    private func personalRow(_ metric: Metric) -> some View {
        ItemView(
            metric: metric,
            addMetric: { picked in
                saveMetric(picked, source: AnalyticsEvents.Source.custom)
            },
            removeMetric: { uuid in
                mainState.trigger(.removeMetric(uuid))
            },
            alreadyAdded: !isPicker && mainState.state.metrics[metric.id] != nil
        )
        .buttonStyle(PlainButtonStyle())
        .listRowSeparator(.hidden)
        .galleryListRowSurface()
        .galleryMetricRowSpacing()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isPicker {
                Button(role: .destructive) {
                    personalPendingDelete = metric
                } label: {
                    Text(AnyMetricsStrings.Catalog.delete)
                }
            }
        }
    }

    @ViewBuilder
    private var galleryRows: some View {
        if !showsNoResults {
            ForEach(viewState.state.galleryItems, id: \.self) { group in
                Section {
                    ForEach(group.metrics, id: \.self) { metric in
                        ItemView(
                            metric: metric,
                            addMetric: { picked in
                                saveMetric(
                                    picked,
                                    source: AnalyticsEvents.Source.gallery,
                                    galleryGroup: group.name
                                )
                            },
                            removeMetric: { uuid in
                                mainState.trigger(.removeMetric(uuid))
                            },
                            alreadyAdded: !isPicker && mainState.state.metrics[metric.id] != nil
                        )
                        .buttonStyle(PlainButtonStyle())
                        .listRowSeparator(.hidden)
                        .galleryListRowSurface()
                        .galleryMetricRowSpacing()
                    }
                } header: {
                    Text(group.name).font(Constants.sectionFont)
                }
                .galleryListRowSurface()
            }
        }
    }

    private func presentGalleryMail() {
        if MFMailComposeViewController.canSendMail() {
            showEmailForm = true
            return
        }
        if let url = URL(string: "mailto:\(AppConfig.emailForReport)") {
            UIApplication.shared.open(url)
        }
    }

    private func addCustomMetric(_ metric: Metric) {
        showAddMenu = false
        saveMetric(
            metric,
            source: AnalyticsEvents.Source.custom,
            dismissGallery: true,
            storeInPersonal: true
        )
    }

    private func saveMetric(
        _ metric: Metric,
        source: String,
        galleryGroup: String? = nil,
        dismissGallery: Bool = false,
        storeInPersonal: Bool = false
    ) {
        var metric = metric
        if source == AnalyticsEvents.Source.gallery {
            metric = StarterMetric.applyingCollectionGradient(to: metric)
        }
        ImpactHelper.success()
        if let onPickMetric {
            onPickMetric(metric)
            presentationMode.wrappedValue.dismiss()
            return
        }
        let alreadyOnDashboard = mainState.state.metrics[metric.id] != nil
        let alreadyPersonal = mainState.state.personalMetrics[metric.id] != nil
        if !alreadyOnDashboard && !alreadyPersonal {
            AnalyticsEvents.metricAdded(
                source: source,
                type: metric.type,
                resultKind: metric.resultKind,
                galleryId: source == AnalyticsEvents.Source.gallery ? metric.id.uuidString : nil,
                galleryGroup: galleryGroup
            )
        }
        if source == AnalyticsEvents.Source.gallery,
           let personal = mainState.state.personalMetrics[metric.id] {
            mainState.trigger(.addMetricAndRefresh(personal))
        } else if storeInPersonal || alreadyPersonal {
            mainState.trigger(.addPersonalMetricAndRefresh(metric))
        } else {
            mainState.trigger(.addMetricAndRefresh(metric))
        }
        if dismissGallery {
            presentationMode.wrappedValue.dismiss()
        }
    }

}

private extension View {
    @ViewBuilder
    func galleryActionRow() -> some View {
        self
            .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
            .listRowSeparator(.hidden)
            .galleryListRowSurface()
    }

    @ViewBuilder
    func galleryListRowSurface() -> some View {
        if #available(iOS 26.0, *) {
            listRowBackground(Color.clear)
        } else {
            self
        }
    }

    @ViewBuilder
    func galleryMetricRowSpacing() -> some View {
        if #available(iOS 26.0, *) {
            listRowInsets(.vertical, GalleryView.Constants.itemRowSpacing)
        } else {
            self
        }
    }
}

private struct GenerateAIAnimation: View {
    private static let ink = Color(white: 0.17083333)

    var body: some View {
        RobotFaceView(size: 16, kind: .widget, ink: Self.ink)
            .frame(width: 16, height: 28)
    }
}

private struct GenerateAIBorder: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.bottom, 16)
            .listRowBackground(plate)
    }

    private var plate: some View {
        AIGradientBorder(cornerRadius: GalleryView.Constants.itemCorner)
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 16)
    }
}

#if DEBUG
struct Previews_GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView(allowDismissed: .constant(true))
        .preferredColorScheme(.light)
        .environmentObject(ViewState(MainView.Interactor()))
    }
}
#endif
