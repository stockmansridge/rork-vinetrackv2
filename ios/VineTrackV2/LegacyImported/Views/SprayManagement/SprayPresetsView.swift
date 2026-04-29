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
    @State private var showAILookup: Bool = false
    @State private var aiLoading: Bool = false
    @State private var aiError: String?

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
                if store.settings.aiSuggestionsEnabled {
                    Section {
                        Button {
                            showAILookup = true
                        } label: {
                            Label(aiLoading ? "Looking up…" : "Search with AI", systemImage: "sparkles")
                        }
                        .disabled(aiLoading)
                        if let aiError {
                            Text(aiError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } footer: {
                        Text("AI suggestions must be checked against the current product label, permit, SDS, and local regulations before use.")
                    }
                }

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
            .sheet(isPresented: $showAILookup) {
                ChemicalAILookupSheet(initialQuery: name) { result in
                    Task { await applyAIResult(result) }
                }
            }
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

    @MainActor
    private func applyAIResult(_ result: ChemicalSearchResult) async {
        aiError = nil
        aiLoading = true
        defer { aiLoading = false }
        if name.isEmpty { name = result.name }
        if activeIngredient.isEmpty { activeIngredient = result.activeIngredient }
        if manufacturer.isEmpty { manufacturer = result.brand }
        if chemicalGroup.isEmpty { chemicalGroup = result.chemicalGroup }
        if modeOfAction.isEmpty { modeOfAction = result.modeOfAction }
        if use.isEmpty { use = result.primaryUse }
        if problem.isEmpty { problem = result.primaryUse }

        let country = store.selectedVineyard?.country ?? ""
        do {
            let info = try await ChemicalInfoService().lookupChemicalInfo(productName: result.name, country: country)
            if activeIngredient.isEmpty { activeIngredient = info.activeIngredient }
            if manufacturer.isEmpty { manufacturer = info.brand }
            if chemicalGroup.isEmpty { chemicalGroup = info.chemicalGroup }
            if labelURL.isEmpty { labelURL = info.labelURL }
            if let moa = info.modeOfAction, modeOfAction.isEmpty { modeOfAction = moa }
            if use.isEmpty { use = info.primaryUse }
            unit = info.defaultUnit
            if let rates = info.ratesPerHectare, let first = rates.first, ratePerHaText.isEmpty {
                ratePerHaText = String(format: "%.2f", first.value)
            }
        } catch {
            aiError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

// MARK: - Chemical AI Lookup Sheet

struct ChemicalAILookupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MigratedDataStore.self) private var store

    let initialQuery: String
    let onSelect: (ChemicalSearchResult) -> Void

    @State private var query: String = ""
    @State private var results: [ChemicalSearchResult] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    init(initialQuery: String, onSelect: @escaping (ChemicalSearchResult) -> Void) {
        self.initialQuery = initialQuery
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Product or active ingredient", text: $query)
                            .textInputAutocapitalization(.words)
                            .onSubmit { Task { await search() } }
                        Button {
                            Task { await search() }
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(isLoading || query.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("AI suggestions must be checked against the current label, permit, SDS, and local regulations before use.")
                }

                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Searching…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if !results.isEmpty {
                    Section("Results") {
                        ForEach(results) { item in
                            Button {
                                onSelect(item)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if !item.activeIngredient.isEmpty {
                                        Text(item.activeIngredient)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 6) {
                                        if !item.brand.isEmpty {
                                            Text(item.brand).font(.caption2).foregroundStyle(.tertiary)
                                        }
                                        if !item.chemicalGroup.isEmpty {
                                            Text("• \(item.chemicalGroup)").font(.caption2).foregroundStyle(.tertiary)
                                        }
                                        if !item.modeOfAction.isEmpty {
                                            Text("• MOA \(item.modeOfAction)").font(.caption2).foregroundStyle(.tertiary)
                                        }
                                    }
                                    if !item.primaryUse.isEmpty {
                                        Text(item.primaryUse)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if !initialQuery.trimmingCharacters(in: .whitespaces).isEmpty && results.isEmpty {
                    await search()
                }
            }
        }
    }

    @MainActor
    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        let country = store.selectedVineyard?.country ?? ""
        do {
            results = try await ChemicalInfoService().searchChemicals(query: trimmed, country: country)
            if results.isEmpty {
                errorMessage = "No products found."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            results = []
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
