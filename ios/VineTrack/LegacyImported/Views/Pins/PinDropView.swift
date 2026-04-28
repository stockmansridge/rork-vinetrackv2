import SwiftUI
import CoreLocation

struct PinDropView: View {
    let mode: PinMode

    @Environment(MigratedDataStore.self) private var store
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(LocationService.self) private var locationService
    @Environment(BackendAccessControl.self) private var accessControl

    @State private var selectedPaddockId: UUID?
    @State private var rowText: String = ""
    @State private var notes: String = ""
    @State private var showEditButtons: Bool = false
    @State private var showGrowthPicker: Bool = false
    @State private var pendingGrowthButton: ButtonConfig?
    @State private var pendingSide: PinSide = .right
    @State private var feedbackMessage: String?
    @State private var feedbackKind: VineyardBadgeKind = .success

    private var canCreate: Bool { accessControl.canCreateOperationalRecords }
    private var canEdit: Bool { accessControl.canChangeSettings }

    private var leftButtons: [ButtonConfig] {
        let all = mode == .repairs ? store.repairButtons : store.growthButtons
        return Array(all.sorted { $0.index < $1.index }.prefix(4))
    }

    private var title: String {
        mode == .repairs ? "Repairs" : "Growth"
    }

    private var titleIcon: String {
        mode == .repairs ? "wrench.and.screwdriver.fill" : "leaf.fill"
    }

    private var titleColor: Color {
        mode == .repairs ? VineyardTheme.earthBrown : VineyardTheme.leafGreen
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !canCreate {
                    permissionWarning
                }
                gpsCard
                locationCard
                buttonsGrid
                notesCard
                if let feedbackMessage {
                    VineyardCard {
                        Label(feedbackMessage, systemImage: feedbackKind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(feedbackKind.foreground)
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                }
                Spacer(minLength: 24)
            }
            .padding(.vertical)
        }
        .background(VineyardTheme.appBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditButtons = true
                    } label: {
                        Label("Configure", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditButtons) {
            EditButtonsSheet(mode: mode)
        }
        .sheet(isPresented: $showGrowthPicker) {
            GrowthStagePickerSheet { stage in
                handleGrowthStageSelected(stage)
            }
        }
    }

    // MARK: - Header

    private var permissionWarning: some View {
        VineyardCard {
            Label("Read-only — you do not have permission to drop pins.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var gpsCard: some View {
        VineyardCard(padding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(gpsAvailable ? VineyardTheme.success.opacity(0.15) : VineyardTheme.warning.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: gpsAvailable ? "location.fill" : "location.slash")
                        .foregroundStyle(gpsAvailable ? VineyardTheme.success : VineyardTheme.warning)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(gpsAvailable ? "GPS Ready" : "Waiting for GPS…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VineyardTheme.textPrimary)
                    if let coord = locationService.location?.coordinate {
                        Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Pins will use manual paddock/row only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal)
    }

    private var gpsAvailable: Bool { locationService.location != nil }

    // MARK: - Location selection

    private var locationCard: some View {
        VineyardCard {
            VStack(alignment: .leading, spacing: 10) {
                VineyardSectionHeader(title: "Location", icon: "mappin.circle.fill", iconColor: VineyardTheme.olive)
                HStack {
                    Text("Paddock")
                        .foregroundStyle(VineyardTheme.textSecondary)
                    Spacer()
                    Picker("Paddock", selection: $selectedPaddockId) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.paddocks) { paddock in
                            Text(paddock.name).tag(UUID?.some(paddock.id))
                        }
                    }
                    .labelsHidden()
                    .tint(VineyardTheme.olive)
                }
                Divider()
                HStack {
                    Text("Row")
                        .foregroundStyle(VineyardTheme.textSecondary)
                    Spacer()
                    TextField("Optional", text: $rowText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Buttons grid

    private var buttonsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Tap to Drop Pin", icon: titleIcon, iconColor: titleColor)
                .padding(.horizontal, 24)

            VineyardCard(padding: 12) {
                if leftButtons.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No buttons configured")
                            .font(.subheadline.weight(.semibold))
                        if canEdit {
                            Button("Configure Buttons") { showEditButtons = true }
                                .buttonStyle(.vineyardSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    HStack(spacing: 10) {
                        VStack(spacing: 8) {
                            sideHeader("LEFT")
                            ForEach(leftButtons) { btn in
                                buttonTile(btn, side: .left)
                            }
                        }
                        VStack(spacing: 8) {
                            sideHeader("RIGHT")
                            ForEach(leftButtons) { btn in
                                buttonTile(btn, side: .right)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func sideHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private func buttonTile(_ btn: ButtonConfig, side: PinSide) -> some View {
        let isLightColor = ["yellow", "white", "cyan"].contains(btn.color.lowercased())
        return Button {
            handleTap(button: btn, side: side)
        } label: {
            HStack(spacing: 8) {
                if btn.isGrowthStageButton {
                    Image(systemName: "leaf.fill")
                        .font(.subheadline.weight(.bold))
                }
                Text(btn.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(isLightColor ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.fromString(btn.color).gradient, in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
        .opacity(canCreate ? 1 : 0.55)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VineyardCard {
            VStack(alignment: .leading, spacing: 8) {
                VineyardSectionHeader(title: "Notes", icon: "text.alignleft", iconColor: VineyardTheme.info)
                TextField("Optional", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func handleTap(button: ButtonConfig, side: PinSide) {
        guard canCreate else { return }

        if mode == .growth && button.isGrowthStageButton {
            pendingGrowthButton = button
            pendingSide = side
            showGrowthPicker = true
            return
        }

        guard let location = locationService.location else {
            showFeedback("Waiting for GPS location.", kind: .warning)
            return
        }

        let rowNumber = Int(rowText.trimmingCharacters(in: .whitespacesAndNewlines))
        store.createPinFromButton(
            button: button,
            coordinate: location.coordinate,
            heading: locationService.heading?.trueHeading ?? 0,
            side: side,
            paddockId: selectedPaddockId,
            rowNumber: rowNumber,
            createdBy: auth.userName,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )
        notes = ""
        showFeedback("Pin dropped: \(button.name) (\(side == .left ? "Left" : "Right"))", kind: .success)
    }

    private func handleGrowthStageSelected(_ stage: GrowthStage) {
        guard let location = locationService.location else {
            showFeedback("Waiting for GPS location.", kind: .warning)
            return
        }
        let rowNumber = Int(rowText.trimmingCharacters(in: .whitespacesAndNewlines))
        store.createGrowthStagePin(
            stageCode: stage.code,
            stageDescription: stage.description,
            coordinate: location.coordinate,
            heading: locationService.heading?.trueHeading ?? 0,
            side: pendingSide,
            paddockId: selectedPaddockId,
            rowNumber: rowNumber,
            createdBy: auth.userName,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        )
        notes = ""
        showFeedback("Growth pin: EL \(stage.code)", kind: .success)
    }

    private func showFeedback(_ message: String, kind: VineyardBadgeKind) {
        withAnimation(.snappy) {
            feedbackMessage = message
            feedbackKind = kind
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run {
                withAnimation(.easeOut) { feedbackMessage = nil }
            }
        }
    }
}
