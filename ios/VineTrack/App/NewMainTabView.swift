import SwiftUI
import CoreLocation

struct NewMainTabView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @Environment(LocationService.self) private var locationService
    @Environment(BackendAccessControl.self) private var accessControl
    @Environment(TripTrackingService.self) private var tripTracking
    @Environment(PinSyncService.self) private var pinSync
    @Environment(PaddockSyncService.self) private var paddockSync
    @Environment(TripSyncService.self) private var tripSync
    @Environment(SprayRecordSyncService.self) private var sprayRecordSync
    @Environment(ButtonConfigSyncService.self) private var buttonConfigSync
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NewHomeTabView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                PinsView()
            }
            .tabItem { Label("Pins", systemImage: "mappin.and.ellipse") }

            NavigationStack {
                TripView()
            }
            .tabItem { Label("Trip", systemImage: "steeringwheel") }

            NavigationStack {
                SprayProgramView()
            }
            .tabItem { Label("Program", systemImage: "sprinkler.and.droplets.fill") }

            BackendSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environment(\.accessControl, accessControl.legacyAccessControl)
        .onAppear {
            if locationService.authorizationStatus == .notDetermined {
                locationService.requestPermission()
            } else if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                locationService.startUpdating()
            }
            tripTracking.configure(store: store, locationService: locationService)
            pinSync.configure(store: store, auth: auth)
            paddockSync.configure(store: store, auth: auth)
            tripSync.configure(store: store, auth: auth)
            sprayRecordSync.configure(store: store, auth: auth)
            buttonConfigSync.configure(store: store, auth: auth)
        }
        .task(id: store.selectedVineyardId) {
            await accessControl.refresh(for: store.selectedVineyardId, auth: auth)
            await pinSync.syncPinsForSelectedVineyard()
            await paddockSync.syncPaddocksForSelectedVineyard()
            await tripSync.syncTripsForSelectedVineyard()
            await sprayRecordSync.syncSprayRecordsForSelectedVineyard()
            await buttonConfigSync.syncButtonConfigForSelectedVineyard()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await pinSync.syncPinsForSelectedVineyard()
                    await paddockSync.syncPaddocksForSelectedVineyard()
                    await tripSync.syncTripsForSelectedVineyard()
                    await sprayRecordSync.syncSprayRecordsForSelectedVineyard()
                    await buttonConfigSync.syncButtonConfigForSelectedVineyard()
                }
            }
        }
    }
}

// MARK: - Home Tab

private struct NewHomeTabView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @Environment(BackendAccessControl.self) private var accessControl
    @Environment(TripTrackingService.self) private var tripTracking

    @State private var showQuickPin: Bool = false
    @State private var showStartTrip: Bool = false
    #if DEBUG
    @State private var showBackendDiagnostic: Bool = false
    @State private var showStoreDiagnostic: Bool = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    if tripTracking.activeTrip != nil {
                        ActiveTripCard()
                            .padding(.horizontal)
                    }
                    if accessControl.canCreateOperationalRecords {
                        quickActionsSection
                    }
                    operationsSection
                    managementSection
                    summarySection
                    #if DEBUG
                    debugSection
                    #endif
                    Spacer(minLength: 24)
                }
                .padding(.vertical)
            }
            .background(VineyardTheme.appBackground)
            .navigationTitle("Home")
            .sheet(isPresented: $showQuickPin) {
                QuickPinSheet()
            }
            .sheet(isPresented: $showStartTrip) {
                StartTripSheet()
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

    // MARK: Header

    private var headerCard: some View {
        VineyardCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VineyardTheme.leafGreen.gradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedVineyard?.name ?? "No Vineyard")
                        .font(.headline)
                        .foregroundStyle(VineyardTheme.textPrimary)
                    Text(auth.userName ?? auth.userEmail ?? "Signed in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let role = accessControl.currentRole {
                    VineyardStatusBadge(text: role.rawValue.capitalized, kind: .info)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Quick Actions", icon: "bolt.fill", iconColor: .orange)
                .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    RepairsGrowthView(initial: .repairs)
                } label: {
                    quickActionTileLabel(title: "Repairs", icon: "wrench.fill", colors: [.orange, Color.orange.opacity(0.75)])
                }
                .buttonStyle(.plain)
                NavigationLink {
                    RepairsGrowthView(initial: .growth)
                } label: {
                    quickActionTileLabel(title: "Growth", icon: "leaf.fill", colors: [VineyardTheme.leafGreen, VineyardTheme.olive])
                }
                .buttonStyle(.plain)
                Button {
                    showStartTrip = true
                } label: {
                    quickActionTileLabel(title: "Start Trip", icon: "steeringwheel", colors: [.blue, Color.blue.opacity(0.75)])
                }
                .buttonStyle(.plain)
                NavigationLink {
                    SprayProgramView()
                } label: {
                    quickActionTileLabel(title: "Spray Program", icon: "sprinkler.and.droplets.fill", colors: [.purple, Color.purple.opacity(0.75)])
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    private func quickActionTileLabel(title: String, icon: String, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 16)
        )
        .shadow(color: colors.first?.opacity(0.25) ?? .clear, radius: 4, y: 2)
    }

    // MARK: Operational Tools

    private var operationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Operational Tools", icon: "wrench.and.screwdriver.fill", iconColor: VineyardTheme.earthBrown)
                .padding(.horizontal, 24)

            VineyardCard(padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink {
                        WorkTasksHubView()
                    } label: {
                        hubRow(title: "Work Tasks", subtitle: "\(store.workTasks.count) tasks", icon: "person.2.badge.gearshape.fill", tint: .indigo)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        MaintenanceLogListView()
                    } label: {
                        hubRow(title: "Maintenance Log", subtitle: "\(store.maintenanceLogs.count) logs", icon: "wrench.and.screwdriver.fill", tint: VineyardTheme.earthBrown)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        GrowthStageReportView()
                    } label: {
                        hubRow(title: "Growth Stage Report", subtitle: "Phenology & E-L", icon: "chart.line.uptrend.xyaxis", tint: VineyardTheme.leafGreen)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        YieldHubView()
                    } label: {
                        hubRow(title: "Yield Estimation", subtitle: "Estimates & harvest", icon: "chart.bar.fill", tint: .orange)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        OperationsHubView()
                    } label: {
                        hubRow(title: "Irrigation Advisor", subtitle: "Water guidance", icon: "drop.fill", tint: .cyan)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        YieldHubView()
                    } label: {
                        hubRow(title: "Yield Determination", subtitle: "Final weight", icon: "scalemass.fill", tint: .purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Management

    @ViewBuilder
    private var managementSection: some View {
        if accessControl.canChangeSettings {
            VStack(alignment: .leading, spacing: 8) {
                VineyardSectionHeader(title: "Management", icon: "person.2.fill", iconColor: .blue)
                    .padding(.horizontal, 24)

                VineyardCard(padding: 0) {
                    VStack(spacing: 0) {
                        if let vineyard = store.selectedVineyard {
                            NavigationLink {
                                BackendTeamAccessView(vineyardId: vineyard.id, vineyardName: vineyard.name)
                            } label: {
                                hubRow(title: "Manage Users", subtitle: "Team & roles", icon: "person.2.fill", tint: .blue)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 60)
                        }
                        NavigationLink {
                            BlocksHubView()
                        } label: {
                            hubRow(title: "Vineyard Setup", subtitle: "Blocks, varieties, settings", icon: "gearshape.2.fill", tint: .gray)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            OperationsHubView()
                        } label: {
                            hubRow(title: "Audit Log", subtitle: "Activity history", icon: "doc.text.magnifyingglass", tint: .pink)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            OperationsHubView()
                        } label: {
                            hubRow(title: "Full Overview", subtitle: "Complete vineyard report", icon: "chart.pie.fill", tint: VineyardTheme.olive)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Recent", icon: "clock.fill", iconColor: .secondary)
                .padding(.horizontal, 24)

            VineyardCard {
                VStack(spacing: 10) {
                    summaryRow("Pins", value: store.pins.count, icon: "mappin.circle.fill", tint: .red)
                    Divider()
                    summaryRow("Trips", value: store.trips.count, icon: "map.fill", tint: .blue)
                    Divider()
                    summaryRow("Spray records", value: store.sprayRecords.count, icon: "sprinkler.and.droplets.fill", tint: .purple)
                    Divider()
                    summaryRow("Paddocks", value: store.paddocks.count, icon: "square.grid.2x2.fill", tint: VineyardTheme.leafGreen)
                }
            }
            .padding(.horizontal)
        }
    }

    private func summaryRow(_ label: String, value: Int, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label)
                .foregroundStyle(VineyardTheme.textPrimary)
            Spacer()
            Text("\(value)")
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func hubRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(VineyardTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Debug", icon: "stethoscope", iconColor: .gray)
                .padding(.horizontal, 24)
            VineyardCard(padding: 0) {
                VStack(spacing: 0) {
                    Button {
                        showBackendDiagnostic = true
                    } label: {
                        hubRow(title: "Backend Diagnostic", subtitle: "Inspect Supabase state", icon: "stethoscope", tint: .gray)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    Button {
                        showStoreDiagnostic = true
                    } label: {
                        hubRow(title: "MigratedDataStore", subtitle: "Local storage", icon: "tray.full", tint: .gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    #endif
}
