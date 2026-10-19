import SwiftUI
import AnyMetricsShared

struct WidgetDesignGalleryView: View {

    struct Item: Identifiable {
        let id: String
        let metric: Metric
        let isSelected: Bool
    }

    private enum Constants {
        static let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        static let gridPadding: CGFloat = 8
        static let checkmarkInset: CGFloat = 10
        static let badgeSize: CGFloat = 34
        static let badgeCheckSize: CGFloat = 16
    }

    let items: [Item]
    var onSelect: (Item) -> Void
    var onClose: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Constants.columns, spacing: Constants.gridPadding) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            galleryCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Constants.gridPadding)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AnyMetricsStrings.Addmetric.Field.widgetDesign)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AnyMetricsStrings.Common.close) {
                        onClose()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func galleryCard(_ item: Item) -> some View {
        MetricWidgetDesignView(
            metric: item.metric,
            palette: .widget(),
            useGlassEffect: item.metric.resolvedAppearance.small.background.usesGlassEffect,
            matchWidgetMetrics: false
        )
        .frame(width: MainView.Constants.size, height: MainView.Constants.size)
        .overlay(alignment: .topTrailing) {
            if item.isSelected {
                selectionBadge
                    .padding(.top, Constants.checkmarkInset)
                    .padding(.trailing, Constants.checkmarkInset)
            }
        }
        .contentShape(Rectangle())
    }

    private var selectionBadge: some View {
        badgeCheck
            .frame(width: Constants.badgeSize, height: Constants.badgeSize)
            .modifier(SelectionBadgeGlass())
    }

    private var badgeCheck: some View {
        Image(systemName: "checkmark")
            .font(.system(size: Constants.badgeCheckSize, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.82))
    }
}

private struct SelectionBadgeGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.clear, in: Circle())
        } else {
            content
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.7), .white.opacity(0.18)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                }
        }
    }
}
