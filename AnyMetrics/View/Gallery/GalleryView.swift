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
                    NavigationLink(isActive: $showAddMenu) {
                        MetricFormView(
                            allowDismissed: $allowDismissed,
                            action: { _ in
                                showAddMenu.toggle()
                                presentationMode.wrappedValue.dismiss()
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
                            mainState.trigger(.addMetric(metric))
                            mainState.trigger(.refreshMetric(metric.id))
                            presentationMode.wrappedValue.dismiss()
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

                    if !viewState.state.showSendRequestMetric {
                        ForEach(viewState.state.galleryItems, id: \.self) { group in
                            Section {
                                ForEach(group.metrics, id: \.self) { metric in
                                    ItemView(
                                        metric: metric,
                                        addMetric: { m in
                                            ImpactHelper.success()
                                            mainState.trigger(.addMetric(m))
                                            mainState.trigger(.refreshMetric(m.id))
                                        }, removeMetric: { uuid in
                                            mainState.trigger(.removeMetric(uuid))
                                        }, alreadyAdded: mainState.state.metrics[metric.id] != nil)
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
                            showEmailForm = true
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
