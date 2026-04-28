import SwiftUI

/// Phase 6A backend-aware vineyard list. Uses `SupabaseVineyardRepository` to list
/// and create vineyards on the new backend, then mirrors the result into
/// `MigratedDataStore` so the rest of the (still-local) legacy app can use them.
struct BackendVineyardListView: View {
    @Environment(MigratedDataStore.self) private var store

    private let vineyardRepository: any VineyardRepositoryProtocol

    @State private var showAddVineyard: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var errorMessage: String?
    @State private var vineyardPendingDeletion: Vineyard?

    init(vineyardRepository: any VineyardRepositoryProtocol = SupabaseVineyardRepository()) {
        self.vineyardRepository = vineyardRepository
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            GrapeLeafIcon(size: 64)
                .foregroundStyle(VineyardTheme.leafGreen.opacity(0.6))

            VStack(spacing: 8) {
                Text("Welcome to VineTrack")
                    .font(.title2.weight(.semibold))
                Text("Create your first vineyard to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showAddVineyard = true
            } label: {
                Label("Create Vineyard", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VineyardTheme.olive)
            .controlSize(.large)
            .padding(.horizontal, 40)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var vineyardList: some View {
        List {
            ForEach(store.vineyards) { vineyard in
                BackendVineyardCardRow(
                    vineyard: vineyard,
                    isSelected: vineyard.id == store.selectedVineyardId,
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

                VStack(alignment: .leading, spacing: 4) {
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
}
