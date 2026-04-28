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
    @State private var showTripChoice: Bool = false
    @State private var showStartTrip: Bool = false
    @State private var showSpraySetup: Bool = false
    #if DEBUG
    @State private var showBackendDiagnostic: Bool = false
    @State private var showStoreDiagnostic: Bool = false
    #endif

    @State private var showVineyardDetail: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    titleHeader
                    if tripTracking.activeTrip != nil {
                        ActiveTripCard()
                            .padding(.horizontal)
                    }
                    todaySection
                    vineyardOverviewSection
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showVineyardDetail) {
                if let vineyard = store.selectedVineyard {
                    BackendVineyardDetailSheet(vineyard: vineyard)
                }
            }
            .sheet(isPresented: $showQuickPin) {
                QuickPinSheet()
            }
            .sheet(isPresented: $showTripChoice) {
                TripTypeChoiceSheet { type in
                    showTripChoice = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        switch type {
                        case .maintenance:
                            showStartTrip = true
                        case .spray:
                            showSpraySetup = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showStartTrip) {
                StartTripSheet()
            }
            .sheet(isPresented: $showSpraySetup) {
                SprayTripSetupSheet()
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

    private var titleHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(VineyardTheme.leafGreen.gradient)
                    .frame(width: 40, height: 40)
                GrapeVineLeafShape()
                    .fill(.white)
                    .frame(width: 22, height: 22)
            }
            Text(store.selectedVineyard?.name ?? "No Vineyard")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func plainSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    // MARK: Today

    private var pinsNeedingAttention: Int {
        store.pins.filter { !$0.isCompleted }.count
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            plainSectionHeader("Today")
            VineyardCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(pinsNeedingAttention) pin\(pinsNeedingAttention == 1 ? "" : "s") need attention")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(pinsNeedingAttention == 0 ? "All caught up" : "Open the Pins tab to review")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Vineyard Overview

    private var vineyardOverviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            plainSectionHeader("Vineyard Overview")
            Button {
                if store.selectedVineyard != nil {
                    showVineyardDetail = true
                }
            } label: {
                VineyardCard {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(VineyardTheme.leafGreen.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: "map.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(VineyardTheme.leafGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.selectedVineyard?.name ?? "No vineyard selected")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(store.paddocks.count) block\(store.paddocks.count == 1 ? "" : "s") \u{2022} View map & summary")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            plainSectionHeader("Quick Actions")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    RepairsGrowthView(initial: .repairs)
                } label: {
                    quickActionTileLabel(title: "Repairs", systemIcon: "wrench.fill", colors: [.orange, Color.orange.opacity(0.75)])
                }
                .buttonStyle(.plain)
                NavigationLink {
                    RepairsGrowthView(initial: .growth)
                } label: {
                    quickActionTileLabel(title: "Growth", grapeLeaf: true, colors: [VineyardTheme.leafGreen, VineyardTheme.darkGreen])
                }
                .buttonStyle(.plain)
                Button {
                    showTripChoice = true
                } label: {
                    quickActionTileLabel(title: "Start Trip", systemIcon: "steeringwheel", colors: [.blue, Color.blue.opacity(0.75)])
                }
                .buttonStyle(.plain)
                NavigationLink {
                    SprayProgramView()
                } label: {
                    quickActionTileLabel(title: "Spray Program", systemIcon: "sprinkler.and.droplets.fill", colors: [.purple, Color.purple.opacity(0.75)])
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    private func quickActionTileLabel(title: String, systemIcon: String? = nil, grapeLeaf: Bool = false, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if grapeLeaf {
                    GrapeVineLeafShape()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                } else if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            plainSectionHeader("Operational Tools")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    WorkTasksHubView()
                } label: {
                    iconTile(title: "Work Tasks", icon: "person.2.badge.gearshape.fill", tint: .indigo)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    MaintenanceLogListView()
                } label: {
                    iconTile(title: "Maintenance Log", icon: "wrench.and.screwdriver.fill", tint: VineyardTheme.earthBrown)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    GrowthStageReportView()
                } label: {
                    iconTile(title: "Growth Stage Report", icon: "chart.line.uptrend.xyaxis", tint: VineyardTheme.leafGreen)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    YieldHubView()
                } label: {
                    iconTile(title: "Yield Estimation", icon: "chart.bar.fill", tint: .orange)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    OperationsHubView()
                } label: {
                    iconTile(title: "Irrigation Advisor", icon: "drop.fill", tint: .cyan)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    YieldHubView()
                } label: {
                    iconTile(title: "Yield Determination", icon: "scalemass.fill", tint: .purple)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    private func iconTile(title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(tint.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 14)
        .background(VineyardTheme.cardBackground, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VineyardTheme.cardBorder, lineWidth: 0.5)
        )
    }

    // MARK: Management

    @ViewBuilder
    private var managementSection: some View {
        if accessControl.canChangeSettings {
            VStack(alignment: .leading, spacing: 10) {
                plainSectionHeader("Management")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let vineyard = store.selectedVineyard {
                        NavigationLink {
                            BackendTeamAccessView(vineyardId: vineyard.id, vineyardName: vineyard.name)
                        } label: {
                            iconTile(title: "Manage Users", icon: "person.2.fill", tint: .blue)
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink {
                        BlocksHubView()
                    } label: {
                        iconTile(title: "Vineyard Setup", icon: "gearshape.2.fill", tint: .gray)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        OperationsHubView()
                    } label: {
                        iconTile(title: "Audit Log", icon: "doc.text.magnifyingglass", tint: .pink)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        OperationsHubView()
                    } label: {
                        iconTile(title: "Full Overview", icon: "chart.pie.fill", tint: VineyardTheme.leafGreen)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            plainSectionHeader("Recent")

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
        VStack(alignment: .leading, spacing: 10) {
            plainSectionHeader("Debug")
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
