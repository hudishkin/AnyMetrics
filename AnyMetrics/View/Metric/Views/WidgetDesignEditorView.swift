import SwiftUI
import PhotosUI
import AnyMetricsShared
import UIKit

struct WidgetDesignEditorView: View {

    private enum Constants {
        static let textColor = AnyMetricsAsset.Assets.baseText.swiftUIColor
        static let secondaryColor = AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        static let selectedRowBackground = AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        static let previewBackground = Color(uiColor: .systemBackground)
        static let chromeBackground = Color(uiColor: .systemGroupedBackground)

        static let previewSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let chromeTopPadding: CGFloat = 8
        static let chromeBottomPadding: CGFloat = 10
        static let iconWidth: CGFloat = 22
        static let controlSpacing: CGFloat = 12
        static let controlVerticalPadding: CGFloat = 4

        static let smallPreviewSize: CGFloat = 200
        static let mediumPreviewWidth: CGFloat = 320
        static let mediumPreviewHeight: CGFloat = 150
        static let smallCanvasHeight: CGFloat = 220
        static let mediumCanvasHeight: CGFloat = 168
        static let metricViewCorner: CGFloat = MetricFormView.Constants.metricViewCorner
        static let mediumViewCorner: CGFloat = 22
        static let metricViewPadding: CGFloat = MetricFormView.Constants.metricViewPadding

        static let fontCaption = Font.system(size: 12, weight: .regular, design: .default)
        static let fontAction = Font.system(size: 13, weight: .semibold, design: .default)
        static let fontRow = Font.system(size: 17, weight: .regular, design: .default)
        static let fontRowSelected = Font.system(size: 17, weight: .semibold, design: .default)
    }

    @Binding var appearance: WidgetAppearance
    let metric: Metric
    let metricId: UUID

    @State private var sizeKey: WidgetSizeKey = .small
    @State private var selectedKind: WidgetElementKind? = .value
    @State private var dragOrigins: [WidgetElementKind: NormalizedRect] = [:]
    @State private var imagePanOrigins: [WidgetElementKind: (x: Double, y: Double)] = [:]
    @State private var backgroundPanOrigin: (x: Double, y: Double)?
    @State private var fittedSizes: [WidgetElementKind: CGSize] = [:]
    @State private var pinchBaseScale: Double?
    @State private var showPhotoPicker = false
    @State private var showURLField = false
    @State private var backgroundURLText = ""
    @State private var solidColor = Color.blue.opacity(0.35)
    @State private var elementTextColor = Color.primary
    @State private var isSyncingControls = false
    @State private var backgroundURLTask: URLSessionDataTask?
    @State private var backgroundURLRequestID = UUID()
    @State private var backgroundApplyError: String?

    private var palette: MetricWidgetPalette { .widget() }

    private typealias L10n = AnyMetricsStrings.Addmetric.Design

    private var sizeAppearance: WidgetSizeAppearance {
        appearance.appearance(for: sizeKey)
    }

    private var selectedElement: WidgetElementSpec? {
        guard let selectedKind else { return nil }
        return sizeAppearance.element(kind: selectedKind)
    }

    private var isImageResult: Bool {
        metric.resultKind == .image
    }

    private var canUseResultImageAsBackground: Bool {
        guard isImageResult, let path = metric.resultImagePath else { return false }
        return MetricResultImageStore.shared.loadImage(relativePath: path) != nil
    }

    private var usesResultImageAsBackground: Bool {
        sizeAppearance.background.usesResultImageAsBackground && canUseResultImageAsBackground
    }

    private var selectedShowsResultImage: Bool {
        selectedKind == .value
            && isImageResult
            && metric.resultImagePath != nil
            && !usesResultImageAsBackground
    }

    private var currentBackgroundKind: BackgroundKind {
        if usesResultImageAsBackground { return .resultImage }
        switch sizeAppearance.background.fill {
        case .statusGradient: return .statusGradient
        case .system: return .system
        case .solid: return .solid
        case .image: return .image
        case .gradient: return .customGradient
        }
    }

    private var showsBackgroundImageControls: Bool {
        usesResultImageAsBackground || currentBackgroundKind == .image
    }

    var body: some View {
        Form {
            if let selectedKind, selectedElement != nil, !usesResultImageAsBackground || selectedKind != .value {
                Section {
                    if selectedShowsResultImage {
                        imageScaleControls(for: selectedKind)
                        Button(L10n.resetImageTransform) {
                            resetImageTransform(kind: selectedKind)
                        }
                        .disabled(isDefaultImageTransform(selectedElement))
                    } else {
                        alignmentControls(for: selectedKind)
                        fontScaleControls(for: selectedKind)
                        textColorControl(for: selectedKind)
                        Button(L10n.resetTextSize) {
                            updateFontScale(kind: selectedKind, WidgetElementSpec.defaultFontScale)
                        }
                        .disabled(
                            abs((selectedElement?.resolvedFontScale ?? 1) - WidgetElementSpec.defaultFontScale) < 0.01
                        )
                    }
                } header: {
                    Text(L10n.selectedFormat(label(for: selectedKind)))
                }
            }

            Section {
                ForEach(WidgetElementKind.allCases) { kind in
                    if !(kind == .value && usesResultImageAsBackground) {
                        elementRow(kind)
                    }
                }
            } header: {
                Text(L10n.elements)
            } footer: {
                Text(selectedShowsResultImage || usesResultImageAsBackground ? L10n.imageElementsFooter : L10n.elementsFooter)
            }

            Section {
                backgroundOptions
            } header: {
                Text(L10n.background)
            } footer: {
                if usesResultImageAsBackground {
                    Text(L10n.useAsBackgroundFooter)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            previewChrome
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.top, Constants.chromeTopPadding)
                .padding(.bottom, Constants.chromeBottomPadding)
                .background(
                    Constants.chromeBackground
                        .ignoresSafeArea(edges: .top)
                )
        }
        .onAppear(perform: syncControlsFromAppearance)
        .onDisappear {
            backgroundURLTask?.cancel()
            backgroundURLTask = nil
        }
        .onChange(of: sizeKey) { _ in
            dragOrigins = [:]
            imagePanOrigins = [:]
            backgroundPanOrigin = nil
            pinchBaseScale = nil
            syncControlsFromAppearance()
        }
        .onChange(of: selectedKind) { _ in
            syncControlsFromAppearance()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoLibraryPicker { image in
                guard let image else { return }
                applyBackgroundImage(image)
            }
        }
        .alert(
            AnyMetricsStrings.Common.error,
            isPresented: Binding(
                get: { backgroundApplyError != nil },
                set: { if !$0 { backgroundApplyError = nil } }
            )
        ) {
            Button(AnyMetricsStrings.Common.ok, role: .cancel) {}
        } message: {
            Text(backgroundApplyError ?? "")
        }
    }

    // MARK: - Preview (pinned)

    private var previewChrome: some View {
        VStack(spacing: Constants.previewSpacing) {
            Picker("", selection: $sizeKey) {
                Text(L10n.sizeSmall).tag(WidgetSizeKey.small)
                Text(L10n.sizeMedium).tag(WidgetSizeKey.medium)
            }
            .pickerStyle(.segmented)

            canvas
                .frame(height: sizeKey == .small ? Constants.smallCanvasHeight : Constants.mediumCanvasHeight)

            HStack(spacing: Constants.controlSpacing) {
                Label(
                    usesResultImageAsBackground || selectedShowsResultImage
                        ? L10n.imageDragHintShort
                        : L10n.dragHintShort,
                    systemImage: "hand.draw"
                )
                .font(Constants.fontCaption)
                .foregroundColor(Constants.secondaryColor)
                .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                Button(sizeKey == .small ? L10n.copyToMedium : L10n.copyToSmall) {
                    copyLayoutToOtherSize()
                }
                .font(Constants.fontAction)
                .foregroundColor(Constants.textColor)
                .buttonStyle(.bordered)
            }
        }
    }

    private var canvas: some View {
        let width: CGFloat = sizeKey == .small ? Constants.smallPreviewSize : Constants.mediumPreviewWidth
        let height: CGFloat = sizeKey == .small ? Constants.smallPreviewSize : Constants.mediumPreviewHeight
        let corner = sizeKey == .small ? Constants.metricViewCorner : Constants.mediumViewCorner

        return WidgetAppearanceRenderer(
            metric: metric,
            appearance: sizeAppearance,
            palette: palette,
            sizeKey: sizeKey,
            useGlassEffect: false,
            matchWidgetMetrics: true,
            updatedAt: metric.updated ?? Date().addingTimeInterval(-120),
            isEditing: true,
            selectedKind: selectedKind,
            onSelect: { selectedKind = $0 },
            onDrag: { kind, translation, canvas in
                if shouldPanResultImageContent(kind: kind) {
                    panResultImage(kind: kind, translation: translation, canvas: canvas)
                } else {
                    panElementFrame(kind: kind, translation: translation, canvas: canvas)
                }
            },
            onDragEnd: { kind in
                dragOrigins[kind] = nil
                imagePanOrigins[kind] = nil
            },
            onBackgroundDrag: { translation, canvas in
                panBackgroundImage(translation: translation, canvas: canvas)
            },
            onBackgroundDragEnd: {
                backgroundPanOrigin = nil
            },
            onFittedSizes: { sizes, _ in
                fittedSizes = sizes
            }
        )
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: corner)
                .fill(Constants.previewBackground)
                .padding(Constants.metricViewPadding)
        )
        .frame(maxWidth: .infinity)
        .simultaneousGesture(pinchToZoom)
    }

    private var pinchToZoom: some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                if let selectedKind, !(usesResultImageAsBackground && selectedKind == .value) {
                    if shouldZoomResultImage(kind: selectedKind) {
                        if pinchBaseScale == nil {
                            pinchBaseScale = sizeAppearance.element(kind: selectedKind)?.imageScale
                                ?? WidgetElementSpec.defaultImageScale
                        }
                        let next = (pinchBaseScale ?? WidgetElementSpec.defaultImageScale) * Double(magnification)
                        updateImageScale(kind: selectedKind, next)
                    } else {
                        if pinchBaseScale == nil {
                            pinchBaseScale = sizeAppearance.element(kind: selectedKind)?.fontScale
                                ?? WidgetElementSpec.defaultFontScale
                        }
                        let next = (pinchBaseScale ?? WidgetElementSpec.defaultFontScale) * Double(magnification)
                        updateFontScale(kind: selectedKind, next)
                    }
                    return
                }
                guard showsBackgroundImageControls else { return }
                if pinchBaseScale == nil {
                    pinchBaseScale = sizeAppearance.background.imageScale
                }
                let next = (pinchBaseScale ?? WidgetBackgroundSpec.defaultImageScale) * Double(magnification)
                updateBackgroundImageScale(next)
            }
            .onEnded { _ in
                pinchBaseScale = nil
            }
    }

    private func shouldZoomResultImage(kind: WidgetElementKind) -> Bool {
        kind == .value
            && isImageResult
            && metric.resultImagePath != nil
            && !usesResultImageAsBackground
    }

    /// Pan image content when zoomed/offset; otherwise move the value slot like text.
    private func shouldPanResultImageContent(kind: WidgetElementKind) -> Bool {
        guard shouldZoomResultImage(kind: kind),
              let element = sizeAppearance.element(kind: kind)
        else { return false }
        return abs(element.resolvedImageScale - WidgetElementSpec.defaultImageScale) > 0.02
            || abs(element.imageOffsetX) > 0.02
            || abs(element.imageOffsetY) > 0.02
    }

    private func panElementFrame(kind: WidgetElementKind, translation: CGSize, canvas: CGSize) {
        if dragOrigins[kind] == nil {
            let origin = tightenedOrigin(for: kind, canvas: canvas)
            dragOrigins[kind] = origin
            updateFrame(kind: kind, frame: origin)
        }
        guard let origin = dragOrigins[kind] else { return }
        var frame = origin
        frame.x += Double(translation.width / max(canvas.width, 1))
        frame.y += Double(translation.height / max(canvas.height, 1))
        updateFrame(kind: kind, frame: frame.clamped())
    }

    private func panResultImage(kind: WidgetElementKind, translation: CGSize, canvas: CGSize) {
        if imagePanOrigins[kind] == nil {
            let element = sizeAppearance.element(kind: kind)
            imagePanOrigins[kind] = (element?.imageOffsetX ?? 0, element?.imageOffsetY ?? 0)
        }
        guard let origin = imagePanOrigins[kind] else { return }
        let dx = Double(translation.width / max(canvas.width, 1)) * 2
        let dy = Double(translation.height / max(canvas.height, 1)) * 2
        updateImageOffset(
            kind: kind,
            x: clampOffset(origin.x + dx),
            y: clampOffset(origin.y + dy)
        )
    }

    private func panBackgroundImage(translation: CGSize, canvas: CGSize) {
        if backgroundPanOrigin == nil {
            backgroundPanOrigin = (
                sizeAppearance.background.imageOffsetX,
                sizeAppearance.background.imageOffsetY
            )
        }
        guard let origin = backgroundPanOrigin else { return }
        let dx = Double(translation.width / max(canvas.width, 1)) * 2
        let dy = Double(translation.height / max(canvas.height, 1)) * 2
        mutateSize { size in
            size.background.imageOffsetX = clampOffset(origin.x + dx)
            size.background.imageOffsetY = clampOffset(origin.y + dy)
        }
    }

    private func clampOffset(_ value: Double) -> Double {
        min(max(value, -1), 1)
    }

    /// Content-sized frame so drag clamps against the label, not the full widget width.
    private func tightenedOrigin(for kind: WidgetElementKind, canvas: CGSize) -> NormalizedRect {
        guard var frame = sizeAppearance.element(kind: kind)?.frame else { return .unit }
        let alignment = sizeAppearance.element(kind: kind)?.alignment ?? .center
        if let fitted = fittedSizes[kind] {
            frame = frame.tightened(to: fitted, canvas: canvas, alignment: alignment)
        }
        return frame.clamped()
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundOptions: some View {
        if isImageResult {
            Toggle(isOn: useAsBackgroundBinding) {
                Label(L10n.useAsBackground, systemImage: "photo.on.rectangle.angled")
                    .foregroundColor(Constants.textColor)
            }
            .tint(Color.accentColor)
            .disabled(!canUseResultImageAsBackground && !sizeAppearance.background.usesResultImageAsBackground)
        }

        if !usesResultImageAsBackground {
            if currentBackgroundKind == .customGradient {
                backgroundRow(
                    title: L10n.bgStatusGradient,
                    kind: .customGradient,
                    systemImage: "circle.lefthalf.filled"
                ) {
                    // Keep imported custom gradient; don't replace with status gradient.
                }
            } else {
                backgroundRow(
                    title: L10n.bgStatusGradient,
                    kind: .statusGradient,
                    systemImage: "circle.lefthalf.filled"
                ) {
                    setFill(.statusGradient)
                }
            }

            backgroundRow(
                title: L10n.bgSystem,
                kind: .system,
                systemImage: "square.fill"
            ) {
                setFill(.system)
            }

            HStack(spacing: Constants.controlSpacing) {
                selectionMark(currentBackgroundKind == .solid)
                Image(systemName: "paintpalette.fill")
                    .foregroundColor(Constants.secondaryColor)
                    .frame(width: Constants.iconWidth)
                ColorPicker(L10n.bgSolid, selection: $solidColor, supportsOpacity: true)
                    .onChange(of: solidColor) { newValue in
                        guard !isSyncingControls else { return }
                        setFill(.solid(.hex(newValue.hexString)))
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                setFill(.solid(.hex(solidColor.hexString)))
            }

            Button {
                showPhotoPicker = true
            } label: {
                HStack(spacing: Constants.controlSpacing) {
                    selectionMark(currentBackgroundKind == .image && !isRemoteImageBackground)
                    Image(systemName: "photo")
                        .foregroundColor(Constants.secondaryColor)
                        .frame(width: Constants.iconWidth)
                    Text(L10n.bgPhoto)
                        .font(Constants.fontRow)
                        .foregroundColor(Constants.textColor)
                    Spacer()
                }
            }

            DisclosureGroup(isExpanded: $showURLField) {
                HStack {
                    TextField(L10n.bgUrlPlaceholder, text: $backgroundURLText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                    Button(L10n.bgApplyUrl) {
                        applyBackgroundURL(backgroundURLText)
                    }
                    .disabled(backgroundURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } label: {
                HStack(spacing: Constants.controlSpacing) {
                    selectionMark(isRemoteImageBackground)
                    Image(systemName: "link")
                        .foregroundColor(Constants.secondaryColor)
                        .frame(width: Constants.iconWidth)
                    Text(L10n.bgFromUrl)
                        .font(Constants.fontRow)
                        .foregroundColor(Constants.textColor)
                }
            }
        }

        if showsBackgroundImageControls {
            Picker(L10n.imageMode, selection: imageContentModeBinding) {
                Text(L10n.imageFill).tag(WidgetImageContentMode.fill)
                Text(L10n.imageFit).tag(WidgetImageContentMode.fit)
            }
            .pickerStyle(.segmented)

            backgroundImageScaleControls
        }
    }

    private var useAsBackgroundBinding: Binding<Bool> {
        Binding(
            get: { sizeAppearance.background.usesResultImageAsBackground },
            set: { enabled in
                mutateSize { size in
                    if enabled {
                        size.applyImageResultPresentation()
                    } else {
                        size.clearImageResultPresentation()
                    }
                }
                if enabled {
                    selectedKind = selectedKind == .value ? .title : selectedKind
                } else if selectedKind == nil {
                    selectedKind = .value
                }
            }
        )
    }

    private var backgroundImageScaleControls: some View {
        let scale = sizeAppearance.background.resolvedImageScale
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.imageScale)
                    .foregroundColor(Constants.textColor)
                Spacer()
                Text("\(Int((scale * 100).rounded()))%")
                    .foregroundColor(Constants.secondaryColor)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { scale },
                    set: { updateBackgroundImageScale($0) }
                ),
                in: WidgetBackgroundSpec.minImageScale...WidgetBackgroundSpec.maxImageScale,
                step: 0.05
            )
            Button(L10n.resetImageTransform) {
                mutateSize { size in
                    size.background.imageScale = WidgetBackgroundSpec.defaultImageScale
                    size.background.imageOffsetX = 0
                    size.background.imageOffsetY = 0
                }
            }
            .disabled(
                abs(scale - WidgetBackgroundSpec.defaultImageScale) < 0.01
                    && abs(sizeAppearance.background.imageOffsetX) < 0.01
                    && abs(sizeAppearance.background.imageOffsetY) < 0.01
            )
        }
        .padding(.vertical, Constants.controlVerticalPadding)
    }

    private func backgroundRow(
        title: String,
        kind: BackgroundKind,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Constants.controlSpacing) {
                selectionMark(currentBackgroundKind == kind)
                Image(systemName: systemImage)
                    .foregroundColor(Constants.secondaryColor)
                    .frame(width: Constants.iconWidth)
                Text(title)
                    .font(Constants.fontRow)
                    .foregroundColor(Constants.textColor)
                Spacer()
            }
        }
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(selected ? Constants.textColor : Constants.secondaryColor.opacity(0.45))
            .imageScale(.medium)
    }

    private var isRemoteImageBackground: Bool {
        if case .image(.url) = sizeAppearance.background.fill { return true }
        return false
    }

    private var imageContentModeBinding: Binding<WidgetImageContentMode> {
        Binding(
            get: { sizeAppearance.background.imageContentMode },
            set: { mode in
                mutateSize { $0.background.imageContentMode = mode }
            }
        )
    }

    // MARK: - Elements

    private func elementRow(_ kind: WidgetElementKind) -> some View {
        let visible = sizeAppearance.element(kind: kind)?.isVisible ?? true
        let isSelected = selectedKind == kind

        return HStack(spacing: Constants.controlSpacing) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? Constants.textColor : Constants.secondaryColor.opacity(0.45))
                .frame(width: Constants.iconWidth)

            Text(label(for: kind))
                .font(isSelected ? Constants.fontRowSelected : Constants.fontRow)
                .foregroundColor(Constants.textColor)

            Spacer(minLength: 8)

            Toggle(
                "",
                isOn: Binding(
                    get: { visible },
                    set: { setVisible(kind: kind, $0) }
                )
            )
            .labelsHidden()
            .tint(Color.accentColor)
        }
        .contentShape(Rectangle())
        .listRowBackground(
            isSelected
                ? Constants.selectedRowBackground
                : Color(uiColor: .secondarySystemGroupedBackground)
        )
        .onTapGesture {
            selectedKind = kind
        }
    }

    private func alignmentControls(for kind: WidgetElementKind) -> some View {
        let alignment = sizeAppearance.element(kind: kind)?.alignment ?? .center
        return Picker(L10n.alignment, selection: Binding(
            get: { alignment },
            set: { setAlignment(kind: kind, $0) }
        )) {
            Image(systemName: "text.alignleft").tag(WidgetTextAlignment.leading)
            Image(systemName: "text.aligncenter").tag(WidgetTextAlignment.center)
            Image(systemName: "text.alignright").tag(WidgetTextAlignment.trailing)
        }
        .pickerStyle(.segmented)
    }

    private func fontScaleControls(for kind: WidgetElementKind) -> some View {
        let scale = sizeAppearance.element(kind: kind)?.resolvedFontScale ?? WidgetElementSpec.defaultFontScale
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.fontScale)
                    .foregroundColor(Constants.textColor)
                Spacer()
                Text("\(Int((scale * 100).rounded()))%")
                    .foregroundColor(Constants.secondaryColor)
                    .monospacedDigit()
            }
            HStack(spacing: Constants.controlSpacing) {
                Button {
                    updateFontScale(kind: kind, scale - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(scale <= WidgetElementSpec.minFontScale)

                Slider(
                    value: Binding(
                        get: { scale },
                        set: { updateFontScale(kind: kind, $0) }
                    ),
                    in: WidgetElementSpec.minFontScale...WidgetElementSpec.maxFontScale,
                    step: 0.05
                )

                Button {
                    updateFontScale(kind: kind, scale + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(scale >= WidgetElementSpec.maxFontScale)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Constants.controlVerticalPadding)
    }

    private func textColorControl(for kind: WidgetElementKind) -> some View {
        ColorPicker(
            L10n.textColor,
            selection: Binding(
                get: { elementTextColor },
                set: { newValue in
                    elementTextColor = newValue
                    guard !isSyncingControls else { return }
                    setElementColor(kind: kind, .hex(newValue.hexString))
                }
            ),
            supportsOpacity: true
        )
    }

    private func imageScaleControls(for kind: WidgetElementKind) -> some View {
        let scale = sizeAppearance.element(kind: kind)?.resolvedImageScale ?? WidgetElementSpec.defaultImageScale
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.imageScale)
                    .foregroundColor(Constants.textColor)
                Spacer()
                Text("\(Int((scale * 100).rounded()))%")
                    .foregroundColor(Constants.secondaryColor)
                    .monospacedDigit()
            }
            HStack(spacing: Constants.controlSpacing) {
                Button {
                    updateImageScale(kind: kind, scale - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(scale <= WidgetElementSpec.minImageScale)

                Slider(
                    value: Binding(
                        get: { scale },
                        set: { updateImageScale(kind: kind, $0) }
                    ),
                    in: WidgetElementSpec.minImageScale...WidgetElementSpec.maxImageScale,
                    step: 0.05
                )

                Button {
                    updateImageScale(kind: kind, scale + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(scale >= WidgetElementSpec.maxImageScale)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Constants.controlVerticalPadding)
    }

    // MARK: - Mutations

    private func label(for kind: WidgetElementKind) -> String {
        switch kind {
        case .title: return L10n.elementTitle
        case .value: return L10n.elementValue
        case .measure: return L10n.elementMeasure
        case .updated: return L10n.elementUpdated
        }
    }

    private func syncControlsFromAppearance() {
        isSyncingControls = true
        if case .solid(let colorSpec) = sizeAppearance.background.fill,
           let color = Color(widgetColorSpec: colorSpec) {
            solidColor = color
        }
        if case .image(.url(let url)) = sizeAppearance.background.fill {
            backgroundURLText = url
            showURLField = true
            // Legacy persisted URL fills: materialize to App Group file.
            applyBackgroundURL(url)
        }
        if let selectedKind,
           let spec = sizeAppearance.element(kind: selectedKind)?.color {
            elementTextColor = Color(widgetColorSpec: spec) ?? palette.textColor
        }
        DispatchQueue.main.async {
            isSyncingControls = false
        }
    }

    private func mutateSize(_ update: (inout WidgetSizeAppearance) -> Void) {
        var copy = appearance
        var size = copy.appearance(for: sizeKey)
        update(&size)
        copy.setAppearance(size, for: sizeKey)
        appearance = copy
    }

    private func updateFrame(kind: WidgetElementKind, frame: NormalizedRect) {
        mutateSize { size in
            size.updateElement(kind: kind) { $0.frame = frame }
        }
    }

    private func updateFontScale(kind: WidgetElementKind, _ scale: Double) {
        let clamped = min(max(scale, WidgetElementSpec.minFontScale), WidgetElementSpec.maxFontScale)
        mutateSize { size in
            size.updateElement(kind: kind) { $0.fontScale = clamped }
        }
    }

    private func updateImageScale(kind: WidgetElementKind, _ scale: Double) {
        let clamped = min(max(scale, WidgetElementSpec.minImageScale), WidgetElementSpec.maxImageScale)
        mutateSize { size in
            size.updateElement(kind: kind) { $0.imageScale = clamped }
        }
    }

    private func updateImageOffset(kind: WidgetElementKind, x: Double, y: Double) {
        mutateSize { size in
            size.updateElement(kind: kind) {
                $0.imageOffsetX = x
                $0.imageOffsetY = y
            }
        }
    }

    private func updateBackgroundImageScale(_ scale: Double) {
        let clamped = min(max(scale, WidgetBackgroundSpec.minImageScale), WidgetBackgroundSpec.maxImageScale)
        mutateSize { size in
            size.background.imageScale = clamped
        }
    }

    private func resetImageTransform(kind: WidgetElementKind) {
        mutateSize { size in
            size.updateElement(kind: kind) {
                $0.imageScale = WidgetElementSpec.defaultImageScale
                $0.imageOffsetX = 0
                $0.imageOffsetY = 0
            }
        }
    }

    private func isDefaultImageTransform(_ element: WidgetElementSpec?) -> Bool {
        guard let element else { return true }
        return abs(element.resolvedImageScale - WidgetElementSpec.defaultImageScale) < 0.01
            && abs(element.imageOffsetX) < 0.01
            && abs(element.imageOffsetY) < 0.01
    }

    private func setVisible(kind: WidgetElementKind, _ visible: Bool) {
        mutateSize { size in
            size.updateElement(kind: kind) { $0.isVisible = visible }
        }
    }

    private func setAlignment(kind: WidgetElementKind, _ alignment: WidgetTextAlignment) {
        mutateSize { size in
            size.updateElement(kind: kind) { $0.alignment = alignment }
        }
    }

    private func setElementColor(kind: WidgetElementKind, _ color: WidgetColorSpec) {
        mutateSize { size in
            size.updateElement(kind: kind) { $0.color = color }
        }
    }

    private func setFill(_ fill: WidgetBackgroundFill) {
        mutateSize { size in
            size.background.usesResultImageAsBackground = false
            size.background.fill = fill
            if case .system = fill {
                size.background.shape = .rectangle
                size.background.usesGlassEffect = false
            }
        }
    }

    private func copyLayoutToOtherSize() {
        var copy = appearance
        var source = copy.appearance(for: sizeKey)
        let targetKey: WidgetSizeKey = sizeKey == .small ? .medium : .small
        if case .image(.file(let path)) = source.background.fill {
            if let image = WidgetBackgroundStore.shared.loadImage(relativePath: path),
               let newPath = try? WidgetBackgroundStore.shared.saveImage(image, metricId: metricId, size: targetKey) {
                source.background.fill = .image(.file(newPath))
            } else {
                // Avoid sharing one file across sizes when copy fails.
                source.background.fill = .system
                backgroundApplyError = L10n.importStyleError
            }
        }
        copy.setAppearance(source, for: targetKey)
        appearance = copy
    }

    private func applyBackgroundImage(_ image: UIImage) {
        guard let path = try? WidgetBackgroundStore.shared.saveImage(image, metricId: metricId, size: sizeKey) else {
            backgroundApplyError = L10n.importStyleError
            return
        }
        mutateSize { size in
            size.background.usesResultImageAsBackground = false
            size.background.fill = .image(.file(path))
            size.background.imageContentMode = .fill
            size.background.imageScale = WidgetBackgroundSpec.defaultImageScale
            size.background.imageOffsetX = 0
            size.background.imageOffsetY = 0
        }
    }

    private func applyBackgroundURL(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            backgroundApplyError = L10n.importStyleError
            return
        }
        backgroundURLTask?.cancel()
        let requestID = UUID()
        backgroundURLRequestID = requestID
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    guard backgroundURLRequestID == requestID else { return }
                    backgroundApplyError = L10n.importStyleError
                }
                return
            }
            DispatchQueue.main.async {
                guard backgroundURLRequestID == requestID else { return }
                applyBackgroundImage(image)
            }
        }
        backgroundURLTask = task
        task.resume()
    }

    private enum BackgroundKind {
        case statusGradient
        case customGradient
        case system
        case solid
        case image
        case resultImage
    }
}

// MARK: - Photo picker

private struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void

        init(onPick: @escaping (UIImage?) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self)
            else {
                onPick(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    self.onPick(object as? UIImage)
                }
            }
        }
    }
}

private extension Color {
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return String(
                format: "%02X%02X%02X%02X",
                Int(round(a * 255)),
                Int(round(r * 255)),
                Int(round(g * 255)),
                Int(round(b * 255))
            )
        }
        guard let srgb = ui.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ), let components = srgb.components, components.count >= 3 else {
            return "FF000000"
        }
        let rr = components[0]
        let gg = components[1]
        let bb = components[2]
        let aa = components.count > 3 ? components[3] : 1
        return String(
            format: "%02X%02X%02X%02X",
            Int(round(aa * 255)),
            Int(round(rr * 255)),
            Int(round(gg * 255)),
            Int(round(bb * 255))
        )
    }

    init?(widgetColorSpec: WidgetColorSpec) {
        switch widgetColorSpec {
        case .hex(let hex):
            self.init(hex: hex)
        case .adaptiveHex(let light, _):
            self.init(hex: light)
        case .adaptive:
            return nil
        }
    }

    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16)
        else { return nil }

        let hasAlpha = cleaned.count == 8
        let a = hasAlpha ? Double((value & 0xFF000000) >> 24) / 255 : 1
        let r = Double((value & 0x00FF0000) >> 16) / 255
        let g = Double((value & 0x0000FF00) >> 8) / 255
        let b = Double(value & 0x000000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
