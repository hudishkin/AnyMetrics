import SwiftUI
import UniformTypeIdentifiers
import VVSI
import AnyMetricsShared

extension MetricFormView {

    struct DisplayView: View {

        @Binding
        var allowDismissed: Bool
        @State
        private var showSaveError = false
        @State
        private var showStyleEditor = false
        @State
        private var showStyleImporter = false
        @State
        private var styleImportError: String?
        @State
        private var editorDraft: WidgetAppearance = .preset(.default)
        @State
        private var previewImagePath: String?
        @State
        private var dismissLockWorkItem: DispatchWorkItem?
        @EnvironmentObject
        var viewState: ViewState<MetricFormView.Interactor>
        @EnvironmentObject
        var requestViewState: ViewState<RequestFormView.Interactor>
        var action: (Metric) -> Void

        var body: some View {

            ZStack(alignment: .bottomTrailing) {
                Form {
                    Section {
                        designCarousel
                    } header: {
                        EmptyView()
                    }

                    Section {
                        HStack(spacing: 12) {
                            Button {
                                editorDraft = viewState.state.widgetAppearance
                                showStyleEditor = true
                            } label: {
                                Text(AnyMetricsStrings.Addmetric.Design.editStyle)
                                    .font(Constants.mainButtonFont)
                                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .background(AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor)
                            .cornerRadius(30)

                            Button {
                                showStyleImporter = true
                            } label: {
                                Text(AnyMetricsStrings.Addmetric.Design.importStyle)
                                    .font(Constants.mainButtonFont)
                                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .background(AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor)
                            .cornerRadius(30)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        HStack {
                            Text(AnyMetricsStrings.Addmetric.Field.title)
                            TextField(
                                AnyMetricsStrings.Addmetric.Field.titlePlaceholder,
                                text: formBinding(for: \.title, set: MetricFormView.VAction.setTitle))
                            .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text(AnyMetricsStrings.Addmetric.Field.paramMeasure)
                            TextField(
                                AnyMetricsStrings.Addmetric.Field.paramMeasurePlaceholder,
                                text: formBinding(for: \.measure, set: MetricFormView.VAction.setMeasure))
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 72)
                }

                HStack(alignment: .center, spacing: Constants.zero, content: {
                    Button(action: {
                        guard let metric = Metric(
                            formState: viewState.state,
                            requestState: requestViewState.state
                        ) else {
                            showSaveError = true
                            return
                        }
                        action(metric)

                    }, label: {
                        Spacer()
                        Text(viewState.state.isEdited ? AnyMetricsStrings.Addmetric.Button.save : AnyMetricsStrings.Addmetric.Button.add)
                            .font(Constants.mainButtonFont).padding()
                        Spacer()
                    })
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Constants.buttonTextColor)
                    .background(Constants.buttonBackground)
                    .cornerRadius(Constants.mainButtonCorner)
                    .disabled(!enableNextButton())
                    .opacity(opacityButton())
                })
                .padding()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle(AnyMetricsStrings.Addmetric.titleDisplay)
            .alert(AnyMetricsStrings.Common.error, isPresented: $showSaveError) {
                Button(AnyMetricsStrings.Common.ok, role: .cancel) {}
            } message: {
                Text(AnyMetricsStrings.Addmetric.Error.cannotSave)
            }
            .alert(
                AnyMetricsStrings.Common.error,
                isPresented: Binding(
                    get: { styleImportError != nil },
                    set: { if !$0 { styleImportError = nil } }
                )
            ) {
                Button(AnyMetricsStrings.Common.ok, role: .cancel) {}
            } message: {
                Text(styleImportError ?? "")
            }
            .sheet(isPresented: $showStyleEditor) {
                styleEditorSheet
            }
            .fileImporter(
                isPresented: $showStyleImporter,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleStyleImport(result)
            }
            .onAppear {
                applyDefaultTitleIfNeeded()
                refreshPreviewImagePath()
                scheduleDismissLock()
            }
            .onDisappear {
                dismissLockWorkItem?.cancel()
                dismissLockWorkItem = nil
            }
            .onChange(of: requestViewState.state.responseImageData) { _ in
                refreshPreviewImagePath()
            }
        }

        private var styleEditorSheet: some View {
            NavigationView {
                WidgetDesignEditorView(
                    appearance: $editorDraft,
                    metric: previewMetric(for: viewState.state.widgetDesign, appearance: editorDraft),
                    metricId: viewState.state.id
                )
                .navigationTitle(AnyMetricsStrings.Addmetric.Design.editStyle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AnyMetricsStrings.Common.close) {
                            showStyleEditor = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AnyMetricsStrings.Common.save) {
                            var custom = editorDraft
                            custom.presetId = WidgetAppearancePreset.custom.rawValue
                            viewState.trigger(.setWidgetAppearance(custom))
                            showStyleEditor = false
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }

        private enum DesignCarouselItem: Hashable {
            case custom
            case preset(WidgetDesign)
        }

        private var designCarousel: some View {
            VStack(spacing: 0) {
                TabView(selection: carouselBinding) {
                    if let custom = viewState.state.savedCustomAppearance {
                        designCarouselPage(
                            metric: previewMetric(
                                for: viewState.state.widgetDesign,
                                appearance: custom
                            )
                        )
                        .tag(DesignCarouselItem.custom)
                    }
                    ForEach(WidgetDesign.allCases) { design in
                        designCarouselPage(
                            metric: previewMetric(for: design, appearance: .preset(design))
                        )
                        .tag(DesignCarouselItem.preset(design))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: Constants.designCarouselHeight)
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        private func designCarouselPage(metric: Metric) -> some View {
            VStack(spacing: 12) {
                MetricWidgetDesignView(
                    metric: metric,
                    palette: .widget(),
                    useGlassEffect: false,
                    matchWidgetMetrics: true
                )
                    .frame(
                        width: Constants.metricViewSize,
                        height: Constants.metricViewSize,
                        alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.metricViewCorner)
                            .fill(Color(uiColor: .systemBackground))
                            .padding(Constants.metricViewPadding))
            }
        }

        private var carouselBinding: Binding<DesignCarouselItem> {
            Binding(
                get: {
                    if viewState.state.widgetAppearance.isCustom,
                       viewState.state.savedCustomAppearance != nil {
                        return .custom
                    }
                    return .preset(viewState.state.widgetDesign)
                },
                set: { item in
                    switch item {
                    case .custom:
                        if let custom = viewState.state.savedCustomAppearance {
                            viewState.trigger(.setWidgetAppearance(custom))
                        }
                    case .preset(let design):
                        viewState.trigger(.setWidgetDesign(design))
                    }
                }
            )
        }

        private func previewMetric(
            for design: WidgetDesign,
            appearance: WidgetAppearance? = nil
        ) -> Metric {
            let formState = viewState.state
            let requestState = requestViewState.state
            let resolvedAppearance = appearance ?? formState.widgetAppearance

            var resultWithError = formState.resultWithError
            var result = formState.result.isEmpty ? previewPlaceholderValue : formState.result
            var imagePath: String?
            if requestState.resultKind == .image {
                imagePath = previewImagePath
                result = ""
                resultWithError = imagePath == nil
            }

            return Metric(
                id: formState.id,
                title: formState.title.isEmpty ? "—" : formState.title,
                measure: formState.measure,
                type: requestState.typeMetric,
                resultKind: requestState.resultKind,
                result: result,
                resultImagePath: imagePath,
                resultWithError: resultWithError,
                formatter: .init(format: formState.formatType, length: formState.maxLengthValue),
                rules: .init(
                    parseRules: formState.parseRules,
                    type: formState.typeRule,
                    value: formState.parseConfigurationValue,
                    caseSensitive: formState.caseSensitive),
                updated: Date().addingTimeInterval(-180),
                widgetDesign: design,
                widgetAppearance: resolvedAppearance
            )
        }

        private var previewPlaceholderValue: String {
            switch requestViewState.state.typeMetric {
            case .checkStatus:
                return viewState.state.resultWithError ? "false" : "true"
            default:
                return "1,234"
            }
        }

        private func refreshPreviewImagePath() {
            guard requestViewState.state.resultKind == .image,
                  let data = requestViewState.state.responseImageData
            else {
                previewImagePath = nil
                return
            }
            previewImagePath = try? MetricResultImageStore.shared.save(
                data: data,
                metricId: viewState.state.id
            )
        }

        private func scheduleDismissLock() {
            dismissLockWorkItem?.cancel()
            let work = DispatchWorkItem {
                allowDismissed = false
            }
            dismissLockWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }

        private func handleStyleImport(_ result: Result<[URL], Error>) {
            switch result {
            case .failure:
                styleImportError = AnyMetricsStrings.Addmetric.Design.importStyleError
            case .success(let urls):
                guard let url = urls.first else {
                    styleImportError = AnyMetricsStrings.Addmetric.Design.importStyleError
                    return
                }
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let data = try Data(contentsOf: url)
                    var appearance = try WidgetStyleImport.parse(data: data)
                    try appearance.materializeImportedImages(metricId: viewState.state.id)
                    appearance.presetId = WidgetAppearancePreset.custom.rawValue
                    viewState.trigger(.setWidgetAppearance(appearance))
                } catch {
                    styleImportError = AnyMetricsStrings.Addmetric.Design.importStyleError
                }
            }
        }

        func opacityButton() -> CGFloat {
            enableNextButton() ? Constants.opacityEnable : Constants.opacityDisable
        }

        func enableNextButton() -> Bool {
            Metric.canSave(from: viewState.state, requestState: requestViewState.state)
        }

        private func applyDefaultTitleIfNeeded() {
            let current = viewState.state.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard current.isEmpty,
                  let defaultTitle = Metric.defaultTitle(from: requestViewState.state.requestUrl)
            else { return }
            viewState.trigger(.setTitle(defaultTitle))
        }

        private func formBinding<Value>(
            for keyPath: KeyPath<MetricFormView.VState, Value>,
            set action: @escaping (Value) -> MetricFormView.VAction
        ) -> Binding<Value> {
            Binding(
                get: { viewState.state[keyPath: keyPath] },
                set: { viewState.trigger(action($0)) }
            )
        }
    }

}
