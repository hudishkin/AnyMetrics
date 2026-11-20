import SwiftUI
import AnyMetricsShared

/// The card stays centered. Source and Add hang below and do not move that center.
struct GeneratedMetricCard: View {
    var metric: Metric
    var size: CGFloat
    var source: BuilderAPI.MetricSource?
    var isSaved: Bool
    var onAdd: () -> Void

    var body: some View {
        MetricContentView(metric: metric)
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.16), radius: 22, x: 0, y: 14)
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if let source {
                        sourceCaption(source)
                    }
                    addButton
                }
                .alignmentGuide(.bottom) { _ in -12 }
            }
            .accessibilityIdentifier("generate.job.ready")
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
                    .foregroundColor(GenerateMetricView.Constants.textColor)
            }
            if let site, site.label != title {
                if let url = site.url {
                    Link(site.label, destination: url)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(GenerateMetricView.Constants.secondaryColor)
                        .tint(GenerateMetricView.Constants.secondaryColor)
                } else {
                    Text(site.label)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(GenerateMetricView.Constants.secondaryColor)
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

    private var addButton: some View {
        Button {
            onAdd()
        } label: {
            Text(AnyMetricsStrings.Metric.add)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(GenerateMetricView.Constants.sendIconColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(GenerateMetricView.Constants.textColor))
        }
        .buttonStyle(.plain)
        .disabled(isSaved)
        .opacity(isSaved ? 0.45 : 1)
        .accessibilityIdentifier("generate.add")
    }
}
