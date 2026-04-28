import SwiftUI
import CoreLocation

struct NewMainTabView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @Environment(LocationService.self) private var locationService

    var body: some View {
        TabView {
            NewHomeTabView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            NewPaddocksTabView()
                .tabItem { Label("Paddocks", systemImage: "square.grid.2x2.fill") }

            PinsView()
                .tabItem { Label("Pins", systemImage: "mappin.and.ellipse") }

            TripView()
                .tabItem { Label("Trip", systemImage: "road.lanes") }

            SprayProgramView()
                .tabItem { Label("Program", systemImage: "drop.fill") }

            NewWorkTabView()
                .tabItem { Label("Work", systemImage: "checklist") }

            NewSettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(VineyardTheme.leafGreen)
        .onAppear {
            if locationService.authorizationStatus == .notDetermined {
                locationService.requestPermission()
            } else if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                locationService.startUpdating()
            }
        }
    }
}

// MARK: - Home Tab

private struct NewHomeTabView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    #if DEBUG
    @State private var showBackendDiagnostic: Bool = false
    @State private var showStoreDiagnostic: Bool = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.selectedVineyard?.name ?? "No Vineyard")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(VineyardTheme.olive)
                        if let country = store.selectedVineyard?.country, !country.isEmpty {
                            Label(country, systemImage: "globe")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Selected Vineyard")
                }

                Section("Account") {
                    LabeledContent("Name", value: auth.userName ?? "—")
                    LabeledContent("Email", value: auth.userEmail ?? "—")
                }

                Section("Counts") {
                    countRow("Paddocks", value: store.paddocks.count, icon: "square.grid.2x2")
                    countRow("Pins", value: store.pins.count, icon: "mappin.circle")
                    countRow("Trips", value: store.trips.count, icon: "map")
                    countRow("Spray records", value: store.sprayRecords.count, icon: "drop.fill")
                    countRow("Work tasks", value: store.workTasks.count, icon: "checklist")
                }

                #if DEBUG
                Section("Debug") {
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
                }
                #endif
            }
            .navigationTitle("Home")
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

    private func countRow(_ label: String, value: Int, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text("\(value)")
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(VineyardTheme.leafGreen)
        }
    }
}

// MARK: - Paddocks Tab

private struct NewPaddocksTabView: View {
    @Environment(MigratedDataStore.self) private var store
    @State private var showAddPaddock: Bool = false
    @State private var paddockToEdit: Paddock?

    var body: some View {
        NavigationStack {
            Group {
                if store.paddocks.isEmpty {
                    emptyState
                } else {
                    paddockList
                }
            }
            .navigationTitle("Paddocks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPaddock = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPaddock) {
                EditPaddockSheet(paddock: nil)
            }
            .sheet(item: $paddockToEdit) { paddock in
                EditPaddockSheet(paddock: paddock)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 56))
                .foregroundStyle(VineyardTheme.leafGreen.opacity(0.6))
            Text("No paddocks yet")
                .font(.headline)
            Text("Create your first block to start mapping rows.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showAddPaddock = true
            } label: {
                Label("Add Paddock", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(VineyardTheme.olive)
            .controlSize(.large)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var paddockList: some View {
        List {
            ForEach(store.paddocks) { paddock in
                Button {
                    paddockToEdit = paddock
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(VineyardTheme.leafGreen)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(paddock.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(paddock.rows.count) rows")
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
            .onDelete(perform: deletePaddocks)
        }
        .listStyle(.insetGrouped)
    }

    private func deletePaddocks(at offsets: IndexSet) {
        for index in offsets {
            let paddock = store.paddocks[index]
            store.deletePaddock(paddock.id)
        }
    }
}

// MARK: - Work Tab

private struct NewWorkTabView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case tasks = "Tasks"
        case maintenance = "Maintenance"
        case yield = "Yield"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .tasks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    ForEach(Segment.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                switch segment {
                case .tasks:
                    WorkTasksHubView()
                case .maintenance:
                    MaintenanceLogListView()
                case .yield:
                    YieldHubView()
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Settings Tab

private struct NewSettingsTabView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @State private var showVineyardSwitcher: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var refreshMessage: String?
    private let vineyardRepository: any VineyardRepositoryProtocol = SupabaseVineyardRepository()
    #if DEBUG
    @State private var showBackendDiagnostic: Bool = false
    @State private var showStoreDiagnostic: Bool = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Name", value: auth.userName ?? "—")
                    LabeledContent("Email", value: auth.userEmail ?? "—")
                }

                Section("Vineyard") {
                    LabeledContent("Selected", value: store.selectedVineyard?.name ?? "—")
                    Button {
                        showVineyardSwitcher = true
                    } label: {
                        Label("Change Vineyard", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        Task { await refreshVineyards() }
                    } label: {
                        HStack {
                            Label("Refresh Vineyards", systemImage: "arrow.clockwise")
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
                }

                #if DEBUG
                Section("Debug") {
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
                }
                #endif

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
            .navigationTitle("Settings")
            .sheet(isPresented: $showVineyardSwitcher) {
                BackendVineyardListView()
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
