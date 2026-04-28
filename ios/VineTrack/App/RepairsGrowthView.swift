import SwiftUI
import CoreLocation

struct RepairsGrowthView: View {
    enum Tab: Int, Hashable { case repairs = 0, growth = 1 }

    @Environment(MigratedDataStore.self) private var store
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(LocationService.self) private var locationService
    @Environment(BackendAccessControl.self) private var accessControl

    @State private var selection: Tab
    @State private var showEditButtons: Bool = false
    @State private var showGrowthPicker: Bool = false
    @State private var lastGrowthStage: GrowthStage?
    @State private var feedbackMessage: String?
    @State private var feedbackKind: VineyardBadgeKind = .success

    init(initial: Tab = .repairs) {
        _selection = State(initialValue: initial)
    }

    private var canCreate: Bool { accessControl.canCreateOperationalRecords }
    private var canEdit: Bool { accessControl.canChangeSettings }

    private var repairButtons: [ButtonConfig] {
        store.repairButtons
            .filter { !$0.isGrowthStageButton }
            .sorted { $0.index < $1.index }
    }

    private var growthButtons: [ButtonConfig] {
        let nonGrowthStage = store.growthButtons
            .filter { !$0.isGrowthStageButton }
            .sorted { $0.index < $1.index }
        var seen = Set<String>()
        var unique: [ButtonConfig] = []
        for btn in nonGrowthStage {
            let key = btn.name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(btn)
            }
        }
        return Array(unique.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            segmentHeader
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

            TabView(selection: $selection) {
                repairsPage
                    .tag(Tab.repairs)
                growthPage
                    .tag(Tab.growth)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: selection)

            if let feedbackMessage {
                FeedbackBar(message: feedbackMessage, kind: feedbackKind)
                    .padding(.bottom, 8)
            }
        }
        .background(VineyardTheme.appBackground)
        .navigationTitle(store.selectedVineyard?.name ?? "Vineyard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditButtons = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditButtons) {
            EditButtonsSheet(mode: selection == .repairs ? .repairs : .growth)
        }
        .sheet(isPresented: $showGrowthPicker) {
            GrowthStagePickerSheet { stage in
                handleGrowthStageSelected(stage)
            }
        }
    }

    // MARK: - Segmented header

    private var segmentHeader: some View {
        HStack(spacing: 8) {
            segmentButton(title: "Repairs", tab: .repairs)
            segmentButton(title: "Growth", tab: .growth)
        }
        .padding(4)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private func segmentButton(title: String, tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selection = tab }
        } label: {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(selection == tab ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selection == tab ? VineyardTheme.primary : Color.clear,
                    in: .rect(cornerRadius: 9)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Repairs page

    private var repairsPage: some View {
        VStack(spacing: 0) {
            if !canCreate { PermissionRow().padding(.bottom, 6) }
            if repairButtons.isEmpty {
                EmptyButtonsState(canEdit: canEdit, showEditButtons: $showEditButtons)
                    .padding(.horizontal)
                    .padding(.top, 12)
                Spacer()
            } else {
                fillingButtonGrid(buttons: repairButtons) { btn in
                    handleTap(button: btn, side: .right)
                }
            }
        }
    }

    // MARK: - Growth page

    private var growthPage: some View {
        VStack(spacing: 10) {
            if !canCreate { PermissionRow() }
            growthStageBar
                .padding(.horizontal)

            if growthButtons.isEmpty {
                EmptyButtonsState(canEdit: canEdit, showEditButtons: $showEditButtons)
                    .padding(.horizontal)
                Spacer()
            } else {
                fillingButtonGrid(buttons: growthButtons) { btn in
                    handleTap(button: btn, side: .right)
                }
            }
        }
        .padding(.top, 4)
    }

    private var growthStageBar: some View {
        Button {
            showGrowthPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3.weight(.bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Growth Stage")
                        .font(.headline.weight(.bold))
                    if let stage = lastGrowthStage {
                        Text("EL \(stage.code) — \(stage.description)")
                            .font(.caption)
                            .lineLimit(1)
                            .opacity(0.9)
                    } else {
                        Text("Tap to select current E-L stage")
                            .font(.caption)
                            .opacity(0.9)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.55, blue: 0.28), Color(red: 0.12, green: 0.42, blue: 0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
    }

    // MARK: - Filling grid

    private func fillingButtonGrid(buttons: [ButtonConfig], onTap: @escaping (ButtonConfig) -> Void) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(buttons) { btn in
                FillingActionTile(button: btn, side: .right, canCreate: canCreate) {
                    onTap(btn)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    // MARK: - Actions

    private func handleTap(button: ButtonConfig, side: PinSide) {
        guard canCreate else { return }
        guard let location = locationService.location else {
            showFeedback("Waiting for GPS location.", kind: .warning)
            return
        }
        store.createPinFromButton(
            button: button,
            coordinate: location.coordinate,
            heading: locationService.heading?.trueHeading ?? 0,
            side: side,
            paddockId: nil,
            rowNumber: nil,
            createdBy: auth.userName,
            notes: nil
        )
        showFeedback("Pin: \(button.name) (\(side == .left ? "L" : "R"))", kind: .success)
    }

    private func handleGrowthStageSelected(_ stage: GrowthStage) {
        guard let location = locationService.location else {
            showFeedback("Waiting for GPS location.", kind: .warning)
            return
        }
        lastGrowthStage = stage
        store.createGrowthStagePin(
            stageCode: stage.code,
            stageDescription: stage.description,
            coordinate: location.coordinate,
            heading: locationService.heading?.trueHeading ?? 0,
            side: .right,
            paddockId: nil,
            rowNumber: nil,
            createdBy: auth.userName,
            notes: nil
        )
        showFeedback("Growth pin: EL \(stage.code)", kind: .success)
    }

    private func showFeedback(_ message: String, kind: VineyardBadgeKind) {
        withAnimation(.snappy) {
            feedbackMessage = message
            feedbackKind = kind
        }
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run {
                withAnimation(.easeOut) { feedbackMessage = nil }
            }
        }
    }
}

// MARK: - Filling tile (uses pin drop icon)

struct FillingActionTile: View {
    let button: ButtonConfig
    let side: PinSide
    let canCreate: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title.weight(.semibold))
                Text(button.name)
                    .font(.title3.weight(.heavy))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.fromString(button.color), Color.fromString(button.color).opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.black.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
        .opacity(canCreate ? 1 : 0.55)
    }

    private var foreground: Color {
        let isLightColor = ["yellow", "white", "cyan"].contains(button.color.lowercased())
        return isLightColor ? .black : .white
    }
}
