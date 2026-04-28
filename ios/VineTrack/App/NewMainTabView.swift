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
        .tint(VineyardTheme.olive)
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
                    setupSection
                    operationsSection
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
                    RepairsActionView()
                } label: {
                    quickActionLabel(title: "Repairs", icon: "wrench.and.screwdriver.fill", tint: VineyardTheme.earthBrown)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    GrowthObservationActionView()
                } label: {
                    quickActionLabel(title: "Growth", icon: "leaf.fill", tint: VineyardTheme.leafGreen)
                }
                .buttonStyle(.plain)
                quickActionTile(title: "Drop Pin", icon: "mappin.and.ellipse", tint: VineyardTheme.olive) {
                    showQuickPin = true
                }
                quickActionTile(title: "Start Trip", icon: "steeringwheel", tint: VineyardTheme.leafGreen) {
                    showStartTrip = true
                }
                NavigationLink {
                    SprayProgramView()
                } label: {
                    quickActionLabel(title: "Spray Program", icon: "sprinkler.and.droplets.fill", tint: VineyardTheme.info)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    WorkTasksHubView()
                } label: {
                    quickActionLabel(title: "Work Tasks", icon: "checklist", tint: VineyardTheme.warning)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    private func quickActionTile(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(title: title, icon: icon, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func quickActionLabel(title: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.headline)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VineyardTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(VineyardTheme.cardBackground, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VineyardTheme.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: Setup

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Vineyard Setup", icon: "square.grid.2x2.fill", iconColor: VineyardTheme.leafGreen)
                .padding(.horizontal, 24)

            VineyardCard(padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink {
                        BlocksHubView()
                    } label: {
                        hubRow(title: "Blocks", subtitle: "\(store.paddocks.count) paddocks", icon: "square.grid.2x2.fill", tint: VineyardTheme.leafGreen)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        GrapeVarietyManagementView()
                    } label: {
                        hubRow(title: "Grape Varieties", subtitle: "Variety library", icon: "leaf.fill", tint: VineyardTheme.olive)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Operations

    private var operationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Operations", icon: "wrench.and.screwdriver.fill", iconColor: VineyardTheme.earthBrown)
                .padding(.horizontal, 24)

            VineyardCard(padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink {
                        OperationsHubView()
                    } label: {
                        hubRow(title: "Operations Hub", subtitle: "Work, maintenance, yield", icon: "rectangle.stack.fill", tint: VineyardTheme.olive)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        WorkTasksHubView()
                    } label: {
                        hubRow(title: "Work Tasks", subtitle: "\(store.workTasks.count) tasks", icon: "checklist", tint: VineyardTheme.warning)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        MaintenanceLogListView()
                    } label: {
                        hubRow(title: "Maintenance", subtitle: "\(store.maintenanceLogs.count) logs", icon: "wrench.and.screwdriver.fill", tint: VineyardTheme.earthBrown)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        YieldHubView()
                    } label: {
                        hubRow(title: "Yield & Damage", subtitle: "Estimates & harvest", icon: "scalemass.fill", tint: VineyardTheme.vineRed)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 60)
                    NavigationLink {
                        GrowthStageReportView()
                    } label: {
                        hubRow(title: "Growth Stage", subtitle: "Phenology & E-L", icon: "leaf.arrow.triangle.circlepath", tint: VineyardTheme.leafGreen)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VineyardSectionHeader(title: "Summary", icon: "chart.bar.fill", iconColor: VineyardTheme.info)
                .padding(.horizontal, 24)

            VineyardCard {
                VStack(spacing: 10) {
                    summaryRow("Pins", value: store.pins.count, icon: "mappin.circle.fill", tint: VineyardTheme.olive)
                    Divider()
                    summaryRow("Trips", value: store.trips.count, icon: "map.fill", tint: VineyardTheme.leafGreen)
                    Divider()
                    summaryRow("Spray records", value: store.sprayRecords.count, icon: "sprinkler.and.droplets.fill", tint: VineyardTheme.info)
                    Divider()
                    summaryRow("Paddocks", value: store.paddocks.count, icon: "square.grid.2x2.fill", tint: VineyardTheme.olive)
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
