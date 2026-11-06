import SwiftUI
import Combine
import AnyMetricsShared

struct MetricBasisCatalog {
    struct GalleryRow: Identifiable {
        var group: String
        var metric: Metric
        var id: String { "\(group)-\(metric.id.uuidString)" }
    }

    var own: [Metric]
    var gallery: [GalleryItem]

    func filtered(query: String) -> (own: [Metric], gallery: [GalleryRow]) {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ownResult = own.filter { needle.isEmpty || Self.matches($0, needle: needle) }
        let galleryResult = gallery.flatMap { group -> [GalleryRow] in
            let groupMatches = !needle.isEmpty && (
                group.name.lowercased().contains(needle) || group.tags.lowercased().contains(needle)
            )
            return group.metrics.compactMap { metric in
                guard needle.isEmpty || groupMatches || Self.matches(metric, needle: needle) else {
                    return nil
                }
                return GalleryRow(group: group.name, metric: metric)
            }
        }
        return (ownResult, galleryResult)
    }

    private static func matches(_ metric: Metric, needle: String) -> Bool {
        let fields = [
            metric.title,
            metric.measure,
            metric.description ?? "",
            metric.request?.url.absoluteString ?? ""
        ]
        return fields.contains { $0.lowercased().contains(needle) }
    }
}

struct MetricBasisPickerView: View {

    var excludingID: UUID?
    var onSelect: (Metric) -> Void

    @StateObject
    private var loader = GalleryLoader()
    @State
    private var searchText = ""
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        let listed = catalog.filtered(query: searchText)
        NavigationView {
            List {
                if !listed.own.isEmpty {
                    Section(AnyMetricsStrings.Addmetric.Basis.own) {
                        ForEach(listed.own) { metric in
                            row(metric, group: nil) {
                                choose(metric)
                            }
                        }
                    }
                }

                if !listed.gallery.isEmpty {
                    Section(AnyMetricsStrings.Addmetric.Basis.gallery) {
                        ForEach(listed.gallery) { item in
                            row(item.metric, group: item.group) {
                                choose(item.metric)
                            }
                        }
                    }
                }

                if loader.isLoading && listed.gallery.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if listed.own.isEmpty && listed.gallery.isEmpty {
                    Text(AnyMetricsStrings.Addmetric.Basis.empty)
                        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: AnyMetricsStrings.Addmetric.Basis.search
            )
            .navigationTitle(AnyMetricsStrings.Addmetric.Basis.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(AnyMetricsStrings.Common.close) {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .tint(AnyMetricsAsset.Assets.baseText.swiftUIColor)
        .onAppear {
            loader.loadIfNeeded()
        }
    }

    private var catalog: MetricBasisCatalog {
        let own = DI.shared.metricStore.metrics.values
            .filter { $0.id != excludingID }
            .sorted { $0.created > $1.created }
        return MetricBasisCatalog(own: own, gallery: loader.gallery)
    }

    private func choose(_ metric: Metric) {
        onSelect(metric)
        dismiss()
    }

    private func row(_ metric: Metric, group: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(AnyMetricsAsset.Assets.baseText.swiftUIColor)
                let caption = caption(metric: metric, group: group)
                if !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundColor(AnyMetricsAsset.Assets.secondaryText.swiftUIColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func caption(metric: Metric, group: String?) -> String {
        var parts: [String] = []
        let measure = metric.measure.trimmingCharacters(in: .whitespacesAndNewlines)
        if !measure.isEmpty {
            parts.append(measure)
        }
        if let group, !group.isEmpty {
            parts.append(group)
        } else if measure.isEmpty, let host = metric.request?.url.host, !host.isEmpty {
            parts.append(host)
        }
        return parts.joined(separator: " · ")
    }
}

private final class GalleryLoader: ObservableObject {
    @Published var gallery: [GalleryItem] = []
    @Published var isLoading = false

    private var token: AnyCancellable?
    private var didStart = false

    func loadIfNeeded() {
        guard !didStart else { return }
        didStart = true
        isLoading = true
        token = GalleryService.load()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure = completion {
                    self?.gallery = []
                }
            } receiveValue: { [weak self] items in
                self?.gallery = items
            }
    }
}
