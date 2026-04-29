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
                    SettingsRow(
                        title: "Blocks / Paddocks",
                        subtitle: "\(store.paddocks.count) paddock\(store.paddocks.count == 1 ? "" : "s")",
                        symbol: "square.grid.2x2.fill",
                        color: VineyardTheme.leafGreen
                    )
                }
                NavigationLink {
                    GrapeVarietyManagementView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(VineyardTheme.leafGreen.gradient)
                                .frame(width: 32, height: 32)
                            GrapeLeafIcon(size: 16, color: .white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grape Varieties")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(currentVineyardVarieties) variet\(currentVineyardVarieties == 1 ? "y" : "ies")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            } header: {
                SettingsSectionHeader(title: "Vineyard Setup", symbol: "square.grid.2x2.fill", color: VineyardTheme.leafGreen)
            }

            if accessControl.canChangeSettings {
                Section {
                    NavigationLink {
                        SprayManagementSettingsView()
                    } label: {
                        SettingsRow(
                            title: "Spray Management",
                            subtitle: "Chemicals, presets, programs",
                            symbol: "flask.fill",
                            color: .teal
                        )
                    }
                    NavigationLink {
                        EquipmentManagementView()
                    } label: {
                        SettingsRow(
                            title: "Equipment & Tractors",
                            subtitle: "Sprayers, tractors, fuel",
                            symbol: "wrench.and.screwdriver.fill",
                            color: VineyardTheme.earthBrown
                        )
                    }
                    NavigationLink {
                        OperatorCategoriesView()
                    } label: {
                        SettingsRow(
                            title: "Operators & Costs",
                            subtitle: "\(currentVineyardOperatorCategories) categor\(currentVineyardOperatorCategories == 1 ? "y" : "ies")",
                            symbol: "person.badge.clock.fill",
                            color: .blue
                        )
                    }
                    NavigationLink {
                        ButtonsAndQuickActionsView()
                    } label: {
                        SettingsRow(
                            title: "Buttons & Quick Actions",
                            subtitle: "Repair & growth buttons",
                            symbol: "square.grid.2x2.fill",
                            color: .orange
                        )
                    }
                } header: {
                    SettingsSectionHeader(title: "Management", symbol: "wrench.adjustable.fill", color: .orange)
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
        SettingsRow(title: title, subtitle: subtitle, symbol: icon, color: tint)
    }
}
