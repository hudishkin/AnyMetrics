import SwiftUI

struct GenerateHistoryView: View {

    @ObservedObject
    private var generation = GenerationJobService.shared

    private var rows: [GenerationJobRecord] {
        generation.jobs.filter { record in
            guard record.jobId != nil else { return false }
            switch record.status {
            case .completed:
                return record.job?.result != nil
            case .failed:
                return true
            case .queued, .running, .needsInput, .cancelled, .none:
                return false
            }
        }
    }

    var body: some View {
        Group {
            if rows.isEmpty {
                Text(AnyMetricsStrings.Generate.History.empty)
                    .font(GenerateMetricView.Constants.examplesFont)
                    .foregroundColor(GenerateMetricView.Constants.secondaryColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GenerateMetricView.Constants.horizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(rows) { record in
                    if let jobID = record.jobId {
                        NavigationLink {
                            GenerateMetricView(jobID: jobID)
                        } label: {
                            row(record)
                        }
                        .accessibilityIdentifier("generate.history.\(jobID.uuidString.lowercased())")
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(AnyMetricsStrings.Generate.history)
        .navigationBarTitleDisplayMode(.inline)
        .background(DismissNavigationSearch())
        .task {
            guard !isPreview else { return }
            await GenerationJobService.shared.resume()
        }
    }

    private func row(_ record: GenerationJobRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.prompt)
                .font(GenerateMetricView.Constants.chipFont)
                .foregroundColor(GenerateMetricView.Constants.textColor)
                .lineLimit(2)
            if let detail = detail(record), !detail.isEmpty {
                Text(detail)
                    .font(GenerateMetricView.Constants.examplesFont)
                    .foregroundColor(GenerateMetricView.Constants.secondaryColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func detail(_ record: GenerationJobRecord) -> String? {
        switch record.status {
        case .completed:
            return record.job?.result?.metric.title
        case .failed:
            return record.job?.error?.message ?? record.failure
        case .queued, .running, .needsInput, .cancelled, .none:
            return nil
        }
    }
}
