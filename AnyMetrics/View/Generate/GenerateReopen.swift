import SwiftUI

/// What the generate screen should show after it is closed. The screen keeps this object.
struct GenerateReopenState: Equatable {
    var jobID: UUID?
    var token = "new"
}

final class GenerateReopen: ObservableObject {
    @Published var state = GenerateReopenState()

    static let detached = GenerateReopen()
}

/// Watches the open generation without invalidating the gallery list.
struct GenerateLiveRouteMonitor: View {
    @ObservedObject private var generation = GenerationJobService.shared
    var screenOpen: Bool
    var onLiveJob: (UUID?) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: generation.live?.jobId) { jobID in
                guard !screenOpen else { return }
                onLiveJob(jobID)
            }
    }
}
