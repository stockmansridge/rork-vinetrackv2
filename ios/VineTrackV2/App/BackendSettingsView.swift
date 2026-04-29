import SwiftUI

struct BackendSettingsView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @Environment(BackendAccessControl.self) private var accessControl
    @Environment(PinSyncService.self) private var pinSync
    @Environment(PaddockSyncService.self) private var paddockSync
    @Environment(TripSyncService.self) private var tripSync
    @Environment(SprayRecordSyncService.self) private var sprayRecordSync
    @Environment(ButtonConfigSyncService.self) private var buttonConfigSync

    @State private var showVineyardSwitcher: Bool = false
    @State private var showVineyardDetail: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var refreshMessage: String?

    #if DEBUG
    @State private var showBackendDiagnostic: Bool = false
    @State private var showStoreDiagnostic: Bool = false
    #endif

    private let vineyardRepository: any VineyardRepositoryProtocol = SupabaseVineyardRepository()

    private var pendingInvitationCount: Int {
        let userEmail = (auth.userEmail ?? "").lowercased()
        let memberIds = Set(store.vineyards.map { $0.id })
        return auth.pendingInvitations
            .filter { $0.status.lowercased() == "pending" }
            .filter { userEmail.isEmpty || $0.email.lowercased() == userEmail }
            .filter { !memberIds.contains($0.vineyardId) }
            .count
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                vineyardSection
                if let vineyard = store.selectedVineyard {
                    teamSection(vineyard: vineyard)
                }

                Section {
                    NavigationLink {
                        SetupManagementHubView()
                    } label: {
                        Label("Setup & Management", systemImage: "slider.horizontal.below.rectangle")
                    }
                    NavigationLink {
                        OperationsHubView()
                    } label: {
                        Label("Operations", systemImage: "rectangle.stack.fill")
                    }
                    NavigationLink {
                        PreferencesHubView()
                    } label: {
                        Label("Preferences", systemImage: "slider.horizontal.3")
                    }
                }

                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label("Sync", systemImage: "icloud.and.arrow.up")
                }

                accountPrivacySection
                aboutSection

                #if DEBUG
                debugSection
                #endif

                signOutSection
            }
            .navigationTitle("Settings")
            .refreshable { await refreshVineyards() }
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
            NavigationLink {
                EditDisplayNameView()
            } label: {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(auth.userName ?? "—")
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Email", value: auth.userEmail ?? "—")
        } header: {
            Text("Account")
        }
    }

    private var vineyardSection: some View {
        Section {
            if let vineyard = store.selectedVineyard {
                Button {
                    showVineyardDetail = true
                } label: {
                    HStack(spacing: 12) {
                        vineyardThumbnail(vineyard)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vineyard.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if !vineyard.country.isEmpty {
                                Text(vineyard.country)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("No vineyard selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showVineyardSwitcher = true
            } label: {
                HStack {
                    Label("Change Vineyard", systemImage: "arrow.triangle.swap")
                        .foregroundStyle(.primary)
                    Spacer()
                    let count = pendingInvitationCount
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                            .accessibilityLabel("\(count) pending invitations")
                    }
                }
            }
        } header: {
            Text("Vineyard")
        }
    }

    @ViewBuilder
    private func vineyardThumbnail(_ vineyard: Vineyard) -> some View {
        if let data = vineyard.logoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 8))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(VineyardTheme.leafGreen.gradient)
                    .frame(width: 40, height: 40)
                GrapeLeafIcon(size: 20, color: .white)
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
            Text("Team")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "\(appVersion) (\(appBuild))")
            LabeledContent("Disclaimer", value: "v\(DisclaimerInfo.version)")
            LabeledContent("Backend", value: SupabaseClientProvider.shared.isConfigured ? "Connected" : "Not configured")
        } header: {
            Text("About")
        }
    }

    private var accountPrivacySection: some View {
        Section {
            if let url = URL(string: "https://vinetrack.com.au/privacy") {
                Link(destination: url) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .foregroundStyle(.primary)
                }
            }
            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                Link(destination: url) {
                    Label("Terms of Use (EULA)", systemImage: "doc.text.fill")
                        .foregroundStyle(.primary)
                }
            }
            NavigationLink {
                DisclaimerInfoView()
            } label: {
                Label("Disclaimer", systemImage: "exclamationmark.shield.fill")
            }
            NavigationLink {
                AccountDeletionRequestView()
            } label: {
                Label("Request Account Deletion", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Account & Privacy")
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

// MARK: - Sync Settings (extracted)

struct SyncSettingsView: View {
    @Environment(PinSyncService.self) private var pinSync
    @Environment(PaddockSyncService.self) private var paddockSync
    @Environment(TripSyncService.self) private var tripSync
    @Environment(SprayRecordSyncService.self) private var sprayRecordSync
    @Environment(ButtonConfigSyncService.self) private var buttonConfigSync

    var body: some View {
        Form {
            Section {
                Button {
                    Task { await pinSync.syncPinsForSelectedVineyard() }
                } label: {
                    syncButtonLabel(title: "Sync Pins", icon: "mappin.and.ellipse", isSyncing: isSyncing(pinSync.syncStatus))
                }
                .disabled(isSyncing(pinSync.syncStatus))
                VineyardSyncStatusRow(label: "pins", state: pinStateFrom(pinSync.syncStatus, lastSync: pinSync.lastSyncDate))

                Button {
                    Task { await paddockSync.syncPaddocksForSelectedVineyard() }
                } label: {
                    syncButtonLabel(title: "Sync Paddocks", icon: "square.grid.2x2", isSyncing: isSyncing(paddockSync.syncStatus))
                }
                .disabled(isSyncing(paddockSync.syncStatus))
                VineyardSyncStatusRow(label: "paddocks", state: paddockStateFrom(paddockSync.syncStatus, lastSync: paddockSync.lastSyncDate))

                Button {
                    Task { await tripSync.syncTripsForSelectedVineyard() }
                } label: {
                    syncButtonLabel(title: "Sync Trips", icon: "map", isSyncing: isSyncing(tripSync.syncStatus))
                }
                .disabled(isSyncing(tripSync.syncStatus))
                VineyardSyncStatusRow(label: "trips", state: tripStateFrom(tripSync.syncStatus, lastSync: tripSync.lastSyncDate))

                Button {
                    Task { await sprayRecordSync.syncSprayRecordsForSelectedVineyard() }
                } label: {
                    syncButtonLabel(title: "Sync Spray Records", icon: "drop.fill", isSyncing: isSyncing(sprayRecordSync.syncStatus))
                }
                .disabled(isSyncing(sprayRecordSync.syncStatus))
                VineyardSyncStatusRow(label: "spray records", state: sprayStateFrom(sprayRecordSync.syncStatus, lastSync: sprayRecordSync.lastSyncDate))

                Button {
                    Task { await buttonConfigSync.syncButtonConfigForSelectedVineyard() }
                } label: {
                    syncButtonLabel(title: "Sync Button Config", icon: "square.grid.2x2", isSyncing: isSyncing(buttonConfigSync.syncStatus))
                }
                .disabled(isSyncing(buttonConfigSync.syncStatus))
                VineyardSyncStatusRow(label: "button config", state: buttonConfigStateFrom(buttonConfigSync.syncStatus, lastSync: buttonConfigSync.lastSyncDate))
            } footer: {
                Text("Pins, paddocks, trips, spray records, and button config sync to Supabase. Other data stays on this device for now.")
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func syncButtonLabel(title: String, icon: String, isSyncing: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            if isSyncing { ProgressView() }
        }
    }

    private func isSyncing(_ status: PinSyncService.Status) -> Bool { if case .syncing = status { return true }; return false }
    private func isSyncing(_ status: PaddockSyncService.Status) -> Bool { if case .syncing = status { return true }; return false }
    private func isSyncing(_ status: TripSyncService.Status) -> Bool { if case .syncing = status { return true }; return false }
    private func isSyncing(_ status: SprayRecordSyncService.Status) -> Bool { if case .syncing = status { return true }; return false }
    private func isSyncing(_ status: ButtonConfigSyncService.Status) -> Bool { if case .syncing = status { return true }; return false }

    private func pinStateFrom(_ status: PinSyncService.Status, lastSync: Date?) -> VineyardSyncState {
        switch status {
        case .idle: return .idle
        case .syncing: return .syncing
        case .success: return .success(lastSync)
        case .failure(let m): return .failure(m)
        }
    }
    private func tripStateFrom(_ status: TripSyncService.Status, lastSync: Date?) -> VineyardSyncState {
        switch status {
        case .idle: return .idle
        case .syncing: return .syncing
        case .success: return .success(lastSync)
        case .failure(let m): return .failure(m)
        }
    }
    private func paddockStateFrom(_ status: PaddockSyncService.Status, lastSync: Date?) -> VineyardSyncState {
        switch status {
        case .idle: return .idle
        case .syncing: return .syncing
        case .success: return .success(lastSync)
        case .failure(let m): return .failure(m)
        }
    }
    private func sprayStateFrom(_ status: SprayRecordSyncService.Status, lastSync: Date?) -> VineyardSyncState {
        switch status {
        case .idle: return .idle
        case .syncing: return .syncing
        case .success: return .success(lastSync)
        case .failure(let m): return .failure(m)
        }
    }
    private func buttonConfigStateFrom(_ status: ButtonConfigSyncService.Status, lastSync: Date?) -> VineyardSyncState {
        switch status {
        case .idle: return .idle
        case .syncing: return .syncing
        case .success: return .success(lastSync)
        case .failure(let m): return .failure(m)
        }
    }
}
