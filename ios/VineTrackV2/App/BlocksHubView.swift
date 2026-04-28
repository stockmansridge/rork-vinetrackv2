import SwiftUI

struct BlocksHubView: View {
    @Environment(MigratedDataStore.self) private var store
    @Environment(BackendAccessControl.self) private var accessControl
    @State private var showAddPaddock: Bool = false
    @State private var paddockToEdit: Paddock?

    var body: some View {
        Group {
            if store.paddocks.isEmpty {
                VineyardEmptyStateView(
                    icon: "square.grid.2x2",
                    title: "No paddocks yet",
                    message: "Create your first block to start mapping rows.",
                    actionTitle: accessControl.canCreateOperationalRecords ? "Add Paddock" : nil,
                    action: accessControl.canCreateOperationalRecords ? { showAddPaddock = true } : nil as (() -> Void)?
                )
            } else {
                paddockList
            }
        }
        .navigationTitle("Blocks")
        .toolbar {
            if accessControl.canCreateOperationalRecords {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPaddock = true
                    } label: {
                        Image(systemName: "plus")
                    }
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

    private var paddockList: some View {
        List {
            ForEach(store.paddocks) { paddock in
                Button {
                    paddockToEdit = paddock
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(VineyardTheme.leafGreen.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundStyle(VineyardTheme.leafGreen)
                        }
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
            .onDelete { offsets in
                guard accessControl.canDeleteOperationalRecords else { return }
                deletePaddocks(at: offsets)
            }
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
