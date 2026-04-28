import SwiftUI

struct StartTripSheet: View {
    @Environment(MigratedDataStore.self) private var store
    @Environment(TripTrackingService.self) private var tracking
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var tripType: TripType = .maintenance
    @State private var selectedPaddockId: UUID?
    @State private var trackingPattern: TrackingPattern = .sequential
    @State private var personName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Type") {
                    Picker("Type", selection: $tripType) {
                        Text("Maintenance").tag(TripType.maintenance)
                        Text("Spray").tag(TripType.spray)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Paddock") {
                    Picker("Paddock", selection: $selectedPaddockId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.paddocks) { paddock in
                            Text(paddock.name).tag(UUID?.some(paddock.id))
                        }
                    }
                }

                Section("Tracking Pattern") {
                    Picker("Pattern", selection: $trackingPattern) {
                        ForEach(TrackingPattern.allCases) { pattern in
                            Text(pattern.title).tag(pattern)
                        }
                    }
                }

                Section("Operator") {
                    TextField("Name (optional)", text: $personName)
                }

                if let error = tracking.errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Start Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { handleStart() }
                }
            }
            .onAppear {
                if personName.isEmpty, let name = auth.userName {
                    personName = name
                }
            }
        }
    }

    private func handleStart() {
        let paddockName: String
        if let id = selectedPaddockId, let paddock = store.paddocks.first(where: { $0.id == id }) {
            paddockName = paddock.name
        } else {
            paddockName = ""
        }

        tracking.startTrip(
            type: tripType,
            paddockId: selectedPaddockId,
            paddockName: paddockName,
            trackingPattern: trackingPattern,
            personName: personName
        )
        dismiss()
    }
}

struct ActiveTripCard: View {
    @Environment(TripTrackingService.self) private var tracking
    @Environment(LocationService.self) private var locationService

    var body: some View {
        if let trip = tracking.activeTrip {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(tracking.isPaused ? Color.orange : VineyardTheme.leafGreen)
                        .frame(width: 10, height: 10)
                    Text(tracking.isPaused ? "Trip Paused" : "Trip Active")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if locationService.location == nil {
                        Label("No GPS", systemImage: "location.slash")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 16) {
                    stat("Time", value: formatDuration(tracking.elapsedTime))
                    stat("Distance", value: formatDistance(tracking.currentDistance))
                    stat("Points", value: "\(trip.pathPoints.count)")
                }

                if !trip.paddockName.isEmpty {
                    Label(trip.paddockName, systemImage: "leaf")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if tracking.isPaused {
                        Button {
                            tracking.resumeTrip()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VineyardTheme.leafGreen)
                    } else {
                        Button {
                            tracking.pauseTrip()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(role: .destructive) {
                        tracking.endTrip()
                    } label: {
                        Label("End", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters))m" }
        return String(format: "%.2fkm", meters / 1000)
    }
}
