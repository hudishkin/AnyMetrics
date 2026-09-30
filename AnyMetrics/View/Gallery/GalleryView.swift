import SwiftUI
import MessageUI
import AnyMetricsShared
import VVSI

struct GalleryView: View {

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
    var showAddMenu: Bool = false
    @State
    var showImportMenu: Bool = false
    @State
    var showEmailForm: Bool = false
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
                    if !isPicker {
                        NavigationLink(isActive: $showAddMenu) {
                            MetricFormView(
                                allowDismissed: $allowDismissed,
                                action: { metric in
                                    addCustomMetric(metric)
                                }
                            )
                            .navigationTitle(AnyMetricsStrings.Addmetric.titleNew)
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 12) {
                                AnyMetricsAsset.Assets.plus.swiftUIImage
                                    .resizable()
                                    .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                                Text(AnyMetricsStrings.Metric.Add.custom).font(Constants.itemTitleFont)
                            }
                        }
                        .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                        .listRowSeparator(.hidden)
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(isActive: $showImportMenu) {
                            ImportMetricView(onImported: { metric in
                                showImportMenu = false
                                saveMetric(metric, dismissGallery: true)
                            })
                            .navigationTitle(AnyMetricsStrings.Import.title)
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(spacing: 12) {
                                AnyMetricsAsset.Assets.import.swiftUIImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: Constants.createNewIcon, height: Constants.createNewIcon)
                                Text(AnyMetricsStrings.Import.title).font(Constants.itemTitleFont)
                            }
                        }
                        .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                        .listRowSeparator(.hidden)
                        .buttonStyle(PlainButtonStyle())
                    }

                    if !viewState.state.showSendRequestMetric {
                        ForEach(displayedGalleryItems, id: \.self) { group in
                            Section {
                                ForEach(group.metrics, id: \.self) { metric in
                                    ItemView(
                                        metric: metric,
                                        addMetric: { m in
                                            saveMetric(m)
                                        }, removeMetric: { uuid in
                                            mainState.trigger(.removeMetric(uuid))
                                        }, alreadyAdded: !isPicker && mainState.state.metrics[metric.id] != nil)
                                    .buttonStyle(PlainButtonStyle())
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text(group.name).font(Constants.sectionFont)
                            }
                        }
                    }

                }
                if viewState.state.showLoading {
                    ProgressView()
                }

                if viewState.state.showSendRequestMetric {
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
                        }.buttonStyle(PlainButtonStyle())
                    }
                }

            }
            .padding(0)
            .navigationTitle(AnyMetricsStrings.Gallery.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPicker {
                    Button(AnyMetricsStrings.Common.close) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
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
        .onChange(of: searchText, perform: { newValue in
            viewState.trigger(.search(newValue))
        })
        .onAppear {
            viewState.trigger(.onAppear)
        }
    }

    private var isPicker: Bool { onPickMetric != nil }

    private var displayedGalleryItems: [GalleryItem] {
        guard isPicker else { return viewState.state.galleryItems }
        return Self.movingQuoteFirst(viewState.state.galleryItems)
    }

    private static func movingQuoteFirst(_ items: [GalleryItem]) -> [GalleryItem] {
        let quoteID = StarterMetric.id
        var quote: Metric?
        var groups = items.map { group -> GalleryItem in
            var metrics = group.metrics
            if let index = metrics.firstIndex(where: { $0.id == quoteID }) {
                quote = metrics.remove(at: index)
                return GalleryItem(name: group.name, tags: group.tags, metrics: metrics)
            }
            return group
        }
        guard let quote else { return items }
        if groups.isEmpty {
            return [GalleryItem(name: "", tags: "", metrics: [quote])]
        }
        let first = groups[0]
        groups[0] = GalleryItem(name: first.name, tags: first.tags, metrics: [quote] + first.metrics)
        return groups
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
        saveMetric(metric, dismissGallery: true)
    }

    private func saveMetric(_ metric: Metric, dismissGallery: Bool = false) {
        ImpactHelper.success()
        if let onPickMetric {
            onPickMetric(metric)
            presentationMode.wrappedValue.dismiss()
            return
        }
        mainState.trigger(.addMetricAndRefresh(metric))
        if dismissGallery {
            presentationMode.wrappedValue.dismiss()
        }
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
