import SwiftUI

struct SprayPresetsView: View {
    @Environment(MigratedDataStore.self) private var store
    @Environment(\.accessControl) private var accessControl
    @State private var showAddChemical: Bool = false
    @State private var showAddPreset: Bool = false
    @State private var editingChemical: SavedChemical?
    @State private var editingPreset: SavedSprayPreset?

    var body: some View {
        List {
            chemicalsSection
            tankPresetsSection
        }
        .navigationTitle("Spray Presets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddChemical) {
            EditSavedChemicalSheet(chemical: nil)
        }
        .sheet(item: $editingChemical) { chem in
            EditSavedChemicalSheet(chemical: chem)
        }
        .sheet(isPresented: $showAddPreset) {
            EditSavedSprayPresetSheet(preset: nil)
        }
        .sheet(item: $editingPreset) { preset in
            EditSavedSprayPresetSheet(preset: preset)
        }
    }

    private var chemicalsSection: some View {
        Section {
            ForEach(store.savedChemicals) { chemical in
                Button {
                    editingChemical = chemical
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chemical.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if !chemical.activeIngredient.isEmpty {
                                Text(chemical.activeIngredient)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("\(String(format: "%.2f", chemical.ratePerHa)) \(chemical.unit.rawValue)/Ha")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if accessControl?.canDelete ?? false {
                        Button(role: .destructive) {
                            store.deleteSavedChemical(chemical)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                showAddChemical = true
            } label: {
                Label("Add Chemical", systemImage: "plus.circle")
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "flask.fill")
                    .foregroundStyle(VineyardTheme.olive)
                    .font(.caption)
                Text("Chemicals")
            }
        } footer: {
            Text("Saved chemicals link a name with its rate per hectare.")
        }
    }

    private var tankPresetsSection: some View {
        Section {
            ForEach(store.savedSprayPresets) { preset in
                Button {
                    editingPreset = preset
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(Int(preset.waterVolume))L • \(Int(preset.sprayRatePerHa))L/Ha • CF \(String(format: "%.1f", preset.concentrationFactor))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if accessControl?.canDelete ?? false {
                        Button(role: .destructive) {
                            store.deleteSavedSprayPreset(preset)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                showAddPreset = true
            } label: {
                Label("Add Tank Preset", systemImage: "plus.circle")
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(VineyardTheme.olive)
                    .font(.caption)
                Text("Tank Presets")
            }
        } footer: {
            Text("Tank presets save Water Volume, Spray Rate, and Concentration Factor.")
        }
    }
}

// MARK: - Edit Saved Chemical Sheet

struct EditSavedChemicalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MigratedDataStore.self) private var store

    let chemical: SavedChemical?

    @State private var name: String = ""
    @State private var unit: ChemicalUnit = .litres
    @State private var chemicalGroup: String = ""
    @State private var use: String = ""
    @State private var manufacturer: String = ""
    @State private var notes: String = ""
    @State private var problem: String = ""
    @State private var ratePerHaText: String = ""
    @State private var activeIngredient: String = ""
    @State private var modeOfAction: String = ""
    @State private var labelURL: String = ""

    init(chemical: SavedChemical?) {
        self.chemical = chemical
        if let c = chemical {
            _name = State(initialValue: c.name)
            _unit = State(initialValue: c.unit)
            _chemicalGroup = State(initialValue: c.chemicalGroup)
            _use = State(initialValue: c.use)
            _manufacturer = State(initialValue: c.manufacturer)
            _notes = State(initialValue: c.notes)
            _problem = State(initialValue: c.problem)
            _ratePerHaText = State(initialValue: c.ratePerHa > 0 ? String(format: "%.2f", c.ratePerHa) : "")
            _activeIngredient = State(initialValue: c.activeIngredient)
            _modeOfAction = State(initialValue: c.modeOfAction)
            _labelURL = State(initialValue: c.labelURL)
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Chemical Name", text: $name)
                    TextField("Active Ingredient", text: $activeIngredient)
                    TextField("Manufacturer", text: $manufacturer)
                }

                Section("Classification") {
                    TextField("Chemical Group", text: $chemicalGroup)
                    TextField("Mode of Action", text: $modeOfAction)
                    TextField("Use / Target", text: $use)
                    TextField("Problem (e.g. Powdery Mildew)", text: $problem)
                }

                Section("Default Rate") {
                    Picker("Unit", selection: $unit) {
                        ForEach(ChemicalUnit.allCases, id: \.self) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    HStack {
                        TextField("Rate per Ha", text: $ratePerHaText)
                            .keyboardType(.decimalPad)
                        Text("\(unit.rawValue)/Ha")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reference") {
                    TextField("Label URL", text: $labelURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(chemical == nil ? "New Chemical" : "Edit Chemical")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let rate = Double(ratePerHaText) ?? 0
        if var existing = chemical {
            existing.name = name
            existing.unit = unit
            existing.chemicalGroup = chemicalGroup
            existing.use = use
            existing.manufacturer = manufacturer
            existing.notes = notes
            existing.problem = problem
            existing.ratePerHa = rate
            existing.activeIngredient = activeIngredient
            existing.modeOfAction = modeOfAction
            existing.labelURL = labelURL
            store.updateSavedChemical(existing)
        } else {
            let new = SavedChemical(
                name: name,
                ratePerHa: rate,
                unit: unit,
                chemicalGroup: chemicalGroup,
                use: use,
                manufacturer: manufacturer,
                notes: notes,
                problem: problem,
                activeIngredient: activeIngredient,
                labelURL: labelURL,
                modeOfAction: modeOfAction
            )
            store.addSavedChemical(new)
        }
    }
}

// MARK: - Edit Saved Spray Preset Sheet

struct EditSavedSprayPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MigratedDataStore.self) private var store

    let preset: SavedSprayPreset?

    @State private var name: String = ""
    @State private var waterVolumeText: String = ""
    @State private var sprayRateText: String = ""
    @State private var concentrationText: String = "1.0"

    init(preset: SavedSprayPreset?) {
        self.preset = preset
        if let p = preset {
            _name = State(initialValue: p.name)
            _waterVolumeText = State(initialValue: String(format: "%.0f", p.waterVolume))
            _sprayRateText = State(initialValue: String(format: "%.0f", p.sprayRatePerHa))
            _concentrationText = State(initialValue: String(format: "%.1f", p.concentrationFactor))
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Preset Name", text: $name)
                }
                Section("Volumes") {
                    HStack {
                        Text("Water Volume")
                        Spacer()
                        TextField("0", text: $waterVolumeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("L")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Spray Rate")
                        Spacer()
                        TextField("0", text: $sprayRateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("L/Ha")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Concentration Factor")
                        Spacer()
                        TextField("1.0", text: $concentrationText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle(preset == nil ? "New Preset" : "Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let water = Double(waterVolumeText) ?? 0
        let rate = Double(sprayRateText) ?? 0
        let cf = Double(concentrationText) ?? 1.0
        if var existing = preset {
            existing.name = name
            existing.waterVolume = water
            existing.sprayRatePerHa = rate
            existing.concentrationFactor = cf
            store.updateSavedSprayPreset(existing)
        } else {
            let new = SavedSprayPreset(
                name: name,
                waterVolume: water,
                sprayRatePerHa: rate,
                concentrationFactor: cf
            )
            store.addSavedSprayPreset(new)
        }
    }
}
