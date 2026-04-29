import SwiftUI

struct OperationsSetupHubView: View {
    @Environment(MigratedDataStore.self) private var store
    @Environment(BackendAccessControl.self) private var accessControl

    var body: some View {
        List {
            Section {
                NavigationLink {
                    VineyardSetupHubView()
                } label: {
                    SettingsRow(
                        title: "Vineyard Setup",
                        subtitle: "Blocks, Buttons & Growth Stages",
                        symbol: "square.grid.2x2.fill",
                        color: VineyardTheme.leafGreen
                    )
                }
                NavigationLink {
                    SprayEquipmentHubView()
                } label: {
                    SettingsRow(
                        title: "Spray & Equipment",
                        subtitle: "Spray Management, Equipment & Tractors, Chemicals",
                        symbol: "drop.fill",
                        color: .teal
                    )
                }
                NavigationLink {
                    TeamOperationsHubView()
                } label: {
                    SettingsRow(
                        title: "Team Operations",
                        subtitle: "Operator Categories",
                        symbol: "person.2.fill",
                        color: .blue
                    )
                }
            } header: {
                SettingsSectionHeader(title: "Operations Setup", symbol: "wrench.adjustable.fill", color: .orange)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Operations")
    }
}

struct VineyardSetupHubView: View {
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
                if accessControl.canChangeSettings {
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
                }
                NavigationLink {
                    GrowthStageImagesSettingsView()
                } label: {
                    SettingsRow(
                        title: "Growth Stages",
                        subtitle: "E-L stage reference photos",
                        symbol: "leaf.arrow.triangle.circlepath",
                        color: VineyardTheme.leafGreen
                    )
                }
            } header: {
                SettingsSectionHeader(title: "Vineyard Setup", symbol: "square.grid.2x2.fill", color: VineyardTheme.leafGreen)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Vineyard Setup")
    }

    private var currentVineyardVarieties: Int {
        guard let vid = store.selectedVineyardId else { return 0 }
        return store.grapeVarieties.filter { $0.vineyardId == vid }.count
    }
}

struct SprayEquipmentHubView: View {
    @Environment(BackendAccessControl.self) private var accessControl

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SprayManagementSettingsView()
                } label: {
                    SettingsRow(
                        title: "Spray Management",
                        subtitle: "Presets and programs",
                        symbol: "drop.fill",
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
                    ChemicalsManagementView()
                } label: {
                    SettingsRow(
                        title: "Chemicals",
                        subtitle: "Saved chemical library",
                        symbol: "flask.fill",
                        color: .purple
                    )
                }
            } header: {
                SettingsSectionHeader(title: "Spray & Equipment", symbol: "drop.fill", color: .teal)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Spray & Equipment")
    }
}

struct TeamOperationsHubView: View {
    @Environment(MigratedDataStore.self) private var store

    var body: some View {
        List {
            Section {
                NavigationLink {
                    OperatorCategoriesView()
                } label: {
                    SettingsRow(
                        title: "Operator Categories",
                        subtitle: "\(currentVineyardOperatorCategories) categor\(currentVineyardOperatorCategories == 1 ? "y" : "ies")",
                        symbol: "person.badge.clock.fill",
                        color: .blue
                    )
                }
            } header: {
                SettingsSectionHeader(title: "Team Operations", symbol: "person.2.fill", color: .blue)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Team Operations")
    }

    private var currentVineyardOperatorCategories: Int {
        guard let vid = store.selectedVineyardId else { return 0 }
        return store.operatorCategories.filter { $0.vineyardId == vid }.count
    }
}
