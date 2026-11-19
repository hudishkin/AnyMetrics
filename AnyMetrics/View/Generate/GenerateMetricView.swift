import SwiftUI
import VVSI
import AnyMetricsShared

struct GenerateMetricView: View {

    @StateObject
    private var viewState: ViewState<Interactor>
    @ObservedObject
    private var generation = GenerationJobService.shared
    @EnvironmentObject
    private var mainState: ViewState<MainView.Interactor>
    @FocusState
    private var isComposerFocused: Bool
    @State
    private var composerText = ""
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.colorScheme)
    private var colorScheme
    @Environment(\.presentationMode)
    private var presentationMode
    @State
    private var keepsBubbles: Bool
    @State
    private var questionEcho: String?
    @State
    private var shownLine = ""
    @State
    private var lineHidden = false
    @State
    private var lineSqueezed = false
    @State
    private var robotLineToken = 0
    @State
    private var statusStep = 0
    @State
    private var statusCycle = 0
    @State
    private var preparingNew = false
    @State
    private var sending = false
    /// Shown before the async send lands. The field animation used to drop that update.
    @State
    private var pendingLines: [String] = []
    @State
    private var showHistory = false
    @State
    private var confirmReset = false
    private var onDismissResult: () -> Void
    private var onRememberJob: (UUID) -> Void
    /// History passes a job directly. The gallery screen reads `reopen` instead.
    private var suppliedJobID: UUID?
    @ObservedObject
    private var reopen: GenerateReopen
    /// Generate New drops the finished job. The card stays until then.
    @State
    private var dismissedJobID: UUID?
    /// Route already applied on this visit. A restored screen can still be holding an older dialog.
    @State
    private var appliedRouteToken: String?

    init(
        jobID: UUID? = nil,
        reopen: GenerateReopen = .detached,
        onDismissResult: @escaping () -> Void = {},
        onRememberJob: @escaping (UUID) -> Void = { _ in }
    ) {
        let record = jobID.flatMap { GenerationJobService.shared.record(jobID: $0) }
        let done = record?.job.flatMap(GeneratedMetricAdapter.metric(from:)) != nil
        let answers = record?.job?.dialog.compactMap(\.answer) ?? []
        self.onDismissResult = onDismissResult
        self.onRememberJob = onRememberJob
        self.suppliedJobID = jobID
        _reopen = ObservedObject(wrappedValue: reopen)
        _keepsBubbles = State(initialValue: !done)
        _viewState = StateObject(
            wrappedValue: ViewState(Interactor(jobID: jobID, prompt: record?.prompt, answers: answers))
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let robot = robotSize(for: proxy.size.height)
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    robotHeader(width: proxy.size.width, robot: robot)
                    messageLane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let metric = completedMetric, presentsResult {
                    readyMetric(metric, size: robot)
                        .padding(.top, Constants.headerTop + robot * Constants.robotDropShare)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .padding(.bottom, Constants.composerSlot)
            .animation(arrive.delay(0.14), value: presentsResult)
            .contentShape(Rectangle())
            .onTapGesture {
                isComposerFocused = false
            }
        }
        .overlay(alignment: .bottom) {
            composerDock
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: showsAnswerComposer)
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: showsRetry)
        .animation(exitDown, value: showsNew)
        .background(alignment: .top) {
            RobotGradientWash(
                direction: .down,
                softness: isDark ? 1 : 0.92,
                opacity: isDark ? Constants.glowOpacityDark : Constants.glowOpacity
            )
            .frame(height: Constants.glowHeight)
            .ignoresSafeArea(edges: .top)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(AnyMetricsStrings.Generate.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ZStack {
                    NavigationLink(isActive: $showHistory) {
                        GenerateHistoryView()
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)

                    Menu {
                        Button {
                            showHistory = true
                        } label: {
                            Label(AnyMetricsStrings.Generate.history, systemImage: "clock.arrow.circlepath")
                        }
                        .accessibilityIdentifier("generate.menu.history")

                        Button(role: .destructive) {
                            confirmReset = true
                        } label: {
                            Label(AnyMetricsStrings.Generate.reset, systemImage: "arrow.counterclockwise")
                        }
                        .accessibilityIdentifier("generate.menu.reset")
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Constants.textColor)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityIdentifier("generate.menu")
                    .accessibilityLabel(AnyMetricsStrings.Generate.more)
                }
            }
        }
        .alert(AnyMetricsStrings.Generate.reset, isPresented: $confirmReset) {
            Button(AnyMetricsStrings.Generate.reset, role: .destructive) {
                startNew()
            }
            Button(AnyMetricsStrings.Common.close, role: .cancel) {}
        } message: {
            Text(AnyMetricsStrings.Generate.Reset.message)
        }
        .tint(Constants.textColor)
        .background(DismissNavigationSearch())
        .onAppear {
            if discardedRestoredDialog {
                clearForBlankRoute()
            } else if pinnedFinishedJobID != nil {
                clearFinishedChrome()
            }
            appliedRouteToken = reopen.state.token
            viewState.trigger(.onAppear)
            if shownLine.isEmpty {
                shownLine = robotLine
            }
            if let text = liveQuestion {
                questionEcho = text
            }
            beginStatusCycle(showsStatusCycle)
        }
        .onChange(of: showsStatusCycle) { cycling in
            beginStatusCycle(cycling)
        }
        .onChange(of: robotLine) { newValue in
            updateRobotLine(newValue)
        }
        .onChange(of: liveQuestion) { text in
            if let text {
                questionEcho = text
            } else if completedMetric == nil {
                questionEcho = nil
            }
        }
        .onChange(of: viewState.state.draft) { newValue in
            guard !sending, composerText != newValue else { return }
            composerText = newValue
        }
        .onChange(of: reopen.state) { next in
            guard reopen !== GenerateReopen.detached else { return }
            appliedRouteToken = next.token
            if let id = next.jobID, dismissedJobID != id, finishedMetric(id) != nil {
                clearFinishedChrome()
                return
            }
            if next.jobID == nil, next.token != "new" {
                clearForBlankRoute()
            }
        }
        .onChange(of: viewState.state.jobID) { id in
            if let id {
                onRememberJob(id)
            }
            clearPreparingNewIfReady()
        }
        .onChange(of: viewState.state.userLines) { lines in
            if lines.isEmpty || lines.count >= pendingLines.count {
                pendingLines = []
            }
            clearPreparingNewIfReady()
        }
        .onChange(of: showsWaitingComposer) { waiting in
            if waiting {
                isComposerFocused = false
            } else {
                sending = false
            }
        }
        .onReceive(viewState.notifications) { notification in
            switch notification {
            case .submitted:
                isComposerFocused = false
            }
        }
    }

    private var isDark: Bool { colorScheme == .dark }

    private var composerVisible: Bool {
        showsPromptComposer || showsAnswerComposer || showsWaitingComposer || showsRetry || showsNew
    }

    private var composerDock: some View {
        VStack(spacing: 10) {
            if composerVisible, !showsRetry, !showsNew, let error = viewState.state.generationError {
                statusText(error)
            }
            if showsPromptComposer {
                examples
            }
            if showsNew {
                newButton
                    .transition(.opacity)
            } else if showsRetry {
                retryButton
            } else {
                composer(answer: showsAnswerComposer, waiting: fieldWaiting)
                    .transition(fieldExit)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .opacity(composerVisible ? 1 : 0)
        .offset(y: composerVisible || reduceMotion ? 0 : 10)
        .allowsHitTesting(composerVisible)
        .accessibilityHidden(!composerVisible)
    }

    private var showsPromptComposer: Bool {
        preparingNew || (completedMetric == nil && displayedUserLines.isEmpty)
    }

    private var showsNew: Bool {
        presentsResult
    }

    /// The card stays up once it exists. Generate New is what takes it down.
    private var presentsResult: Bool {
        !preparingNew && completedMetric != nil
    }

    private var showsAnswerComposer: Bool {
        completedMetric == nil && liveQuestion != nil && !viewState.state.isAnswering
    }

    /// Covers the gap before the job state catches the tap.
    private var fieldWaiting: Bool {
        showsWaitingComposer || sending
    }

    /// The field stays up while a search or an answer is in flight.
    private var showsWaitingComposer: Bool {
        completedMetric == nil
            && !preparingNew
            && !showsRetry
            && (viewState.state.isAnswering || (!displayedUserLines.isEmpty && liveQuestion == nil))
    }

    private var faceKind: RobotFaceView.Kind {
        if showsAnswerComposer {
            return .awaiting
        }
        if completedMetric == nil, failureMessage != nil {
            return .notFound
        }
        if completedMetric == nil, !displayedUserLines.isEmpty {
            return .working
        }
        return .glance
    }

    /// Greeting plays once. The other scenes play their intro once, then keep a quiet loop going.
    private var faceLoops: Bool {
        switch faceKind {
        case .working, .awaiting, .notFound:
            true
        case .glance, .widget:
            false
        }
    }

    private var showsRetry: Bool {
        !preparingNew
            && completedMetric == nil
            && liveQuestion == nil
            && !viewState.state.isAnswering
            && failureMessage != nil
    }

    /// Blank route after a finished visit, while this screen still has the previous dialog.
    private var discardedRestoredDialog: Bool {
        guard reopen !== GenerateReopen.detached else { return false }
        guard reopen.state.jobID == nil, reopen.state.token != "new" else { return false }
        guard appliedRouteToken != reopen.state.token else { return false }
        return viewState.state.jobID != nil || !viewState.state.userLines.isEmpty
    }

    /// The gallery reopens an in-progress job through `reopen`. A restored conversation does not replace it.
    private var requestedJobID: UUID? {
        reopen === GenerateReopen.detached ? suppliedJobID : reopen.state.jobID
    }

    private func finishedMetric(_ jobID: UUID) -> Metric? {
        generation.record(jobID: jobID)?.job.flatMap(GeneratedMetricAdapter.metric(from:))
    }

    private func clearFinishedChrome() {
        preparingNew = false
        sending = false
        pendingLines = []
        composerText = ""
        questionEcho = nil
        keepsBubbles = false
    }

    private func clearForBlankRoute() {
        dismissedJobID = nil
        preparingNew = false
        sending = false
        pendingLines = []
        composerText = ""
        isComposerFocused = false
        questionEcho = nil
        keepsBubbles = true
        lineHidden = false
        lineSqueezed = false
        showRobotLine(AnyMetricsStrings.Generate.greeting)
        viewState.trigger(.reset)
    }

    private func startNew() {
        dismissedJobID = requestedJobID
        preparingNew = true
        sending = false
        pendingLines = []
        composerText = ""
        isComposerFocused = false
        questionEcho = nil
        keepsBubbles = true
        onDismissResult()
        showRobotLine(AnyMetricsStrings.Generate.greeting)
        viewState.trigger(.reset)
    }

    private func clearPreparingNewIfReady() {
        guard preparingNew else { return }
        guard viewState.state.jobID == nil, viewState.state.userLines.isEmpty else { return }
        preparingNew = false
    }

    private var retryButton: some View {
        dockButton(AnyMetricsStrings.Generate.tryAgain, identifier: "generate.retry") {
            startNew()
        }
    }

    private var newButton: some View {
        dockButton(AnyMetricsStrings.Generate.generateNew, identifier: "generate.new") {
            startNew()
        }
    }

    private func dockButton(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            ImpactHelper.impactButton()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Constants.textColor)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.sendButtonSize + 12)
                .background(
                    RoundedRectangle(cornerRadius: Constants.composerCorner, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier(identifier)
    }

    /// Finished job passed in from the gallery. Wins over a conversation restored from the previous visit.
    private var pinnedFinishedJobID: UUID? {
        guard let requestedJobID, dismissedJobID != requestedJobID else { return nil }
        guard finishedMetric(requestedJobID) != nil else { return nil }
        return requestedJobID
    }

    private var activeJobID: UUID? {
        pinnedFinishedJobID ?? viewState.state.jobID
    }

    private var completedMetric: Metric? {
        guard let jobID = activeJobID,
              let job = generation.record(jobID: jobID)?.job,
              var metric = GeneratedMetricAdapter.metric(from: job) else { return nil }
        metric.widgetAppearance = StarterMetric.appearance(for: .haze)
        metric.widgetDesign = .roundedCard
        return metric
    }

    /// The card stays centered. Source and Add hang below and do not move that center.
    private func readyMetric(_ metric: Metric, size: CGFloat) -> some View {
        MetricContentView(metric: metric)
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.16), radius: 22, x: 0, y: 14)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if let source = completedSource {
                        sourceCaption(source)
                    }
                    addButton(metric)
                }
                .alignmentGuide(.bottom) { _ in -12 }
            }
            .accessibilityIdentifier("generate.job.ready")
    }

    private var completedSource: BuilderAPI.MetricSource? {
        guard let jobID = activeJobID,
              let source = generation.record(jobID: jobID)?.job?.result?.source else { return nil }
        return source
    }

    /// Name, then the site it comes from. Sits between the card and Add.
    private func sourceCaption(_ source: BuilderAPI.MetricSource) -> some View {
        let name = source.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let site = sourceSite(source)
        let title = (name?.isEmpty == false) ? name : nil
        return VStack(spacing: 2) {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Constants.textColor)
            }
                if let site, site.label != title {
                    if let url = site.url {
                        Link(site.label, destination: url)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Constants.secondaryColor)
                            .tint(Constants.secondaryColor)
                    } else {
                    Text(site.label)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Constants.secondaryColor)
                }
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .frame(maxWidth: 280)
        .accessibilityIdentifier("generate.source")
    }

    private func sourceSite(_ source: BuilderAPI.MetricSource) -> (label: String, url: URL?)? {
        let raw = (source.website ?? source.url).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw) else { return nil }
        let host = url.host?.replacingOccurrences(of: "www.", with: "")
        let label = host.flatMap { $0.isEmpty ? nil : $0 } ?? raw
        return (label, url)
    }

    private func isSaved(_ metric: Metric) -> Bool {
        mainState.state.metrics[metric.id] != nil && mainState.state.personalMetrics[metric.id] != nil
    }

    private func add(_ metric: Metric) {
        guard !isSaved(metric) else { return }
        ImpactHelper.success()
        AnalyticsEvents.metricAdded(
            source: AnalyticsEvents.Source.generate,
            type: metric.type,
            resultKind: metric.resultKind
        )
        mainState.trigger(.addPersonalMetricAndRefresh(metric))
        presentationMode.wrappedValue.dismiss()
    }

    /// Smaller on short screens and while the keyboard is up, so the bubble, examples and field all fit.
    private func robotSize(for height: CGFloat) -> CGFloat {
        min(Constants.robotMaxSize, max(Constants.robotMinSize, height * Constants.robotHeightShare)).rounded()
    }

    private func robotHeader(width: CGFloat, robot: CGFloat) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                face(size: robot)
                if keepsBubbles, pinnedFinishedJobID == nil {
                    robotBubble(maxWidth: robotTextWidth(in: width))
                        .fixedSize()
                        .rotationEffect(.degrees(-3), anchor: .top)
                        .padding(.top, robot * (1 - Constants.bubbleOverlapShare))
                        .offset(y: faceDeparted ? departure(-340) : 0)
                        .opacity(faceDeparted ? 0 : 1)
                        .animation(exitUp.delay(0.05), value: presentsResult)
                        .allowsHitTesting(false)
                        .accessibilityHidden(presentsResult)
                }
            }
            .frame(width: robot, height: robot)
            .offset(y: robot * Constants.robotDropShare)
            addSlot
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Constants.headerTop)
    }

    private var messageLane: some View {
        GeometryReader { lane in
            let frontInset = CGFloat(28)
            ScrollViewReader { scroller in
                ScrollView(showsIndicators: false) {
                    BottomPinLayout(minHeight: lane.size.height, spacing: -22, bottomInset: frontInset) {
                        ForEach(indexedLines) { line in
                            userBubble(line, maxWidth: robotTextWidth(in: lane.size.width))
                                .scrollDepth(viewportHeight: lane.size.height, frontInset: frontInset)
                                .zIndex(Double(line.index))
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(speech, value: indexedLines.count)
                }
                .coordinateSpace(name: ScrollDepth.space)
                .onAppear {
                    scrollToFront(scroller)
                }
                .onChange(of: displayedUserLines) { _ in
                    withAnimation(speech) {
                        scrollToFront(scroller)
                    }
                }
            }
        }
    }

    private func scrollToFront(_ scroller: ScrollViewProxy) {
        guard let last = indexedLines.last else { return }
        scroller.scrollTo(last.id, anchor: .bottom)
    }

    private func face(size: CGFloat) -> some View {
        ZStack {
            RobotFaceView(size: size, kind: faceKind, loop: faceLoops)
                .offset(y: faceDeparted ? departure(-320) : 0)
                .opacity(faceDeparted ? 0 : 1)
                .animation(exitUp, value: presentsResult)
        }
        .frame(width: size, height: size)
    }

    private var addSlot: some View {
        Color.clear.frame(height: 34)
    }

    private func addButton(_ metric: Metric) -> some View {
        let saved = isSaved(metric)
        return Button {
            add(metric)
        } label: {
            Text(AnyMetricsStrings.Metric.add)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Constants.sendIconColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(Constants.textColor))
        }
        .buttonStyle(.plain)
        .disabled(saved)
        .opacity(saved ? 0.45 : 1)
        .accessibilityIdentifier("generate.add")
    }

    private struct UserLine: Identifiable {
        let index: Int
        let text: String
        var id: Int { index }
    }

    /// The model line list once it has caught the tap. Until then, the text just sent.
    private var visibleUserLines: [String] {
        let stored = viewState.state.userLines
        return stored.count >= pendingLines.count ? stored : pendingLines
    }

    /// Prompt, then each answer the job has stored. A reply still in flight is appended until the dialog catches it.
    private var displayedUserLines: [String] {
        let local = visibleUserLines
        guard let jobID = activeJobID,
              let record = generation.record(jobID: jobID) else { return local }
        var lines: [String] = []
        let prompt = record.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            lines.append(prompt)
        }
        for turn in record.job?.dialog ?? [] {
            let answer = turn.answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !answer.isEmpty {
                lines.append(answer)
            }
        }
        if jobID == viewState.state.jobID, local.count > lines.count {
            lines.append(contentsOf: local.suffix(local.count - lines.count))
        }
        return lines
    }

    private var indexedLines: [UserLine] {
        guard !preparingNew else { return [] }
        return displayedUserLines.enumerated().map { UserLine(index: $0.offset, text: $0.element) }
    }

    private var faceDeparted: Bool { presentsResult }

    private func departure(_ distance: CGFloat) -> CGFloat {
        reduceMotion ? 0 : distance
    }

    /// Light mass. The bubble uses the same spring a moment later, so it trails the head.
    private var exitUp: Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.64, dampingFraction: 0.8)
    }

    /// Heavier drop. Low damping carries the motion past the rest point, off screen.
    private var exitDown: Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.84, dampingFraction: 0.74)
    }

    private var fieldExit: AnyTransition {
        reduceMotion ? .opacity : .offset(y: 240).combined(with: .opacity)
    }

    private var arrive: Animation {
        .spring(response: 0.52, dampingFraction: 0.8)
    }

    private var speech: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    private func showRobotLine(_ text: String) {
        robotLineToken += 1
        shownLine = text
        lineHidden = false
        lineSqueezed = false
    }

    /// Inhale, then speak: the old text clears fast, the bubble springs to the new size with a light overshoot, the new text lands last.
    private func updateRobotLine(_ newValue: String) {
        guard !shownLine.isEmpty, shownLine != newValue else {
            showRobotLine(newValue)
            return
        }
        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showRobotLine(newValue)
            }
            return
        }
        robotLineToken += 1
        let token = robotLineToken
        withAnimation(.easeIn(duration: 0.14)) {
            lineHidden = true
            lineSqueezed = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard token == robotLineToken else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.66)) {
                shownLine = newValue
                lineSqueezed = false
            }
            withAnimation(.easeOut(duration: 0.26).delay(0.07)) {
                lineHidden = false
            }
        }
    }

    private var liveQuestion: String? {
        guard let jobID = viewState.state.jobID,
              let record = generation.record(jobID: jobID),
              record.status == .needsInput,
              let text = record.job?.question?.text,
              !text.isEmpty else { return nil }
        return text
    }

    private var statusLines: [String] {
        [
            AnyMetricsStrings.Generate.Status.finding,
            AnyMetricsStrings.Generate.Status.checking,
            AnyMetricsStrings.Generate.Status.creating
        ]
    }

    /// Working phrases. A clarification replaces them, and the next run starts at the first line.
    private var showsStatusCycle: Bool {
        guard !preparingNew, !presentsResult, failureMessage == nil else { return false }
        if !viewState.state.isAnswering, liveQuestion != nil { return false }
        return !displayedUserLines.isEmpty
    }

    private func beginStatusCycle(_ cycling: Bool) {
        statusCycle += 1
        statusStep = 0
        guard cycling else { return }
        let cycle = statusCycle
        let pause: UInt64 = 2_600_000_000
        Task { @MainActor in
            while statusCycle == cycle {
                try? await Task.sleep(nanoseconds: pause)
                guard statusCycle == cycle, showsStatusCycle else { return }
                statusStep = (statusStep + 1) % statusLines.count
            }
        }
    }

    private var robotLine: String {
        if preparingNew {
            return AnyMetricsStrings.Generate.greeting
        }
        if !viewState.state.isAnswering, let question = liveQuestion {
            return question
        }
        if presentsResult, let questionEcho {
            return questionEcho
        }
        if let failure = failureMessage, !presentsResult {
            return failure
        }
        if showsStatusCycle {
            return statusLines[statusStep % statusLines.count]
        }
        return AnyMetricsStrings.Generate.greeting
    }

    private var failureMessage: String? {
        guard completedMetric == nil else { return nil }
        if let error = viewState.state.generationError, !error.isEmpty, !viewState.state.userLines.isEmpty {
            return error
        }
        guard let jobID = viewState.state.jobID,
              let record = generation.record(jobID: jobID) else { return nil }
        guard record.status == .failed || record.job?.status == .failed else { return nil }
        let text = record.job?.error?.message ?? record.failure ?? ""
        return text.isEmpty ? nil : text
    }

    /// Leaves the bubble's own padding and a small screen margin, then gives the rest to the text.
    private func robotTextWidth(in width: CGFloat) -> CGFloat {
        let reserved = CGFloat(88)
        return max(CGFloat(220), width - reserved)
    }

    private func robotBubble(maxWidth: CGFloat) -> some View {
        RobotLineBubble(
            text: shownLine.isEmpty ? robotLine : shownLine,
            textHidden: lineHidden,
            squeezed: lineSqueezed,
            maxWidth: maxWidth
        )
        .accessibilityIdentifier("generate.robot")
    }

    private func userBubble(_ line: UserLine, maxWidth: CGFloat) -> some View {
        SpeechBubble(
            side: .bottomCenter,
            role: .user,
            tilt: .zero,
            maxWidth: maxWidth
        ) {
            Text(line.text)
                .font(Constants.bubbleFont)
                .foregroundColor(Constants.textColor)
                .multilineTextAlignment(.leading)
        }
        .rotationEffect(.degrees(1), anchor: .bottom)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("generate.sent.\(line.index)")
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(Constants.examplesFont)
            .foregroundColor(Constants.secondaryColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
    }

    private var examples: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.chipSpacing) {
                ForEach(viewState.state.examples) { example in
                    Button {
                        ImpactHelper.impactLight()
                        composerText = example.title
                        viewState.trigger(.selectExample(example.id))
                        DispatchQueue.main.async {
                            isComposerFocused = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(example.emoji)
                            Text(example.title)
                                .lineLimit(1)
                        }
                        .font(Constants.chipFont)
                        .foregroundColor(Constants.textColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Constants.chipFill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("generate.example.\(example.id)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 1)
        }
        .frame(height: 42)
    }

    private func composer(answer: Bool, waiting: Bool) -> some View {
        GenerateComposer(
            text: Binding(
                get: { composerText },
                set: { newValue in
                    // A focused field writes the old text back after Send. Ignore that echo.
                    if sending, !newValue.isEmpty { return }
                    composerText = newValue
                    if !sending {
                        viewState.trigger(.setDraft(newValue))
                    }
                }
            ),
            isFocused: $isComposerFocused,
            placeholder: waiting
                ? AnyMetricsStrings.Generate.waiting
                : (answer ? AnyMetricsStrings.Generate.answerPlaceholder : AnyMetricsStrings.Generate.placeholder),
            fieldIdentifier: waiting ? "generate.waiting" : (answer ? "generate.answer" : "generate.draft"),
            isWaiting: waiting,
            onSend: {
                let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                ImpactHelper.impactButton()
                guard text.count <= GenerationJobService.maximumPromptLength else {
                    viewState.trigger(.send(text))
                    return
                }
                sending = true
                pendingLines.append(text)
                composerText = ""
                isComposerFocused = false
                viewState.trigger(.send(text))
            }
        )
    }
}

private struct GenerateComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var placeholder: String
    var fieldIdentifier: String
    var isWaiting: Bool = false
    var onSend: () -> Void

    private let sendInset: CGFloat = 6

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: GenerateMetricView.Constants.composerCorner,
            style: .continuous
        )
        HStack(alignment: .bottom, spacing: 0) {
            TextField("", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(GenerateMetricView.Constants.inputFont)
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .focused(isFocused)
                .disabled(isWaiting)
                .lineLimit(1...GenerateMetricView.Constants.composerMaxLines)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.trailing, isWaiting ? 16 : 8)
                .padding(.vertical, 11)
                .frame(
                    minHeight: GenerateMetricView.Constants.sendButtonSize + sendInset * 2,
                    alignment: .center
                )
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        WaitingPlaceholder(text: placeholder, active: isWaiting)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier(fieldIdentifier)

            Button {
                guard canSend else { return }
                onSend()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(GenerateMetricView.Constants.sendIconColor)
                    .frame(
                        width: GenerateMetricView.Constants.sendButtonSize,
                        height: GenerateMetricView.Constants.sendButtonSize
                    )
                    .background(
                        Circle().fill(GenerateMetricView.Constants.textColor)
                    )
            }
            .buttonStyle(.plain)
            .opacity(isWaiting ? 0 : 1)
            .allowsHitTesting(!isWaiting)
            .accessibilityHidden(isWaiting)
            .frame(width: isWaiting ? 0 : nil, alignment: .center)
            .clipped()
            .padding(.trailing, isWaiting ? 0 : sendInset)
            .padding(.vertical, sendInset)
            .accessibilityIdentifier("generate.send")
            .accessibilityLabel(AnyMetricsStrings.Generate.send)
        }
        .background(shape.fill(Color(uiColor: .systemBackground)))
        .overlay {
            AIGradientBorder(cornerRadius: GenerateMetricView.Constants.composerCorner)
        }
        .clipShape(shape)
        .padding(.horizontal, 16)
    }
}

/// A soft light moves across the waiting placeholder. Time drives it, so a parent spring cannot hitch the sweep.
private struct WaitingPlaceholder: View {
    var text: String
    var active: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !active)) { timeline in
            Text(text)
                .font(GenerateMetricView.Constants.inputFont)
                .foregroundStyle(style(at: timeline.date))
                .lineLimit(1)
        }
        .accessibilityLabel(text)
    }

    private func style(at date: Date) -> AnyShapeStyle {
        if reduceMotion || !active {
            return AnyShapeStyle(GenerateMetricView.Constants.secondaryColor)
        }
        let period = 1.6
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        let shift = -0.8 + phase * 2.0
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    GenerateMetricView.Constants.secondaryColor.opacity(0.4),
                    GenerateMetricView.Constants.textColor,
                    GenerateMetricView.Constants.secondaryColor.opacity(0.4)
                ],
                startPoint: UnitPoint(x: shift, y: 0.5),
                endPoint: UnitPoint(x: shift + 0.6, y: 0.5)
            )
        )
    }
}

/// The catalog search uses `displayMode: .always`, so a pushed screen keeps that field under the title.
struct DismissNavigationSearch: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.removeSearch()
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            removeSearch()
            DispatchQueue.main.async { [weak self] in
                self?.removeSearch()
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            removeSearch()
        }

        func removeSearch() {
            guard let navigation = view.enclosingNavigationController(),
                  let top = navigation.topViewController,
                  view.isDescendant(of: top.view) else { return }
            guard top.navigationItem.searchController != nil else { return }
            top.navigationItem.searchController = nil
            navigation.navigationBar.setNeedsLayout()
        }
    }
}

private extension UIView {
    func enclosingNavigationController() -> UINavigationController? {
        var responder: UIResponder? = self
        while let next = responder {
            if let navigation = next as? UINavigationController { return navigation }
            if let controller = next as? UIViewController, let navigation = controller.navigationController {
                return navigation
            }
            responder = next.next
        }
        return nil
    }
}

/// One bubble for every robot line. It squeezes toward the tail while the old text clears, then springs to the new size.
private struct RobotLineBubble: View {
    var text: String
    var textHidden: Bool
    var squeezed: Bool
    var maxWidth: CGFloat

    var body: some View {
        SpeechBubble(
            side: .topCenter,
            role: .robot,
            tilt: .zero,
            maxWidth: maxWidth
        ) {
            Text(text)
                .font(GenerateMetricView.Constants.bubbleFont)
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .blur(radius: textHidden ? 5 : 0)
                .opacity(textHidden ? 0 : 1)
        }
        .scaleEffect(squeezed ? 0.95 : 1, anchor: .top)
    }
}

/// Pins a short message stack to the bottom of the lane. A `Spacer` inside `ScrollView` collapses, which left the bubbles in the far zone.
private struct BottomPinLayout: Layout {
    var minHeight: CGFloat
    var spacing: CGFloat
    var bottomInset: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let content = contentHeight(width: width, subviews: subviews)
        return CGSize(width: width, height: max(minHeight, content + bottomInset))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let proposal = ProposedViewSize(width: bounds.width, height: nil)
        var y = bounds.maxY - bottomInset
        for subview in subviews.reversed() {
            let size = subview.sizeThatFits(proposal)
            y -= size.height
            subview.place(at: CGPoint(x: bounds.midX, y: y), anchor: .top, proposal: proposal)
            y -= spacing
        }
    }

    private func contentHeight(width: CGFloat, subviews: Subviews) -> CGFloat {
        let proposal = ProposedViewSize(width: width, height: nil)
        let heights = subviews.map { $0.sizeThatFits(proposal).height }
        return heights.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
    }
}

#if DEBUG
struct GenerateMetricView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GenerateMetricView()
        }
        .environmentObject(ViewState(MainView.Interactor()))
        .preferredColorScheme(.light)
    }
}
#endif
