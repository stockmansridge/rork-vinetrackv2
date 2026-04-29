import SwiftUI

/// Phase 6A backend-aware vineyard list. Uses `SupabaseVineyardRepository` to list
/// and create vineyards on the new backend, then mirrors the result into
/// `MigratedDataStore` so the rest of the (still-local) legacy app can use them.
struct BackendVineyardListView: View {
    @Environment(MigratedDataStore.self) private var store
    @Environment(NewBackendAuthService.self) private var auth

    private let vineyardRepository: any VineyardRepositoryProtocol
    private let teamRepository: any TeamRepositoryProtocol
    private let logoStorage: VineyardLogoStorageService

    @State private var showAddVineyard: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var errorMessage: String?
    @State private var vineyardPendingDeletion: Vineyard?
    @State private var rolesByVineyardId: [UUID: BackendRole] = [:]
    @State private var isLoadingRoles: Bool = false

    init(
        vineyardRepository: any VineyardRepositoryProtocol = SupabaseVineyardRepository(),
        teamRepository: any TeamRepositoryProtocol = SupabaseTeamRepository(),
        logoStorage: VineyardLogoStorageService = VineyardLogoStorageService()
    ) {
        self.vineyardRepository = vineyardRepository
        self.teamRepository = teamRepository
        self.logoStorage = logoStorage
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.vineyards.isEmpty {
                    emptyState
                } else {
                    vineyardList
                }
            }
            .navigationTitle("Vineyards")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddVineyard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await refresh() }
            .sheet(isPresented: $showAddVineyard) {
                EditVineyardSheet(vineyard: nil, vineyardRepository: vineyardRepository)
            }
            .task { await refresh() }
            .alert("Vineyards", isPresented: errorBinding, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let backendVineyards = try await vineyardRepository.listMyVineyards()
            store.mapBackendVineyardsIntoLocal(backendVineyards)
            await fetchMissingLogos()
            await fetchRoles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchRoles() async {
        guard let userId = auth.userId else { return }
        isLoadingRoles = true
        defer { isLoadingRoles = false }
        var updated: [UUID: BackendRole] = [:]
        await withTaskGroup(of: (UUID, BackendRole?).self) { group in
            for vineyard in store.vineyards {
                let vineyardId = vineyard.id
                let repo = teamRepository
                group.addTask {
                    do {
                        let members = try await repo.listMembers(vineyardId: vineyardId)
                        return (vineyardId, members.first { $0.userId == userId }?.role)
                    } catch {
                        return (vineyardId, nil)
                    }
                }
            }
            for await (id, role) in group {
                if let role { updated[id] = role }
            }
        }
        rolesByVineyardId = updated
    }

    private func fetchMissingLogos() async {
        for vineyard in store.vineyards {
            guard let path = vineyard.logoPath, vineyard.logoData == nil else { continue }
            do {
                let data = try await logoStorage.downloadLogo(path: path)
                if var current = store.vineyards.first(where: { $0.id == vineyard.id }) {
                    current.logoData = data
                    store.upsertLocalVineyard(current)
                }
            } catch {
                #if DEBUG
                print("[VineyardLogo] download failed for \(vineyard.name):", error.localizedDescription)
                #endif
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            VineyardEmptyStateView(
                icon: "leaf.fill",
                title: "Welcome to VineTrackV2",
                message: "Create your first vineyard to get started.",
                actionTitle: "Create Vineyard",
                action: { showAddVineyard = true }
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(VineyardTheme.destructive)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .background(VineyardTheme.appBackground)
    }

    private var vineyardList: some View {
        List {
            ForEach(store.vineyards) { vineyard in
                BackendVineyardCardRow(
                    vineyard: vineyard,
                    isSelected: vineyard.id == store.selectedVineyardId,
                    role: rolesByVineyardId[vineyard.id],
                    isLoadingRole: isLoadingRoles && rolesByVineyardId[vineyard.id] == nil,
                    vineyardRepository: vineyardRepository
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct BackendVineyardCardRow: View {
    let vineyard: Vineyard
    let isSelected: Bool
    let role: BackendRole?
    let isLoadingRole: Bool
    let vineyardRepository: any VineyardRepositoryProtocol
    @Environment(MigratedDataStore.self) private var store
    @State private var showDetail: Bool = false

    var body: some View {
        Button {
            store.selectVineyard(vineyard)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? VineyardTheme.leafGreen.gradient : Color(.tertiarySystemFill).gradient)
                        .frame(width: 44, height: 44)

                    GrapeLeafIcon(size: 22)
                        .foregroundStyle(isSelected ? .white : VineyardTheme.leafGreen)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(vineyard.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if !vineyard.country.isEmpty {
                            Label(vineyard.country, systemImage: "globe")
                        }
                        if isSelected {
                            Text("Active")
                                .fontWeight(.medium)
                                .foregroundStyle(VineyardTheme.leafGreen)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    roleBadge
                }

                Spacer()

                Button {
                    showDetail = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showDetail) {
            BackendVineyardDetailSheet(vineyard: vineyard, vineyardRepository: vineyardRepository)
        }
    }

    @ViewBuilder
    private var roleBadge: some View {
        if let role {
            HStack(spacing: 6) {
                Label {
                    Text(role.displayName)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: role.iconName)
                }
                .labelStyle(.titleAndIcon)
                .font(.caption2)
                .foregroundStyle(role.tintColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(role.tintColor.opacity(0.15), in: Capsule())

                Text(role.permissionSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else if isLoadingRole {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Loading access…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("No access", systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private extension BackendRole {
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .manager: return "Manager"
        case .supervisor: return "Supervisor"
        case .operator: return "Operator"
        }
    }

    var iconName: String {
        switch self {
        case .owner: return "crown.fill"
        case .manager: return "person.badge.shield.checkmark.fill"
        case .supervisor: return "person.2.fill"
        case .operator: return "wrench.and.screwdriver.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .owner: return .purple
        case .manager: return .blue
        case .supervisor: return .teal
        case .operator: return .orange
        }
    }

    var permissionSummary: String {
        switch self {
        case .owner: return "Full access"
        case .manager: return "Financials & settings"
        case .supervisor: return "Edit & delete records"
        case .operator: return "Field operations only"
        }
    }
}
