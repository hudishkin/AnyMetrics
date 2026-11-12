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

    let columns = [
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    NavigationLink(isActive: $showGenerate) {
                        GenerateMetricView()
                    } label: {
                        HStack(spacing: 12) {
                            GenerateAIAnimation()
                            Text(AnyMetricsStrings.Metric.Add.generateAi)
                                .font(Constants.itemTitleFont)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
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
                            icon: AnyMetricsAsset.Assets.plus.swiftUIImage,
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
                            icon: AnyMetricsAsset.Assets.import.swiftUIImage,
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


        }
        .listStyle(PlainListStyle())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
        .onChange(of: searchText, perform: { newValue in
            viewState.trigger(.search(newValue.trimmingCharacters(in: .whitespacesAndNewlines)))
        })
        .onAppear {
            viewState.trigger(.onAppear)
            mainState.trigger(.migratePersonalCatalog)
            if !didLogOpen {
                didLogOpen = true
                AnalyticsEvents.galleryOpened(
                    entry: isPicker ? AnalyticsEvents.GalleryEntry.onboarding : AnalyticsEvents.GalleryEntry.main
                )
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

    private func actionLabel(icon: Image, title: String) -> some View {
        HStack(spacing: 12) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.createNewIcon, height: Constants.createNewIcon)
            Text(title).font(Constants.itemTitleFont)
        }
    }

    @ViewBuilder
    private var personalRows: some View {
        if filteredPersonal.isEmpty && !isSearching && catalogTab == .personal {
            Text(AnyMetricsStrings.Catalog.empty)
                .font(Constants.itemDefaultFont)
                .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Constants.createNewVSpacing)
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
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.colorScheme)
    private var colorScheme

    private static let cycle: TimeInterval = 6

    func body(content: Content) -> some View {
        content
            .padding(.bottom, 16)
            .listRowBackground(plate)
    }

    private var plate: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let turn = reduceMotion
                ? 0.15
                : timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: Self.cycle) / Self.cycle
            border(turn: turn)
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .padding(.bottom, 16)
        }
    }

    private func border(turn: Double) -> some View {
        let angle = turn * 360
        let shape = RoundedRectangle(cornerRadius: GalleryView.Constants.itemCorner, style: .continuous)
        let gradient = AngularGradient(
            gradient: Self.gradient,
            center: .center,
            startAngle: .degrees(angle),
            endAngle: .degrees(angle + 360)
        )
        let glow = colorScheme == .dark ? 0.45 : 0.55

        return ZStack {
            shape
                .stroke(gradient, lineWidth: 8)
                .blur(radius: 8)
                .clipShape(shape)
                .opacity(glow)
            shape
                .strokeBorder(gradient, lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private static let gradient = Gradient(stops: [
        .init(color: Color(red: 0.45, green: 0.76, blue: 0.72), location: 0.00),
        .init(color: Color(red: 0.74, green: 0.84, blue: 0.48), location: 0.16),
        .init(color: Color(red: 0.95, green: 0.84, blue: 0.32), location: 0.32),
        .init(color: Color(red: 0.93, green: 0.52, blue: 0.24), location: 0.46),
        .init(color: Color(red: 0.96, green: 0.74, blue: 0.48), location: 0.58),
        .init(color: Color(red: 0.90, green: 0.82, blue: 0.66), location: 0.72),
        .init(color: Color(red: 0.62, green: 0.78, blue: 0.88), location: 0.86),
        .init(color: Color(red: 0.45, green: 0.76, blue: 0.72), location: 1.00),
    ])
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
