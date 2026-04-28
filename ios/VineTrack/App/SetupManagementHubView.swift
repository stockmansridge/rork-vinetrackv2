import SwiftUI

struct SetupManagementHubView: View {
    @Environment(MigratedDataStore.self) private var store
    @Environment(BackendAccessControl.self) private var accessControl

    var body: some View {
        List {
            Section {
                NavigationLink {
                    BlocksHubView()
                } label: {
                    hubRow(
                        title: "Blocks / Paddocks",
                        subtitle: "\(store.paddocks.count) paddock\(store.paddocks.count == 1 ? "" : "s")",
                        icon: "square.grid.2x2.fill",
                        tint: VineyardTheme.leafGreen
                    )
                }
                NavigationLink {
                    GrapeVarietyManagementView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(VineyardTheme.leafGreen.opacity(0.15))
                                .frame(width: 36, height: 36)
                            GrapeLeafIcon(size: 18, color: VineyardTheme.leafGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grape Varieties")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(currentVineyardVarieties) variet\(currentVineyardVarieties == 1 ? "y" : "ies")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } header: {
                Text("Vineyard Setup")
            }

            if accessControl.canChangeSettings {
                Section {
                    NavigationLink {
                        SprayManagementSettingsView()
                    } label: {
                        hubRow(
                            title: "Spray Management",
                            subtitle: "Chemicals, presets, programs",
                            icon: "flask.fill",
                            tint: VineyardTheme.info
                        )
                    }
                    NavigationLink {
                        EquipmentManagementView()
                    } label: {
                        hubRow(
                            title: "Equipment & Tractors",
                            subtitle: "Sprayers, tractors, fuel",
                            icon: "wrench.and.screwdriver",
                            tint: VineyardTheme.earthBrown
                        )
                    }
                    NavigationLink {
                        OperatorCategoriesView()
                    } label: {
                        hubRow(
                            title: "Operators & Costs",
                            subtitle: "\(currentVineyardOperatorCategories) categor\(currentVineyardOperatorCategories == 1 ? "y" : "ies")",
                            icon: "person.badge.clock",
                            tint: VineyardTheme.olive
                        )
                    }
                    NavigationLink {
                        ButtonsAndQuickActionsView()
                    } label: {
                        hubRow(
                            title: "Buttons & Quick Actions",
                            subtitle: "Repair & growth buttons",
                            icon: "square.grid.2x2",
                            tint: .orange
                        )
                    }
                } header: {
                    Text("Management")
                } footer: {
                    Text("Manage saved chemicals, equipment, operators, and quick action buttons.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Setup & Management")
    }

    private var currentVineyardVarieties: Int {
        guard let vid = store.selectedVineyardId else { return 0 }
        return store.grapeVarieties.filter { $0.vineyardId == vid }.count
    }

    private var currentVineyardOperatorCategories: Int {
        guard let vid = store.selectedVineyardId else { return 0 }
        return store.operatorCategories.filter { $0.vineyardId == vid }.count
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
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
