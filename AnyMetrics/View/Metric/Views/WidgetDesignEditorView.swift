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
        static let fontRow = Font.system(size: 17, weight: .regular, design: .default)
        static let fontTab = Font.system(size: 15, weight: .regular, design: .default)
        static let fontSubtab = Font.system(size: 11, weight: .regular, design: .default)
        static let sizeIconSize: CGFloat = 14
        static let tabTrack = Color(uiColor: .tertiarySystemFill)
        static let switchTint = Color(uiColor: .systemGreen)
        static let historyLimit = 30
    }

    private enum EditorTab: Hashable {
        case text
        case background
    }

    @Binding var appearance: WidgetAppearance
    let metric: Metric
    let metricId: UUID

    @State private var sizeKey: WidgetSizeKey = .small
    @State private var editorTab: EditorTab = .text
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
    @State private var gradientStops = [
        Color(red: 0.11, green: 0.11, blue: 0.12),
        Color(red: 0.23, green: 0.23, blue: 0.24),
        Color(red: 0.56, green: 0.56, blue: 0.58)
    ]
    @State private var elementTextColor = Color.primary
    @State private var isSyncingControls = false
    @State private var backgroundURLTask: URLSessionDataTask?
    @State private var backgroundURLRequestID = UUID()
    @State private var backgroundApplyError: String?
    @State private var showLayoutSettings = false
    @State private var syncSizes = true
    /// Source image path already copied onto a size, so live sync does not write a new file each frame.
    @State private var copiedImageSourcePath: [WidgetSizeKey: String] = [:]
    @State private var undoStack: [WidgetSizeKey: SizeHistory] = [:]
    /// Appearance before the current drag, pinch, slider, or color gesture.
    @State private var editBaseline: WidgetAppearance?
    @State private var editBaselineSynced = false
    @State private var openEditIDs: Set<String> = []
    @State private var colorCommit: DispatchWorkItem?

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

    private var textElementKinds: [WidgetElementKind] {
        WidgetElementKind.allCases.filter { !($0 == .value && usesResultImageAsBackground) }
    }

    var body: some View {
        Form {
            switch editorTab {
            case .text:
                if let selectedKind, textElementKinds.contains(selectedKind), selectedElement != nil {
                    Section {
                        visibilityToggle(for: selectedKind)
                        if selectedElement?.isVisible != false {
                            if selectedShowsResultImage {
                                imageScaleControls(for: selectedKind)
                                Button(L10n.resetImageTransform) {
                                    resetImageTransform(kind: selectedKind)
                                }
                                .foregroundColor(Constants.textColor)
                                .disabled(isDefaultImageTransform(selectedElement))
                            } else {
                                alignmentControls(for: selectedKind)
                                fontControls(for: selectedKind)
                                fontScaleControls(for: selectedKind)
                                textColorControl(for: selectedKind)
                                Button(L10n.resetTextSize) {
                                    updateFontScale(kind: selectedKind, WidgetElementSpec.defaultFontScale)
                                }
                                .foregroundColor(Constants.textColor)
                                .disabled(
                                    abs((selectedElement?.resolvedFontScale ?? 1) - WidgetElementSpec.defaultFontScale) < 0.01
                                )
                            }
                        }
                    } footer: {
                        Text(selectedShowsResultImage ? L10n.imageElementsFooter : L10n.elementsFooter)
                            .foregroundColor(Constants.secondaryColor)
                    }
                    .animation(.easeInOut(duration: 0.25), value: selectedElement?.isVisible)
                }
            case .background:
                Section {
                    backgroundOptions
                } footer: {
                    if usesResultImageAsBackground {
                        Text(L10n.useAsBackgroundFooter)
                            .foregroundColor(Constants.secondaryColor)
                    }
                }
            }
        }
        .tint(Constants.textColor)
        .foregroundColor(Constants.textColor)
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
        .onAppear {
            ensureTextSelection()
            syncControlsFromAppearance()
        }
        .onDisappear {
            backgroundURLTask?.cancel()
            backgroundURLTask = nil
            colorCommit?.cancel()
            colorCommit = nil
        }
        .onChange(of: sizeKey) { _ in
            commitBaseline()
            dragOrigins = [:]
            imagePanOrigins = [:]
            backgroundPanOrigin = nil
            pinchBaseScale = nil
            ensureTextSelection()
            syncControlsFromAppearance()
        }
        .onChange(of: editorTab) { tab in
            if tab == .text {
                ensureTextSelection()
            }
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
        .sheet(isPresented: $showLayoutSettings) {
            layoutSettingsSheet
                .presentationDetents([.medium])
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
            HStack(alignment: .center, spacing: 8) {
                layoutSettingsButton
                Spacer(minLength: 8)
                historyControls
                sizeToggle
            }

            VStack(spacing: 4) {
                canvas
                    .frame(height: max(Constants.smallCanvasHeight, Constants.mediumCanvasHeight))

                Text(
                    usesResultImageAsBackground || selectedShowsResultImage
                        ? L10n.imageDragHintShort
                        : L10n.dragHintShort
                )
                .font(Constants.fontCaption)
                .foregroundColor(Constants.secondaryColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }

            editorTabs

            if editorTab == .text {
                textSubtabs
            }
        }
    }

    private var historyControls: some View {
        HStack(spacing: 2) {
            historyButton(
                systemImage: "arrow.uturn.backward",
                enabled: canUndo,
                label: L10n.undo,
                action: undoAppearance
            )
            historyButton(
                systemImage: "arrow.uturn.forward",
                enabled: canRedo,
                label: L10n.redo,
                action: redoAppearance
            )
        }
        .padding(2)
        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
    }

    private func historyButton(
        systemImage: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: Constants.sizeIconSize, weight: .medium))
                .frame(width: 30, height: 26)
                .foregroundColor(Constants.textColor)
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }

    private var layoutSettingsButton: some View {
        Button {
            showLayoutSettings = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: Constants.sizeIconSize, weight: .medium))
                .frame(width: 30, height: 26)
                .foregroundColor(Constants.textColor)
                .background(
                    Capsule().fill(showLayoutSettings ? Constants.selectedRowBackground : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .padding(2)
        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
        .accessibilityLabel(Text(L10n.layoutSettings))
    }

    private var layoutSettingsSheet: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(L10n.round, isOn: roundSmallBinding)
                        .tint(Constants.switchTint)
                } footer: {
                    Text(L10n.roundFooter)
                        .foregroundColor(Constants.secondaryColor)
                }

                Section {
                    Toggle(L10n.syncSizes, isOn: syncSizesBinding)
                        .tint(Constants.switchTint)
                    if !syncSizes {
                        Button(L10n.copyToSmall) {
                            copyLayout(to: .small)
                        }
                        .foregroundColor(Constants.textColor)
                        Button(L10n.copyToMedium) {
                            copyLayout(to: .medium)
                        }
                        .foregroundColor(Constants.textColor)
                    }
                } footer: {
                    if syncSizes {
                        Text(L10n.syncSizesFooter)
                            .foregroundColor(Constants.secondaryColor)
                    }
                }
            }
            .navigationTitle(L10n.layoutSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AnyMetricsStrings.Common.close) {
                        showLayoutSettings = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var sizeToggle: some View {
        HStack(spacing: 2) {
            sizeButton(.small, systemImage: "widget.small", label: L10n.sizeSmall)
            sizeButton(.medium, systemImage: "widget.medium", label: L10n.sizeMedium)
        }
        .padding(2)
        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
    }

    private func sizeButton(_ key: WidgetSizeKey, systemImage: String, label: String) -> some View {
        let selected = sizeKey == key
        return Button {
            sizeKey = key
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: Constants.sizeIconSize, weight: .medium))
                .frame(width: 30, height: 26)
                .foregroundColor(Constants.textColor)
                .background(Capsule().fill(selected ? Constants.selectedRowBackground : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var editorTabs: some View {
        HStack(spacing: 4) {
            textTab(title: L10n.elements, isSelected: editorTab == .text, labelFont: Constants.fontTab, verticalPadding: 10) {
                editorTab = .text
            }
            textTab(title: L10n.background, isSelected: editorTab == .background, labelFont: Constants.fontTab, verticalPadding: 10) {
                editorTab = .background
            }
        }
        .padding(4)
        .background(Capsule().fill(Constants.tabTrack))
    }

    private var textSubtabs: some View {
        HStack(spacing: 2) {
            ForEach(textElementKinds) { kind in
                textTab(
                    title: label(for: kind),
                    isSelected: selectedKind == kind,
                    labelFont: Constants.fontSubtab,
                    verticalPadding: 6
                ) {
                    selectedKind = kind
                }
            }
        }
        .padding(2)
        .background(Capsule().fill(Constants.tabTrack))
    }

    private func textTab(
        title: String,
        isSelected: Bool,
        labelFont: Font,
        verticalPadding: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(labelFont)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(Constants.textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, 8)
                .background(Capsule().fill(isSelected ? Constants.textColor.opacity(0.16) : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            selectedKind: editorTab == .text ? selectedKind : nil,
            onSelect: { kind in
                selectedKind = kind
                editorTab = .text
            },
            onDrag: { kind, translation, canvas in
                beginEdit("drag")
                if shouldPanResultImageContent(kind: kind) {
                    panResultImage(kind: kind, translation: translation, canvas: canvas)
                } else {
                    panElementFrame(kind: kind, translation: translation, canvas: canvas)
                }
            },
            onDragEnd: { kind in
                dragOrigins[kind] = nil
                imagePanOrigins[kind] = nil
                endEdit("drag")
            },
            onBackgroundDrag: { translation, canvas in
                beginEdit("background-drag")
                panBackgroundImage(translation: translation, canvas: canvas)
            },
            onBackgroundDragEnd: {
                backgroundPanOrigin = nil
                endEdit("background-drag")
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
                beginEdit("pinch")
                if editorTab == .text,
                   let selectedKind,
                   !(usesResultImageAsBackground && selectedKind == .value) {
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
                endEdit("pinch")
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
            }
            .tint(Constants.switchTint)
            .disabled(!canUseResultImageAsBackground && !sizeAppearance.background.usesResultImageAsBackground)
        }

        if !usesResultImageAsBackground {
            backgroundRow(
                title: L10n.bgStatusGradient,
                systemImage: "circle.lefthalf.filled",
                isSelected: currentBackgroundKind == .statusGradient
            ) {
                setFill(.statusGradient)
            }

            backgroundRow(
                title: L10n.bgGradients,
                systemImage: "circle.grid.2x2.fill",
                isSelected: showsPresetGradients
            ) {
                selectPresetGradients()
            }

            if showsPresetGradients {
                gradientPresetRows
                    .padding(.vertical, Constants.controlVerticalPadding)
            }

            backgroundRow(
                title: L10n.bgCustomGradient,
                systemImage: "slider.horizontal.3",
                isSelected: isCustomGradient
            ) {
                beginCustomGradient()
            }

            if isCustomGradient {
                ForEach(0..<3, id: \.self) { index in
                    ColorPicker(
                        L10n.bgGradientStop(index + 1),
                        selection: gradientStopBinding(index),
                        supportsOpacity: true
                    )
                }
            }

            backgroundRow(
                title: L10n.bgSystem,
                systemImage: "square.fill",
                isSelected: currentBackgroundKind == .system
            ) {
                setFill(.system)
            }

            HStack(spacing: Constants.controlSpacing) {
                selectionMark(currentBackgroundKind == .solid)
                Image(systemName: "paintpalette.fill")
                    .foregroundColor(Constants.textColor)
                    .frame(width: Constants.iconWidth)
                ColorPicker(L10n.bgSolid, selection: $solidColor, supportsOpacity: true)
                    .onChange(of: solidColor) { newValue in
                        guard !isSyncingControls else { return }
                        noteColorEdit()
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
                        .foregroundColor(Constants.textColor)
                        .frame(width: Constants.iconWidth)
                    Text(L10n.bgPhoto)
                        .font(Constants.fontRow)
                        .foregroundColor(Constants.textColor)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            DisclosureGroup(isExpanded: $showURLField) {
                HStack {
                    TextField(L10n.bgUrlPlaceholder, text: $backgroundURLText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                    Button(L10n.bgApplyUrl) {
                        applyBackgroundURL(backgroundURLText)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(Constants.textColor)
                    .disabled(backgroundURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } label: {
                HStack(spacing: Constants.controlSpacing) {
                    selectionMark(isRemoteImageBackground)
                    Image(systemName: "link")
                        .foregroundColor(Constants.textColor)
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
            .tint(Constants.textColor)

            backgroundImageScaleControls
        }
    }

    private var roundSmallBinding: Binding<Bool> {
        Binding(
            get: { appearance.isRoundSmallWidget },
            set: { isRound in
                var copy = appearance
                copy.setRoundSmallWidget(isRound)
                storeAppearance(copy)
                sizeKey = .small
            }
        )
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
                step: 0.05,
                onEditingChanged: sliderEditingChanged
            )
            .tint(Constants.textColor)
            Button(L10n.resetImageTransform) {
                mutateSize { size in
                    size.background.imageScale = WidgetBackgroundSpec.defaultImageScale
                    size.background.imageOffsetX = 0
                    size.background.imageOffsetY = 0
                }
            }
            .foregroundColor(Constants.textColor)
            .disabled(
                abs(scale - WidgetBackgroundSpec.defaultImageScale) < 0.01
                    && abs(sizeAppearance.background.imageOffsetX) < 0.01
                    && abs(sizeAppearance.background.imageOffsetY) < 0.01
            )
        }
        .padding(.vertical, Constants.controlVerticalPadding)
    }

    private var showsPresetGradients: Bool {
        currentGradientSpec != nil && StarterMetric.QuoteStyle.allCases.contains(where: matchesPreset)
    }

    private var gradientPresetRows: some View {
        let styles = Array(StarterMetric.QuoteStyle.allCases)
        let rowSize = 5
        let rowCount = (styles.count + rowSize - 1) / rowSize
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(styles.dropFirst(row * rowSize).prefix(rowSize)) { style in
                        gradientPresetButton(style)
                    }
                }
            }
        }
    }

    private func gradientPresetButton(_ style: StarterMetric.QuoteStyle) -> some View {
        let selected = matchesPreset(style)
        return Button {
            applyPreset(style)
        } label: {
            WidgetGradientFill(
                colors: style.colors.compactMap { Color(hex: $0) },
                mesh: style.mesh
            )
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .padding(3)
            .overlay {
                Circle()
                    .strokeBorder(selected ? Constants.textColor : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(style.localizedName))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var currentGradientSpec: WidgetGradientSpec? {
        if case .gradient(let spec) = sizeAppearance.background.fill { return spec }
        return nil
    }

    private var isCustomGradient: Bool {
        currentGradientSpec != nil && !StarterMetric.QuoteStyle.allCases.contains(where: matchesPreset)
    }

    private func matchesPreset(_ style: StarterMetric.QuoteStyle) -> Bool {
        guard let spec = currentGradientSpec,
              spec.mesh == style.mesh,
              spec.colors.count == style.colors.count
        else { return false }
        return zip(spec.colors, style.colors).allSatisfy { pair in
            normalizeHex(pair.0) == normalizeHex(pair.1)
        }
    }

    private func applyPreset(_ style: StarterMetric.QuoteStyle) {
        let colors = style.colors.compactMap { Color(hex: $0) }
        if colors.count == 3 {
            gradientStops = colors
        }
        setFill(.gradient(WidgetGradientSpec(
            colors: style.colors.map { .hex($0) },
            startX: 1,
            startY: 0,
            endX: 0,
            endY: 1,
            mesh: style.mesh
        )))
        guard style.usesDarkText else { return }
        mutateSize { size in
            for kind in WidgetElementKind.allCases {
                size.updateElement(kind: kind) { element in
                    switch kind {
                    case .title, .value:
                        element.color = .hex("#1C1917")
                    case .measure, .updated:
                        element.color = .hex("#B31C1917")
                    }
                }
            }
        }
    }

    private func selectPresetGradients() {
        guard !showsPresetGradients else { return }
        guard let style = StarterMetric.QuoteStyle.allCases.first else { return }
        applyPreset(style)
    }

    private func beginCustomGradient() {
        guard !isCustomGradient else { return }
        let colors = ["#1C1C1E", "#3A3A3C", "#8E8E93"]
        gradientStops = colors.compactMap { Color(hex: $0) }
        setFill(.gradient(WidgetGradientSpec(
            colors: colors.map { .hex($0) },
            startX: 1,
            startY: 0,
            endX: 0,
            endY: 1
        )))
    }

    private func gradientStopBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: { gradientStops[index] },
            set: { newColor in
                guard gradientStops.indices.contains(index) else { return }
                gradientStops[index] = newColor
                guard !isSyncingControls else { return }
                noteColorEdit()
                var spec = currentGradientSpec ?? WidgetGradientSpec(
                    colors: [],
                    startX: 1,
                    startY: 0,
                    endX: 0,
                    endY: 1
                )
                spec.colors = gradientStops.map { .hex($0.hexString) }
                setFill(.gradient(spec))
            }
        )
    }

    private func normalizeHex(_ spec: WidgetColorSpec) -> String {
        switch spec {
        case .hex(let hex):
            return normalizeHex(hex)
        case .adaptiveHex(let light, _):
            return normalizeHex(light)
        case .adaptive:
            return ""
        }
    }

    private func normalizeHex(_ hex: String) -> String {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        if cleaned.count == 6 { cleaned = "FF" + cleaned }
        return cleaned
    }

    private func backgroundRow(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Constants.controlSpacing) {
                selectionMark(isSelected)
                Image(systemName: systemImage)
                    .foregroundColor(Constants.textColor)
                    .frame(width: Constants.iconWidth)
                Text(title)
                    .font(Constants.fontRow)
                    .foregroundColor(Constants.textColor)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func selectionMark(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(Constants.textColor)
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

    private func visibilityToggle(for kind: WidgetElementKind) -> some View {
        let visible = sizeAppearance.element(kind: kind)?.isVisible ?? true
        return Toggle(
            L10n.showBlock,
            isOn: Binding(
                get: { visible },
                set: { setVisible(kind: kind, $0) }
            )
        )
        .tint(Constants.switchTint)
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
        .tint(Constants.textColor)
    }

    private func fontControls(for kind: WidgetElementKind) -> some View {
        Picker(L10n.font, selection: Binding(
            get: { selectedFontDesign(for: kind) },
            set: { setFontDesign(kind: kind, $0) }
        )) {
            fontOption(L10n.fontSystem, design: .system)
            fontOption(L10n.fontRounded, design: .rounded)
            fontOption(L10n.fontSerif, design: .serif)
            fontOption(L10n.fontMonospaced, design: .monospaced)
        }
        .pickerStyle(.menu)
        .tint(Constants.textColor)
    }

    private func fontOption(_ title: String, design: WidgetFontDesign) -> some View {
        Text(title)
            .font(.system(.body, design: fontFace(design)))
            .tag(design)
    }

    private func fontFace(_ design: WidgetFontDesign) -> Font.Design {
        switch design {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }

    /// Matches the renderer when the element has no saved face yet.
    private func selectedFontDesign(for kind: WidgetElementKind) -> WidgetFontDesign {
        if let stored = sizeAppearance.element(kind: kind)?.fontDesign {
            return stored
        }
        guard kind == .value else { return .system }
        let isStatus = metric.type == .checkStatus || ((metric.rules?.type ?? .none) != .none)
        if isStatus { return .rounded }
        return metric.result.count >= 15 ? .system : .monospaced
    }

    private func fontScaleControls(for kind: WidgetElementKind) -> some View {
        let scale = sizeAppearance.element(kind: kind)?.resolvedFontScale ?? WidgetElementSpec.defaultFontScale
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.fontScale)
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
                    step: 0.05,
                    onEditingChanged: sliderEditingChanged
                )
                .tint(Constants.textColor)

                Button {
                    updateFontScale(kind: kind, scale + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(scale >= WidgetElementSpec.maxFontScale)
            }
            .buttonStyle(.borderless)
            .foregroundColor(Constants.textColor)
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
                    noteColorEdit()
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
                    step: 0.05,
                    onEditingChanged: sliderEditingChanged
                )
                .tint(Constants.textColor)

                Button {
                    updateImageScale(kind: kind, scale + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(scale >= WidgetElementSpec.maxImageScale)
            }
            .buttonStyle(.borderless)
            .foregroundColor(Constants.textColor)
        }
        .padding(.vertical, Constants.controlVerticalPadding)
    }

    // MARK: - Mutations

    private func ensureTextSelection() {
        if let selectedKind, textElementKinds.contains(selectedKind) { return }
        selectedKind = textElementKinds.first ?? .title
    }

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
        if case .gradient(let spec) = sizeAppearance.background.fill {
            let parsed = spec.colors.compactMap { Color(widgetColorSpec: $0) }
            if !parsed.isEmpty {
                var colors = parsed
                while colors.count < 3 { colors.append(colors.last ?? .white) }
                gradientStops = Array(colors.prefix(3))
            }
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

    // MARK: - History

    private func sliderEditingChanged(_ editing: Bool) {
        if editing {
            beginEdit("slider")
        } else {
            endEdit("slider")
        }
    }

    private func beginEdit(_ id: String) {
        if editBaseline == nil {
            editBaseline = appearance
            editBaselineSynced = syncSizes
        }
        openEditIDs.insert(id)
    }

    private func endEdit(_ id: String) {
        openEditIDs.remove(id)
        guard openEditIDs.isEmpty else { return }
        commitBaseline()
    }

    private func noteColorEdit() {
        beginEdit("color")
        colorCommit?.cancel()
        let work = DispatchWorkItem { endEdit("color") }
        colorCommit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func commitBaseline() {
        colorCommit?.cancel()
        colorCommit = nil
        guard let baseline = editBaseline else { return }
        editBaseline = nil
        openEditIDs.removeAll()
        guard baseline != appearance else { return }
        recordUndo(before: baseline)
    }

    private var canUndo: Bool {
        if hasPendingEdit { return true }
        if syncSizes {
            return WidgetSizeKey.allCases.contains { !(undoStack[$0]?.undo.isEmpty ?? true) }
        }
        return !(undoStack[sizeKey]?.undo.isEmpty ?? true)
    }

    private var canRedo: Bool {
        guard editBaseline == nil else { return false }
        if syncSizes {
            return WidgetSizeKey.allCases.contains { !(undoStack[$0]?.redo.isEmpty ?? true) }
        }
        return !(undoStack[sizeKey]?.redo.isEmpty ?? true)
    }

    private var hasPendingEdit: Bool {
        guard let baseline = editBaseline else { return false }
        if editBaselineSynced || syncSizes {
            return baseline != appearance
        }
        return baseline.appearance(for: sizeKey) != appearance.appearance(for: sizeKey)
    }

    private func recordUndo(before baseline: WidgetAppearance) {
        let keys = WidgetSizeKey.allCases.filter {
            baseline.appearance(for: $0) != appearance.appearance(for: $0)
        }
        guard !keys.isEmpty else { return }
        let group = (undoStack.values.flatMap(\.undo).map(\.group).max() ?? 0) + 1
        for key in keys {
            pushUndo(baseline.appearance(for: key), for: key, group: group)
        }
    }

    private func pushUndo(_ snapshot: WidgetSizeAppearance, for key: WidgetSizeKey, group: Int) {
        var bucket = undoStack[key] ?? SizeHistory()
        bucket.undo.append(SizeHistory.Entry(value: snapshot, group: group))
        if bucket.undo.count > Constants.historyLimit {
            bucket.undo.removeFirst(bucket.undo.count - Constants.historyLimit)
        }
        bucket.redo.removeAll()
        undoStack[key] = bucket
    }

    private func storeAppearance(_ copy: WidgetAppearance) {
        guard copy != appearance else { return }
        if editBaseline != nil {
            appearance = copy
            return
        }
        let before = appearance
        appearance = copy
        recordUndo(before: before)
    }

    private func undoAppearance() {
        commitBaseline()
        if syncSizes {
            restoreGroupedStep(fromUndo: true)
        } else {
            restoreStep(for: sizeKey, fromUndo: true)
        }
    }

    private func redoAppearance() {
        let hadOpenEdit = editBaseline != nil
        commitBaseline()
        if hadOpenEdit { return }
        if syncSizes {
            restoreGroupedStep(fromUndo: false)
        } else {
            restoreStep(for: sizeKey, fromUndo: false)
        }
    }

    private func restoreStep(for key: WidgetSizeKey, fromUndo: Bool) {
        var bucket = undoStack[key] ?? SizeHistory()
        let entry: SizeHistory.Entry?
        if fromUndo {
            entry = bucket.undo.popLast()
        } else {
            entry = bucket.redo.popLast()
        }
        guard let entry else { return }
        let current = appearance.appearance(for: key)
        if fromUndo {
            bucket.redo.append(SizeHistory.Entry(value: current, group: entry.group))
        } else {
            bucket.undo.append(SizeHistory.Entry(value: current, group: entry.group))
        }
        trim(&bucket)
        undoStack[key] = bucket
        var copy = appearance
        copy.setAppearance(entry.value, for: key)
        appearance = copy
        syncControlsFromAppearance()
    }

    private func restoreGroupedStep(fromUndo: Bool) {
        let group = WidgetSizeKey.allCases.compactMap { key -> Int? in
            let bucket = undoStack[key]
            return fromUndo ? bucket?.undo.last?.group : bucket?.redo.last?.group
        }.max()
        guard let group else { return }
        var copy = appearance
        for key in WidgetSizeKey.allCases {
            var bucket = undoStack[key] ?? SizeHistory()
            let top = fromUndo ? bucket.undo.last : bucket.redo.last
            guard top?.group == group else { continue }
            let entry = fromUndo ? bucket.undo.removeLast() : bucket.redo.removeLast()
            let current = copy.appearance(for: key)
            if fromUndo {
                bucket.redo.append(SizeHistory.Entry(value: current, group: entry.group))
            } else {
                bucket.undo.append(SizeHistory.Entry(value: current, group: entry.group))
            }
            trim(&bucket)
            undoStack[key] = bucket
            copy.setAppearance(entry.value, for: key)
        }
        appearance = copy
        syncControlsFromAppearance()
    }

    private func trim(_ bucket: inout SizeHistory) {
        if bucket.undo.count > Constants.historyLimit {
            bucket.undo.removeFirst(bucket.undo.count - Constants.historyLimit)
        }
        if bucket.redo.count > Constants.historyLimit {
            bucket.redo.removeFirst(bucket.redo.count - Constants.historyLimit)
        }
    }

    private struct SizeHistory {
        struct Entry {
            var value: WidgetSizeAppearance
            var group: Int
        }

        var undo: [Entry] = []
        var redo: [Entry] = []
    }

    private func mutateSize(_ update: (inout WidgetSizeAppearance) -> Void) {
        var copy = appearance
        var size = copy.appearance(for: sizeKey)
        update(&size)
        copy.setAppearance(size, for: sizeKey)
        if syncSizes {
            let target: WidgetSizeKey = sizeKey == .small ? .medium : .small
            copy = copiedAppearance(from: sizeKey, to: target, in: copy, reportError: false)
        }
        storeAppearance(copy)
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
        withAnimation(.easeInOut(duration: 0.25)) {
            mutateSize { size in
                size.updateElement(kind: kind) { $0.isVisible = visible }
            }
        }
    }

    private func setAlignment(kind: WidgetElementKind, _ alignment: WidgetTextAlignment) {
        mutateSize { size in
            size.updateElement(kind: kind) { $0.alignment = alignment }
        }
    }

    private func setFontDesign(kind: WidgetElementKind, _ design: WidgetFontDesign) {
        mutateSize { size in
            size.updateElement(kind: kind) { $0.fontDesign = design }
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
                size.background.usesGlassEffect = false
            }
        }
    }

    private var syncSizesBinding: Binding<Bool> {
        Binding(
            get: { syncSizes },
            set: { enabled in
                syncSizes = enabled
                guard enabled else { return }
                let target: WidgetSizeKey = sizeKey == .small ? .medium : .small
                storeAppearance(copiedAppearance(from: sizeKey, to: target, in: appearance, reportError: true))
                ImpactHelper.success()
            }
        )
    }

    private func copyLayout(to target: WidgetSizeKey) {
        let source: WidgetSizeKey = target == .small ? .medium : .small
        storeAppearance(copiedAppearance(from: source, to: target, in: appearance, reportError: true))
        ImpactHelper.success()
        withAnimation(.easeInOut(duration: 0.25)) {
            sizeKey = target
        }
    }

    private func copiedAppearance(
        from sourceKey: WidgetSizeKey,
        to targetKey: WidgetSizeKey,
        in appearance: WidgetAppearance,
        reportError: Bool
    ) -> WidgetAppearance {
        var copy = appearance
        var source = copy.appearance(for: sourceKey)
        if targetKey == .medium, source.background.shape == .circle {
            source.background.shape = .roundedRect
        } else if copy.small.background.shape == .circle {
            source.background.shape = .circle
        }
        if case .image(.file(let path)) = source.background.fill {
            let targetFill = copy.appearance(for: targetKey).background.fill
            let targetHasFile: Bool = {
                if case .image(.file) = targetFill { return true }
                return false
            }()
            if !reportError, copiedImageSourcePath[targetKey] == path, targetHasFile {
                source.background.fill = targetFill
            } else if let image = WidgetBackgroundStore.shared.loadImage(relativePath: path),
                      let newPath = try? WidgetBackgroundStore.shared.saveImage(image, metricId: metricId, size: targetKey) {
                source.background.fill = .image(.file(newPath))
                copiedImageSourcePath[targetKey] = path
            } else {
                source.background.fill = .system
                if reportError {
                    backgroundApplyError = L10n.importStyleError
                }
            }
        }
        copy.setAppearance(source, for: targetKey)
        return copy
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
