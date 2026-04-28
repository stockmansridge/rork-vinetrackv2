import SwiftUI

struct OperationsHubView: View {
    @Environment(MigratedDataStore.self) private var store

    var body: some View {
        List {
            Section {
                NavigationLink {
                    WorkTasksHubView()
                } label: {
                    operationRow(
                        title: "Work Tasks",
                        subtitle: "Plan and log vineyard work",
                        icon: "checklist",
                        tint: VineyardTheme.olive,
                        count: store.workTasks.count
                    )
                }
                NavigationLink {
                    MaintenanceLogListView()
                } label: {
                    operationRow(
                        title: "Maintenance",
                        subtitle: "Equipment & tractor logs",
                        icon: "wrench.and.screwdriver.fill",
                        tint: VineyardTheme.earthBrown,
                        count: store.maintenanceLogs.count
                    )
                }
                NavigationLink {
                    YieldHubView()
                } label: {
                    operationRow(
                        title: "Yield & Damage",
                        subtitle: "Estimates, harvest, damage records",
                        icon: "scalemass.fill",
                        tint: VineyardTheme.vineRed,
                        count: nil
                    )
                }
            } header: {
                Text("Operations")
            }

            Section {
                NavigationLink {
                    GrowthStageReportView()
                } label: {
                    operationRow(
                        title: "Growth Stage Report",
                        subtitle: "Phenology & E-L stages",
                        icon: "leaf.arrow.triangle.circlepath",
                        tint: VineyardTheme.leafGreen,
                        count: nil
                    )
                }
                NavigationLink {
                    GrowthStageImagesSettingsView()
                } label: {
                    operationRow(
                        title: "E-L Stage Images",
                        subtitle: "Reference photos",
                        icon: "photo.on.rectangle.angled",
                        tint: VineyardTheme.leafGreen,
                        count: nil
                    )
                }
            } header: {
                Text("Phenology")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Operations")
    }

    private func operationRow(title: String, subtitle: String, icon: String, tint: Color, count: Int?) -> some View {
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
            if let count {
                Text("\(count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
