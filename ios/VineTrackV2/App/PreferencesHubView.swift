import SwiftUI

struct PreferencesHubView: View {
    @Environment(MigratedDataStore.self) private var store

    @State private var samplesPerHectareText: String = ""
    @State private var fillTimerEnabled: Bool = true
    @State private var elConfirmationEnabled: Bool = true
    @State private var seasonFuelCostText: String = ""
    @State private var showGrowthStages: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Spray Fill Timer", isOn: $fillTimerEnabled)
                    .onChange(of: fillTimerEnabled) { _, newValue in
                        var s = store.settings
                        s.fillTimerEnabled = newValue
                        store.updateSettings(s)
                    }

                Toggle("Confirm E-L Stage", isOn: $elConfirmationEnabled)
                    .onChange(of: elConfirmationEnabled) { _, newValue in
                        var s = store.settings
                        s.elConfirmationEnabled = newValue
                        store.updateSettings(s)
                    }
            } header: {
                Text("Behaviour")
            }

            Section {
                HStack {
                    Text("Samples per Hectare")
                    Spacer()
                    TextField("0", text: $samplesPerHectareText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onSubmit { saveSamples() }
                }
                HStack {
                    Text("Fuel Cost (per L)")
                    Spacer()
                    TextField("0", text: $seasonFuelCostText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onSubmit { saveFuelCost() }
                }
            } header: {
                Text("Defaults")
            }

            Section {
                NavigationLink {
                    CalculationSettingsView()
                } label: {
                    Label("Canopy Water Rates", systemImage: "drop.triangle.fill")
                }
                NavigationLink {
                    YieldSettingsView()
                } label: {
                    Label("Yield Settings", systemImage: "scalemass")
                }
            } header: {
                Text("Calculations")
            }

            Section {
                Button {
                    showGrowthStages = true
                } label: {
                    HStack {
                        Label { Text("Enabled E-L Stages") } icon: { GrapeLeafIcon(size: 16) }
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(store.settings.enabledGrowthStageCodes.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    GrowthStageImagesSettingsView()
                } label: {
                    Label("E-L Stage Images", systemImage: "photo.on.rectangle.angled")
                }
            } header: {
                Text("Phenology")
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGrowthStages) {
            GrowthStageConfigSheet()
        }
        .onAppear {
            samplesPerHectareText = String(store.settings.samplesPerHectare)
            fillTimerEnabled = store.settings.fillTimerEnabled
            elConfirmationEnabled = store.settings.elConfirmationEnabled
            seasonFuelCostText = String(format: "%.2f", store.settings.seasonFuelCostPerLitre)
        }
    }

    private func saveSamples() {
        guard let v = Int(samplesPerHectareText), v > 0 else { return }
        var s = store.settings
        s.samplesPerHectare = v
        store.updateSettings(s)
    }

    private func saveFuelCost() {
        guard let v = Double(seasonFuelCostText), v >= 0 else { return }
        var s = store.settings
        s.seasonFuelCostPerLitre = v
        store.updateSettings(s)
    }
}
