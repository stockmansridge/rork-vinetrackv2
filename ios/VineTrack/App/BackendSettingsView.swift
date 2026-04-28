import SwiftUI

struct BackendSettingsView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @Environment(BackendAccessControl.self) private var accessControl
    @Environment(PinSyncService.self) private var pinSync
    @Environment(PaddockSyncService.self) private var paddockSync

    @State private var showVineyardSwitcher: Bool = false
    @State private var showVineyardDetail: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var refreshMessage: String?

    #if DEBUG
    @State private var showBackendDiagnostic: Bool = false
    @State private var showStoreDiagnostic: Bool = false
    #endif

    private let vineyardRepository: any VineyardRepositoryProtocol = SupabaseVineyardRepository()

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                vineyardSection
                if let vineyard = store.selectedVineyard {
                    teamSection(vineyard: vineyard)
                }
                if accessControl.canChangeSettings {
                    managementSection
                }
                syncSection
                appSettingsSection
                aboutSection

                #if DEBUG
                debugSection
                #endif

                signOutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showVineyardSwitcher) {
                BackendVineyardListView()
            }
            .sheet(isPresented: $showVineyardDetail) {
                if let vineyard = store.selectedVineyard {
                    BackendVineyardDetailSheet(vineyard: vineyard)
                }
            }
            #if DEBUG
            .sheet(isPresented: $showBackendDiagnostic) {
                BackendDiagnosticHostView()
            }
            .sheet(isPresented: $showStoreDiagnostic) {
                MigratedDataStoreDiagnosticView()
            }
            #endif
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section {
            LabeledContent("Name", value: auth.userName ?? "—")
            LabeledContent("Email", value: auth.userEmail ?? "—")
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.gray)
                    .font(.caption)
                Text("Account")
            }
        }
    }

    private var vineyardSection: some View {
        Section {
            if let vineyard = store.selectedVineyard {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VineyardTheme.leafGreen.gradient)
                            .frame(width: 40, height: 40)
                        Image(systemName: "leaf.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vineyard.name)
                            .font(.headline)
                        if !vineyard.country.isEmpty {
                            Text(vineyard.country)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            } else {
                Text("No vineyard selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showVineyardSwitcher = true
            } label: {
                Label("Switch Vineyard", systemImage: "arrow.triangle.swap")
                    .foregroundStyle(.primary)
            }

            if store.selectedVineyard != nil {
                Button {
                    showVineyardDetail = true
                } label: {
                    Label("Edit Vineyard", systemImage: "pencil")
                        .foregroundStyle(.primary)
                }
            }

            Button {
                Task { await refreshVineyards() }
            } label: {
                HStack {
                    Label("Refresh Vineyards", systemImage: "arrow.clockwise")
                        .foregroundStyle(.primary)
                    Spacer()
                    if isRefreshing { ProgressView() }
                }
            }
            .disabled(isRefreshing)

            if let refreshMessage {
                Text(refreshMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(VineyardTheme.leafGreen)
                    .font(.caption)
                Text("Vineyard")
            }
        }
    }

    private func teamSection(vineyard: Vineyard) -> some View {
        Section {
            NavigationLink {
                BackendTeamAccessView(vineyardId: vineyard.id, vineyardName: vineyard.name)
            } label: {
                Label("Team & Access", systemImage: "person.2.fill")
            }

            NavigationLink {
                RolesPermissionsInfoView()
            } label: {
                Label("Roles & Permissions", systemImage: "person.badge.shield.checkmark.fill")
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.purple)
                    .font(.caption)
                Text("Team")
            }
        }
    }

    private var managementSection: some View {
        Section {
            NavigationLink {
                SprayManagementSettingsView()
            } label: {
                Label("Spray Management", systemImage: "flask.fill")
            }
            NavigationLink {
                EquipmentManagementView()
            } label: {
                Label("Equipment & Tractors", systemImage: "wrench.and.screwdriver")
            }
            NavigationLink {
                OperatorCategoriesView()
            } label: {
                Label("Operators & Costs", systemImage: "person.badge.clock")
            }
            NavigationLink {
                GrapeVarietyManagementView()
            } label: {
                Label("Grape Varieties", systemImage: "leaf.fill")
            }
            NavigationLink {
                ButtonsAndQuickActionsView()
            } label: {
                Label("Buttons & Quick Actions", systemImage: "square.grid.2x2")
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.below.rectangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Management")
            }
        } footer: {
            Text("Manage saved chemicals, equipment, operators, varieties, and button workflows.")
        }
    }

    private var syncSection: some View {
        Section {
            Button {
                Task { await pinSync.syncPinsForSelectedVineyard() }
            } label: {
                HStack {
                    Label("Sync Pins", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.primary)
                    Spacer()
                    if case .syncing = pinSync.syncStatus {
                        ProgressView()
                    }
                }
            }
            .disabled({ if case .syncing = pinSync.syncStatus { return true } else { return false } }())

            syncStatusLine(label: "pins", status: pinSync.syncStatus, lastSync: pinSync.lastSyncDate)

            Button {
                Task { await paddockSync.syncPaddocksForSelectedVineyard() }
            } label: {
                HStack {
                    Label("Sync Paddocks", systemImage: "square.grid.2x2")
                        .foregroundStyle(.primary)
                    Spacer()
                    if case .syncing = paddockSync.syncStatus {
                        ProgressView()
                    }
                }
            }
            .disabled({ if case .syncing = paddockSync.syncStatus { return true } else { return false } }())

            syncStatusLine(label: "paddocks", status: paddockSync.syncStatus, lastSync: paddockSync.lastSyncDate)
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text("Sync")
            }
        } footer: {
            Text("Pins and paddocks sync to Supabase. Other data stays on this device for now.")
        }
    }

    @ViewBuilder
    private func syncStatusLine(label: String, status: PinSyncService.Status, lastSync: Date?) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .syncing:
            Text("Syncing \(label)\u{2026}")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success:
            if let lastSync {
                Text("Last synced \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failure(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func syncStatusLine(label: String, status: PaddockSyncService.Status, lastSync: Date?) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .syncing:
            Text("Syncing \(label)\u{2026}")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .success:
            if let lastSync {
                Text("Last synced \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failure(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var appSettingsSection: some View {
        Section {
            NavigationLink {
                CalculationSettingsView()
            } label: {
                Label("Canopy Water Rates", systemImage: "drop.triangle.fill")
            }

            NavigationLink {
                YieldSettingsView()
            } label: {
                Label("Yield Settings", systemImage: "scalemass")
            }

            NavigationLink {
                LocalPreferencesView()
            } label: {
                Label("Preferences", systemImage: "slider.horizontal.3")
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.indigo)
                    .font(.caption)
                Text("App Settings")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "\(appVersion) (\(appBuild))")
        } header: {
            Text("About")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button {
                showBackendDiagnostic = true
            } label: {
                Label("Backend Diagnostic", systemImage: "stethoscope")
            }
            Button {
                showStoreDiagnostic = true
            } label: {
                Label("MigratedDataStore Diagnostic", systemImage: "tray.full")
            }
        } header: {
            Text("Diagnostics")
        }
    }
    #endif

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                Task {
                    await auth.signOut()
                    store.clearInMemoryState()
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func refreshVineyards() async {
        isRefreshing = true
        refreshMessage = nil
        defer { isRefreshing = false }
        do {
            let backendVineyards = try await vineyardRepository.listMyVineyards()
            store.mapBackendVineyardsIntoLocal(backendVineyards)
            refreshMessage = "Loaded \(backendVineyards.count) vineyard\(backendVineyards.count == 1 ? "" : "s")."
        } catch {
            refreshMessage = error.localizedDescription
        }
    }
}

// MARK: - Local Preferences

private struct LocalPreferencesView: View {
    @Environment(MigratedDataStore.self) private var store
    @State private var samplesPerHectareText: String = ""
    @State private var fillTimerEnabled: Bool = true
    @State private var elConfirmationEnabled: Bool = true
    @State private var seasonFuelCostText: String = ""
    @State private var showGrowthStages: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Spray Fill Timer", isOn: $fillTimerEnabled)
                    .onChange(of: fillTimerEnabled) { _, newValue in
                        var s = store.settings
                        s.fillTimerEnabled = newValue
                        store.updateSettings(s)
                    }

                Toggle("Confirm E-L Stage", isOn: $elConfirmationEnabled)
                    .onChange(of: elConfirmationEnabled) { _, newValue in
                        var s = store.settings
                        s.elConfirmationEnabled = newValue
                        store.updateSettings(s)
                    }
            } header: {
                Text("Behaviour")
            }

            Section {
                HStack {
                    Text("Samples per Hectare")
                    Spacer()
                    TextField("0", text: $samplesPerHectareText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onSubmit { saveSamples() }
                }

                HStack {
                    Text("Fuel Cost (per L)")
                    Spacer()
                    TextField("0", text: $seasonFuelCostText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onSubmit { saveFuelCost() }
                }
            } header: {
                Text("Defaults")
            }

            Section {
                Button {
                    showGrowthStages = true
                } label: {
                    HStack {
                        Label("Enabled E-L Stages", systemImage: "leaf.arrow.triangle.circlepath")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(store.settings.enabledGrowthStageCodes.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    GrowthStageImagesSettingsView()
                } label: {
                    Label("E-L Stage Images", systemImage: "photo.on.rectangle.angled")
                }
                NavigationLink {
                    GrowthStageReportView()
                } label: {
                    Label("Growth Stage Report", systemImage: "chart.bar.doc.horizontal")
                }
            } header: {
                Text("Phenology")
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGrowthStages) {
            GrowthStageConfigSheet()
        }
        .onAppear {
            samplesPerHectareText = String(store.settings.samplesPerHectare)
            fillTimerEnabled = store.settings.fillTimerEnabled
            elConfirmationEnabled = store.settings.elConfirmationEnabled
            seasonFuelCostText = String(format: "%.2f", store.settings.seasonFuelCostPerLitre)
        }
    }

    private func saveSamples() {
        guard let v = Int(samplesPerHectareText), v > 0 else { return }
        var s = store.settings
        s.samplesPerHectare = v
        store.updateSettings(s)
    }

    private func saveFuelCost() {
        guard let v = Double(seasonFuelCostText), v >= 0 else { return }
        var s = store.settings
        s.seasonFuelCostPerLitre = v
        store.updateSettings(s)
    }
}
