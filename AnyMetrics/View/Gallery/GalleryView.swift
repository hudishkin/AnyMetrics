//
//  AddMetricView.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import SwiftUI
import MessageUI
import AnyMetricsShared

// MARK: - Constants

fileprivate enum Constants {
    static let addButtonInset = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    static let addButtonCorner: CGFloat = 20
    static let itemTitleFont = Font.system(size: 17, weight: .semibold, design: .default)
    static let itemDefaultFont = Font.system(size: 12, weight: .regular, design: .default)
    static let itemDefaultBoldFont = Font.system(size: 12, weight: .semibold, design: .default)

    static let itemButtonOffset = CGSize(width: -10, height: 10)
    static let itemButtonSize: CGFloat = 46
    static let itemAddButtonCorner: CGFloat = Self.itemButtonSize / 2
    static let itemButtonLine: CGFloat = 1
    static let descriptionInset = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 52)
    static let itemContentSpacing: CGFloat = 4
    static let itemContentPadding: CGFloat = 14
    static let itemCorner: CGFloat = 18
    static let contentInset = EdgeInsets(top: 4, leading: 12, bottom: 0, trailing: 12)
    static let sectionFont = Font.system(size: 17, weight: .semibold, design: .default)
    static let sectionInset = EdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2)
    static let createNewIcon: CGFloat = 16
    static let createNewVSpacing: CGFloat = 16
    static let createNewHSpacing: CGFloat = 12
}

// MARK: - GalleryItemView

struct GalleryItemView: View {
    var metric: Metric
    var addMetric: (Metric) -> Void
    var removeMetric: (UUID) -> Void
    @State var alreadyAdded: Bool

    var body: some View {
        ZStack(alignment: .topTrailing ) {
            VStack(alignment: .leading, spacing: Constants.itemContentSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: Constants.itemContentSpacing) {
                        Text(metric.title)
                            .font(Constants.itemTitleFont)
                        Text(metric.measure)
                            .font(Constants.itemDefaultBoldFont)
                            .foregroundColor(AssetColor.secondaryText)

                    }
                    Spacer()
                }

                if let description = metric.description, !description.isEmpty {
                    Text(description)
                        .lineLimit(nil)

                        .font(Constants.itemDefaultFont)
                        .foregroundColor(AssetColor.secondaryText)
                        .padding(Constants.descriptionInset)
                }

                if let website = metric.website {
                    Link(website.absoluteString, destination: website)
                        .font(Constants.itemDefaultFont)
                }
            }
            .padding(Constants.itemContentPadding)
            .background(AssetColor.galleryItemBackground)
            .cornerRadius(Constants.itemCorner)
            if alreadyAdded {
                Button {
                    alreadyAdded = false
                    removeMetric(metric.id)

                } label: {
                    AssetImage.minus
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: Constants.itemButtonSize, height: Constants.itemButtonSize, alignment: .center)
                        .background(Circle().fill(AssetColor.red))

                }
                .offset(Constants.itemButtonOffset)
            } else {

                Button {
                    alreadyAdded = true
                    addMetric(metric)
                } label: {
                    AssetImage.plus
                        .renderingMode(.template)
                        .frame(width: Constants.itemButtonSize, height: Constants.itemButtonSize, alignment: .center)
                        .overlay {
                            Circle()
                                .stroke(AssetColor.baseText, lineWidth: Constants.itemButtonLine)
                        }
                }
                .tint(AssetColor.baseText)
                .offset(Constants.itemButtonOffset)

            }

        }
    }
}

// MARK: - GalleryView

struct GalleryView: View {

    @State var mailResult: Result<MFMailComposeResult, Error>? = nil

    @StateObject var viewModel = GalleryViewModel()
    @Binding var allowDismissed: Bool
    @State var searchText: String = ""
    @State var showAddMenu: Bool = false
    @State var showEmailForm: Bool = false
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var mainViewModel: MainViewModel

    let columns = [
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    NavigationLink(isActive: $showAddMenu) {
                        NewMetricView(allowDismissed: $allowDismissed) {
                            showAddMenu.toggle()
                            presentationMode.wrappedValue.dismiss()
                        }.environmentObject(mainViewModel)
                    } label: {
                        HStack {
                            AssetImage.plus
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: Constants.createNewIcon, height:  Constants.createNewIcon)
                            Text(L10n.metricAddCustom()).font(Constants.itemTitleFont)
                        }
                    }
                    .tint(AssetColor.baseText)
                    .listRowSeparator(.hidden)
                    .buttonStyle(PlainButtonStyle())

                    if !viewModel.showSendRequestMetric {
                        ForEach(viewModel.galleryItems, id: \.self) { group in
                            Section {
                                ForEach(group.metrics, id: \.self) { metric in
                                    GalleryItemView(
                                        metric: metric,
                                        addMetric: { m in
                                            ImpactHelper.success()
                                            mainViewModel.addMetric(metric: m)
                                            mainViewModel.updateMetric(id: m.id)
                                        }, removeMetric: { uuid in
                                            mainViewModel.removeMetric(id: uuid)
                                        }, alreadyAdded: mainViewModel.metrics[metric.id] != nil)
                                    .buttonStyle(PlainButtonStyle())
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                Text(group.name).font(Constants.sectionFont)
                            }
                        }
                    }

                }
                if viewModel.showLoading {
                    ProgressView()
                }

                if viewModel.showSendRequestMetric {
                    VStack(alignment: .center) {
                        Text(L10n.galleryNoMetricMessage())
                            .font(Constants.itemDefaultFont)
                            .foregroundColor(AssetColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button {
                            showEmailForm = true
                        } label: {
                            Text(L10n.galleryButtonSend())
                                .font(Constants.itemTitleFont)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }

            }
            .padding(0)
            .navigationTitle(L10n.galleryTitle())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEmailForm) {
                MailView(result: self.$mailResult) { compose in
                    compose.setSubject(L10n.galleryMessageSubject())
                    compose.setToRecipients([AppConfig.emailForReport])
                }
            }


        }
        .listStyle(PlainListStyle())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .onChange(of: searchText, perform: { newValue in
            viewModel.search(text: newValue)
        })
        .onAppear {
            viewModel.load()
        }
    }

}

#if DEBUG
struct Previews_GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView(allowDismissed: .constant(true))
        .preferredColorScheme(.light)
        .environmentObject(MainViewModel())
    }
}
#endif
