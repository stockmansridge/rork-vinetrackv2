import SwiftUI
import CoreLocation

enum GrowthStageMode: String, CaseIterable {
    case same
    case perPaddock
}

/// Backend-safe Spray Calculator.
///
/// Restores the original spray-job setup workflow visually and functionally:
/// paddock selection, operation type, growth stage, equipment, water rate
/// (canopy size + density + row spacing), chemicals (rate per ha or per 100L),
/// optional manual weather, notes, calculation results and (when permitted)
/// costing summary.
///
/// Wired only to MigratedDataStore + TripTrackingService + BackendAccessControl.
/// No DataStore, AuthService, CloudSyncService, SupabaseManager or
/// WeatherDataService imports.
struct SprayCalculatorView: View {
    @Environment(MigratedDataStore.self) private var store
    @Environment(TripTrackingService.self) private var tracking
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(BackendAccessControl.self) private var accessControl
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    // Selection
    @State private var sprayName: String = ""
    @State private var operationType: OperationType = .foliarSpray
    @State private var selectedPaddockIds: Set<UUID> = []
    @State private var selectedEquipmentId: UUID?
    @State private var selectedTractorId: UUID?
    @State private var canopySize: CanopySize = .medium
    @State private var canopyDensity: CanopyDensity = .low
    @State private var sharedGrowthStageId: UUID?
    @State private var growthStageMode: GrowthStageMode = .same
    @State private var paddockPhenologyStages: [UUID: UUID] = [:]
    @State private var chemicalLines: [ChemicalLine] = []
    @State private var showAddChemicalToList: Bool = false
    @State private var sprayRateText: String = ""
    @State private var hasEditedSprayRate: Bool = false
    @State private var notes: String = ""

    // Optional manual weather
    @State private var temperatureText: String = ""
    @State private var windSpeedText: String = ""
    @State private var windDirection: String = ""
    @State private var humidityText: String = ""

    // Weather auto-fetch
    @State private var isFetchingWeather: Bool = false
    @State private var weatherFetchError: String?
    @State private var weatherFetchedAt: Date?
    @State private var weatherStationId: String?
    @State private var weatherSource: String?

    // UI
    @State private var isPaddocksExpanded: Bool = true
    @State private var isEquipmentExpanded: Bool = true
    @State private var calculationResult: SprayCalculationResult?
    @State private var showResults: Bool = false
    @State private var showSummary: Bool = false
    @State private var summaryJobStarted: Bool = false
    @State private var savedFeedback: Bool = false
    @State private var errorMessage: String?

    // MARK: - Computed

    private var phenologyStages: [PhenologyStage] { PhenologyStage.allStages }

    private var selectedPaddocks: [Paddock] {
        store.paddocks.filter { selectedPaddockIds.contains($0.id) }
    }

    private var totalAreaHectares: Double {
        selectedPaddocks.reduce(0) { $0 + $1.areaHectares }
    }

    private var averageRowSpacing: Double {
        guard !selectedPaddocks.isEmpty else { return 2.5 }
        return selectedPaddocks.reduce(0) { $0 + $1.rowSpacingMetres } / Double(selectedPaddocks.count)
    }

    private var waterRateEntry: CanopyWaterRate.RateEntry {
        CanopyWaterRate.rate(
            size: canopySize,
            density: canopyDensity,
            rowSpacingMetres: averageRowSpacing,
            settings: store.settings.canopyWaterRates
        )
    }

    private var chosenSprayRate: Double {
        Double(sprayRateText) ?? waterRateEntry.litresPerHa
    }

    private var concentrationFactor: Double {
        guard chosenSprayRate > 0 else { return 1.0 }
        return waterRateEntry.litresPerHa / chosenSprayRate
    }

    private var formIsValid: Bool {
        !selectedPaddockIds.isEmpty && selectedEquipmentId != nil && !chemicalLines.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sprayNameSection
                    operationTypeSection
                    paddockSelection
                    growthStageSection
                    equipmentSelection
                    waterRateSection
                    irrigationDataSection
                    tractorSelection
                    chemicalLinesSection
                    weatherSection
                    notesSection
                    actionButtons

                    if showResults, let result = calculationResult {
                        ResultsCard(result: result)
                        if let costing = result.costingSummary, accessControl.canViewFinancials {
                            CostingsCard(summary: costing)
                        }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Spray Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: savedFeedback)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showSummary, onDismiss: { dismiss() }) {
                if let result = calculationResult {
                    SprayCalculationSummarySheet(
                        result: result,
                        sprayName: sprayName,
                        jobStarted: summaryJobStarted,
                        canViewFinancials: accessControl.canViewFinancials
                    )
                }
            }
            .sheet(isPresented: $showAddChemicalToList) {
                EditSavedChemicalSheet(chemical: nil)
            }
        }
    }

    // MARK: - Sections

    private var sprayNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Spray Name", icon: "tag")
            TextField("e.g. Downy Mildew Spray #3", text: $sprayName)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var operationTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Operation Type", icon: "gearshape.2")
            VStack(spacing: 0) {
                ForEach(OperationType.allCases, id: \.self) { type in
                    let isSelected = operationType == type
                    Button {
                        operationType = type
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? AnyShapeStyle(VineyardTheme.olive) : AnyShapeStyle(.tertiary))
                            Image(systemName: type.iconName)
                                .font(.subheadline)
                                .foregroundStyle(isSelected ? VineyardTheme.olive : .secondary)
                                .frame(width: 24)
                            Text(type.rawValue).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    if type != OperationType.allCases.last {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var paddockSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(duration: 0.3)) { isPaddocksExpanded.toggle() }
            } label: {
                HStack {
                    PaddockSectionHeader(title: "Paddocks")
                    Spacer()
                    if !selectedPaddockIds.isEmpty {
                        Text("\(selectedPaddockIds.count) selected")
                            .font(.caption)
                            .foregroundStyle(VineyardTheme.olive)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isPaddocksExpanded ? 90 : 0))
                }
            }

            if isPaddocksExpanded {
                VStack(spacing: 0) {
                    if store.paddocks.isEmpty {
                        Text("No paddocks configured")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(store.paddocks) { paddock in
                        let isSelected = selectedPaddockIds.contains(paddock.id)
                        Button {
                            if isSelected {
                                selectedPaddockIds.remove(paddock.id)
                            } else {
                                selectedPaddockIds.insert(paddock.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? AnyShapeStyle(VineyardTheme.olive) : AnyShapeStyle(.tertiary))
                                Text(paddock.name).foregroundStyle(.primary)
                                Spacer()
                                Text("\(paddock.areaHectares, specifier: "%.2f") ha")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        if paddock.id != store.paddocks.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 10))
            }

            if !selectedPaddockIds.isEmpty {
                Text("Total: \(totalAreaHectares, specifier: "%.2f") ha selected")
                    .font(.caption)
                    .foregroundStyle(VineyardTheme.olive)
            }
        }
    }

    private var growthStageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Growth Stage", icon: "leaf.arrow.circlepath")

            if selectedPaddockIds.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Select paddocks above to assign growth stages")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 10))
            } else {
                Picker("", selection: $growthStageMode) {
                    Text("Same for All").tag(GrowthStageMode.same)
                    Text("Per Paddock").tag(GrowthStageMode.perPaddock)
                }
                .pickerStyle(.segmented)
                .onChange(of: growthStageMode) { _, newMode in
                    if newMode == .same, let shared = sharedGrowthStageId {
                        for pid in selectedPaddockIds {
                            paddockPhenologyStages[pid] = shared
                        }
                    }
                }

                if growthStageMode == .same {
                    sameGrowthStageList
                } else {
                    perPaddockGrowthStageList
                }
            }
        }
    }

    private var sameGrowthStageList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("E-L Growth Stages")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Button {
                sharedGrowthStageId = nil
                for pid in selectedPaddockIds {
                    paddockPhenologyStages.removeValue(forKey: pid)
                }
            } label: {
                HStack {
                    Image(systemName: sharedGrowthStageId == nil ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(sharedGrowthStageId == nil ? AnyShapeStyle(VineyardTheme.olive) : AnyShapeStyle(.tertiary))
                    Text("Not Set").foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Divider().padding(.leading, 40)

            ForEach(phenologyStages) { stage in
                let isSelected = sharedGrowthStageId == stage.id
                Button {
                    sharedGrowthStageId = stage.id
                    for pid in selectedPaddockIds {
                        paddockPhenologyStages[pid] = stage.id
                    }
                } label: {
                    HStack {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(isSelected ? AnyShapeStyle(VineyardTheme.olive) : AnyShapeStyle(.tertiary))
                        Text(stage.code)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 56, alignment: .leading)
                        Text(stage.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                if stage.id != phenologyStages.last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var perPaddockGrowthStageList: some View {
        let paddocks = selectedPaddocks
        return VStack(spacing: 0) {
            ForEach(paddocks) { paddock in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(paddock.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        if let stageId = paddockPhenologyStages[paddock.id],
                           let stage = phenologyStages.first(where: { $0.id == stageId }) {
                            Text("\(stage.name) (\(stage.code))")
                                .font(.caption2)
                                .foregroundStyle(VineyardTheme.leafGreen)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("Not Set") { paddockPhenologyStages.removeValue(forKey: paddock.id) }
                        ForEach(phenologyStages) { stage in
                            Button("\(stage.code) – \(stage.name)") {
                                paddockPhenologyStages[paddock.id] = stage.id
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if let stageId = paddockPhenologyStages[paddock.id],
                               let stage = phenologyStages.first(where: { $0.id == stageId }) {
                                Text(stage.code).font(.caption.weight(.semibold))
                            } else {
                                Text("Select").font(.caption)
                            }
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                        .foregroundStyle(VineyardTheme.olive)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VineyardTheme.olive.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                if paddock.id != paddocks.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var irrigationDataSection: some View {
        let paddocksWithIrrigation = selectedPaddocks.filter { $0.litresPerHaPerHour != nil }
        return Group {
            if !paddocksWithIrrigation.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Irrigation Data", icon: "drop.circle.fill")
                    Text("Based on dripper spacing & flow rates")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(paddocksWithIrrigation) { paddock in
                            if let lPerHaHr = paddock.litresPerHaPerHour,
                               let mlPerHaHr = paddock.mlPerHaPerHour,
                               let mmHr = paddock.mmPerHour {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text(paddock.name)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                    }
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("L/ha/hr").font(.caption2).foregroundStyle(.secondary)
                                            Text(String(format: "%.0f", lPerHaHr))
                                                .font(.title3.bold())
                                                .foregroundStyle(.blue)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("ML/ha/hr").font(.caption2).foregroundStyle(.secondary)
                                            Text(String(format: "%.4f", mlPerHaHr))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.blue)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("mm/hr").font(.caption2).foregroundStyle(.secondary)
                                            Text(String(format: "%.2f", mmHr))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.teal)
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(12)
                                if paddock.id != paddocksWithIrrigation.last?.id {
                                    Divider().padding(.leading, 12)
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
    }

    private var equipmentSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(duration: 0.3)) { isEquipmentExpanded.toggle() }
            } label: {
                HStack {
                    SectionHeader(title: "Equipment", icon: "wrench.and.screwdriver")
                    Spacer()
                    if let id = selectedEquipmentId,
                       let eq = store.sprayEquipment.first(where: { $0.id == id }) {
                        Text(eq.name)
                            .font(.caption)
                            .foregroundStyle(VineyardTheme.olive)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isEquipmentExpanded ? 90 : 0))
                }
            }

            if isEquipmentExpanded {
                VStack(spacing: 0) {
                    if store.sprayEquipment.isEmpty {
                        Text("No equipment configured — add one in Equipment Management")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(store.sprayEquipment) { item in
                        let isSelected = selectedEquipmentId == item.id
                        Button {
                            selectedEquipmentId = item.id
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(isSelected ? AnyShapeStyle(VineyardTheme.olive) : AnyShapeStyle(.tertiary))
                                Text(item.name).foregroundStyle(.primary)
                                Spacer()
                                Text("\(item.tankCapacityLitres, specifier: "%.0f") L")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        if item.id != store.sprayEquipment.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var waterRateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Calculated Water Rate", icon: "drop.fill")
            Text("Based on row widths & canopy status")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("VSP Canopy Size")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Picker("Canopy Size", selection: $canopySize) {
                        ForEach(CanopySize.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(canopySize.description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Canopy Density")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Picker("Canopy Density", selection: $canopyDensity) {
                        ForEach(CanopyDensity.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.0f", waterRateEntry.litresPerHa)) L/ha")
                            .font(.title3.bold())
                            .foregroundStyle(VineyardTheme.olive)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Per 100m row")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(String(format: "%.0f", waterRateEntry.litresPer100m)) L")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(12)
                .background(VineyardTheme.olive.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))

                Text("Row spacing: \(String(format: "%.1f", averageRowSpacing))m")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if operationType.useConcentrationFactor {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Spray Rate & Concentration Factor")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chosen Spray Rate (L/ha)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("L/ha", text: $sprayRateText)
                                    .keyboardType(.decimalPad)
                                    .font(.body.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                    .clipShape(.rect(cornerRadius: 8))
                                    .onChange(of: sprayRateText) { _, _ in hasEditedSprayRate = true }
                            }
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("CF").font(.caption).foregroundStyle(.secondary)
                                Text(String(format: "%.2f", concentrationFactor))
                                    .font(.title2.bold())
                                    .foregroundStyle(concentrationFactor == 1.0 ? VineyardTheme.olive : .orange)
                            }
                            .frame(minWidth: 60)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 10))
        }
        .onChange(of: waterRateEntry.litresPerHa) { _, newValue in
            if !hasEditedSprayRate {
                sprayRateText = String(format: "%.0f", newValue)
            }
        }
        .onAppear {
            if sprayRateText.isEmpty {
                sprayRateText = String(format: "%.0f", waterRateEntry.litresPerHa)
            }
        }
    }

    private var tractorSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Tractor (optional)", icon: "truck.pickup.side.fill")
            VStack(spacing: 0) {
                Button {
                    selectedTractorId = nil
                } label: {
                    HStack {
                        Image(systemName: selectedTractorId == nil ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selectedTractorId == nil ? AnyShapeStyle(VineyardTheme.olive) : AnyShapeStyle(.tertiary))
                        Text("Not Set").foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                ForEach(store.tractors) { tractor in
                    let isSelected = selectedTractorId == tractor.id
                    Divider().padding(.leading, 40)
                    Button {
                        selectedTractorId = tractor.id
                    } label: {
                        HStack {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(isSelected ? AnyShapeStyle(VineyardTheme.olive) : AnyShapeStyle(.tertiary))
                            Text(tractor.displayName).foregroundStyle(.primary)
                            Spacer()
                            if tractor.fuelUsageLPerHour > 0 {
                                Text("\(String(format: "%.1f", tractor.fuelUsageLPerHour)) L/hr")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var chemicalLinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Chemicals", icon: "flask")

            ForEach($chemicalLines) { $line in
                CalcChemicalLineCard(
                    line: $line,
                    chemicals: store.savedChemicals
                ) {
                    chemicalLines.removeAll { $0.id == line.id }
                }
            }

            Button {
                if let chem = store.savedChemicals.first {
                    let rate = chem.rates.first
                    chemicalLines.append(
                        ChemicalLine(
                            chemicalId: chem.id,
                            selectedRateId: rate?.id ?? UUID(),
                            basis: rate?.basis ?? .perHectare
                        )
                    )
                }
            } label: {
                Label("Add Chemical", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(VineyardTheme.olive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(VineyardTheme.olive.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 10))
            }
            .disabled(store.savedChemicals.isEmpty)

            Button {
                showAddChemicalToList = true
            } label: {
                Label("Add New Chemical to List", systemImage: "flask.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(VineyardTheme.leafGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(VineyardTheme.leafGreen.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 10))
            }

            if store.savedChemicals.isEmpty {
                Text("No chemicals configured. Tap “Add New Chemical to List” to create one.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Weather (optional)", icon: "cloud.sun")

            Button {
                Task { await fetchWeather() }
            } label: {
                HStack(spacing: 8) {
                    if isFetchingWeather {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "cloud.sun.bolt")
                    }
                    Text(isFetchingWeather ? "Fetching weather…" : "Fetch Weather")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if let fetched = weatherFetchedAt {
                        Text(fetched.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(VineyardTheme.olive)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(VineyardTheme.olive.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))
            }
            .disabled(isFetchingWeather)

            if let weatherFetchError {
                Label(weatherFetchError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
            } else if let source = weatherSource, let fetched = weatherFetchedAt {
                let stationSuffix = weatherStationId.map { " • \($0)" } ?? ""
                Text("\(source)\(stationSuffix) • \(fetched.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 10) {
                HStack {
                    Label("Temperature", systemImage: "thermometer")
                        .font(.subheadline)
                    Spacer()
                    TextField("°C", text: $temperatureText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Divider()
                HStack {
                    Label("Wind Speed", systemImage: "wind")
                        .font(.subheadline)
                    Spacer()
                    TextField("km/h", text: $windSpeedText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Divider()
                HStack {
                    Label("Wind Direction", systemImage: "location.north.line")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $windDirection) {
                        Text("—").tag("")
                        ForEach(WindDirection.allCases, id: \.rawValue) { dir in
                            Text(dir.rawValue).tag(dir.rawValue)
                        }
                    }
                    .labelsHidden()
                }
                Divider()
                HStack {
                    Label("Humidity", systemImage: "humidity")
                        .font(.subheadline)
                    Spacer()
                    TextField("%", text: $humidityText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notes", icon: "note.text")
            TextField("Add notes about this spray job...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                saveAndStartJob()
            } label: {
                Label("Create Spray Job & Start", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(VineyardTheme.olive)
            .disabled(!formIsValid)

            Button {
                saveForLater()
            } label: {
                Label("Save Job for Future Use", systemImage: "clock.badge.checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(VineyardTheme.leafGreen)
            .disabled(!formIsValid)
        }
    }

    // MARK: - Calculation & Save

    private func performCalculation(jobDurationHours: Double = 0) {
        guard let equipId = selectedEquipmentId,
              let equip = store.sprayEquipment.first(where: { $0.id == equipId }) else { return }

        let tractor: Tractor? = selectedTractorId.flatMap { id in
            store.tractors.first(where: { $0.id == id })
        }

        calculationResult = SprayCalculator.calculate(
            selectedPaddocks: selectedPaddocks,
            waterRateLitresPerHectare: chosenSprayRate,
            tankCapacity: equip.tankCapacityLitres,
            chemicalLines: chemicalLines,
            chemicals: store.savedChemicals,
            concentrationFactor: concentrationFactor,
            operationType: operationType,
            tractor: tractor,
            jobDurationHours: jobDurationHours,
            fuelCostPerLitre: store.seasonFuelCostPerLitre
        )
        withAnimation(.spring(duration: 0.4)) { showResults = true }
    }

    private func buildSprayTanks(result: SprayCalculationResult, tankCapacity: Double) -> [SprayTank] {
        let totalTanks = result.fullTankCount + (result.lastTankLitres > 0 ? 1 : 0)
        guard totalTanks > 0 else {
            return [SprayTank(tankNumber: 1, waterVolume: 0, sprayRatePerHa: chosenSprayRate, concentrationFactor: concentrationFactor)]
        }

        var tanks: [SprayTank] = []
        for i in 0..<totalTanks {
            let isLast = (i == totalTanks - 1)
            let waterVolume = isLast && result.lastTankLitres > 0 ? result.lastTankLitres : tankCapacity
            let chemicals: [SprayChemical] = result.chemicalResults.map { chemResult in
                let amount = isLast ? chemResult.amountInLastTank : chemResult.amountPerFullTank
                return SprayChemical(
                    name: chemResult.chemicalName,
                    volumePerTank: amount,
                    ratePerHa: chemResult.basis == .perHectare ? chemResult.selectedRate : 0,
                    ratePer100L: chemResult.basis == .per100Litres ? chemResult.selectedRate : 0,
                    costPerUnit: 0,
                    unit: chemResult.unit
                )
            }
            tanks.append(
                SprayTank(
                    tankNumber: i + 1,
                    waterVolume: waterVolume,
                    sprayRatePerHa: chosenSprayRate,
                    concentrationFactor: concentrationFactor,
                    chemicals: chemicals
                )
            )
        }
        return tanks
    }

    private func currentWeatherSnapshot() -> (temperature: Double?, windSpeed: Double?, windDirection: String, humidity: Double?) {
        (Double(temperatureText), Double(windSpeedText), windDirection, Double(humidityText))
    }

    private func resolveWeatherCoordinate() -> CLLocationCoordinate2D? {
        for paddock in selectedPaddocks {
            let pts = paddock.polygonPoints
            guard !pts.isEmpty else { continue }
            let lat = pts.map(\.latitude).reduce(0, +) / Double(pts.count)
            let lon = pts.map(\.longitude).reduce(0, +) / Double(pts.count)
            if lat != 0 || lon != 0 {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        return locationService.location?.coordinate
    }

    private func fetchWeather() async {
        guard !isFetchingWeather else { return }
        guard let coordinate = resolveWeatherCoordinate() else {
            weatherFetchError = "No location available. Select a paddock with a boundary or enable location services."
            return
        }
        isFetchingWeather = true
        weatherFetchError = nil
        defer { isFetchingWeather = false }

        let stationId = store.settings.weatherStationId
        let service = WeatherCurrentService()
        do {
            let snapshot = try await service.fetch(coordinate: coordinate, stationId: stationId)
            if let t = snapshot.temperatureC {
                temperatureText = String(format: "%.1f", t)
            }
            if let w = snapshot.windSpeedKmh {
                windSpeedText = String(format: "%.1f", w)
            }
            if !snapshot.windDirection.isEmpty {
                windDirection = snapshot.windDirection
            }
            if let h = snapshot.humidityPercent {
                humidityText = String(format: "%.0f", h)
            }
            weatherFetchedAt = snapshot.observedAt
            weatherStationId = snapshot.stationId
            weatherSource = snapshot.source
        } catch {
            weatherFetchError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveAndStartJob() {
        guard formIsValid else { return }
        guard !accessControl.isLoading else { return }
        guard accessControl.canCreateOperationalRecords else {
            errorMessage = "Your role does not allow creating spray records."
            return
        }
        guard let equipId = selectedEquipmentId,
              let equip = store.sprayEquipment.first(where: { $0.id == equipId }) else { return }
        guard let vineyardId = store.selectedVineyardId else {
            errorMessage = "No vineyard selected."
            return
        }

        if tracking.activeTrip != nil {
            errorMessage = "A trip is already in progress. End it before starting a new spray."
            return
        }
        errorMessage = nil

        performCalculation()

        let firstPaddock = selectedPaddocks.first
        let paddockNames = selectedPaddocks.map { $0.name }.joined(separator: ", ")

        tracking.startTrip(
            type: .spray,
            paddockId: firstPaddock?.id,
            paddockName: paddockNames,
            trackingPattern: .sequential,
            personName: auth.userName ?? ""
        )

        guard let activeTrip = tracking.activeTrip else {
            errorMessage = tracking.errorMessage ?? "Could not start trip."
            return
        }

        let weather = currentWeatherSnapshot()
        let tanks: [SprayTank] = {
            guard let result = calculationResult else { return [] }
            return buildSprayTanks(result: result, tankCapacity: equip.tankCapacityLitres)
        }()

        var tripWithTanks = activeTrip
        tripWithTanks.totalTanks = tanks.count
        store.updateTrip(tripWithTanks)

        let tractorName = selectedTractorId.flatMap { id in
            store.tractors.first(where: { $0.id == id })?.displayName
        } ?? ""

        let record = SprayRecord(
            tripId: activeTrip.id,
            vineyardId: vineyardId,
            date: Date(),
            startTime: Date(),
            temperature: weather.temperature,
            windSpeed: weather.windSpeed,
            windDirection: weather.windDirection,
            humidity: weather.humidity,
            sprayReference: sprayName,
            tanks: tanks,
            notes: notes,
            equipmentType: equip.name,
            tractor: tractorName,
            isTemplate: false,
            operationType: operationType
        )
        store.addSprayRecord(record)

        savedFeedback.toggle()
        summaryJobStarted = true
        showSummary = true
    }

    private func saveForLater() {
        guard formIsValid else { return }
        guard accessControl.canCreateOperationalRecords else {
            errorMessage = "Your role does not allow creating spray records."
            return
        }
        guard let equipId = selectedEquipmentId,
              let equip = store.sprayEquipment.first(where: { $0.id == equipId }) else { return }
        guard let vineyardId = store.selectedVineyardId else {
            errorMessage = "No vineyard selected."
            return
        }
        errorMessage = nil

        performCalculation()

        // Create a placeholder inactive trip so the record shows up under
        // "Not Started" in the spray program picker.
        let firstPaddock = selectedPaddocks.first
        let paddockNames = selectedPaddocks.map { $0.name }.joined(separator: ", ")
        let placeholderTrip = Trip(
            id: UUID(),
            vineyardId: vineyardId,
            paddockId: firstPaddock?.id,
            paddockName: paddockNames,
            paddockIds: selectedPaddocks.map { $0.id },
            startTime: Date(),
            endTime: nil,
            isActive: false
        )
        store.startTrip(placeholderTrip)

        let weather = currentWeatherSnapshot()
        let tanks: [SprayTank] = {
            guard let result = calculationResult else { return [] }
            return buildSprayTanks(result: result, tankCapacity: equip.tankCapacityLitres)
        }()

        let tractorName = selectedTractorId.flatMap { id in
            store.tractors.first(where: { $0.id == id })?.displayName
        } ?? ""

        let record = SprayRecord(
            tripId: placeholderTrip.id,
            vineyardId: vineyardId,
            date: Date(),
            startTime: Date(),
            temperature: weather.temperature,
            windSpeed: weather.windSpeed,
            windDirection: weather.windDirection,
            humidity: weather.humidity,
            sprayReference: sprayName,
            tanks: tanks,
            notes: notes,
            equipmentType: equip.name,
            tractor: tractorName,
            isTemplate: false,
            operationType: operationType
        )
        store.addSprayRecord(record)

        savedFeedback.toggle()
        summaryJobStarted = false
        showSummary = true
    }
}

// MARK: - Chemical Line Card

private struct CalcChemicalLineCard: View {
    @Binding var line: ChemicalLine
    let chemicals: [SavedChemical]
    let onDelete: () -> Void

    private var selectedChemical: SavedChemical? {
        chemicals.first(where: { $0.id == line.chemicalId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundStyle(VineyardTheme.leafGreen)
                    .font(.subheadline)
                Text(selectedChemical?.name ?? "Select Chemical")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let chem = selectedChemical,
                   let rate = chem.rates.first(where: { $0.id == line.selectedRateId }) {
                    Text(rate.basis == .perHectare ? "Per Ha" : "Per 100L")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rate.basis == .perHectare ? VineyardTheme.olive.opacity(0.15) : Color.blue.opacity(0.15))
                        .foregroundStyle(rate.basis == .perHectare ? VineyardTheme.olive : .blue)
                        .clipShape(Capsule())
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chemical").font(.caption).foregroundStyle(.secondary)
                Picker("Chemical", selection: $line.chemicalId) {
                    ForEach(chemicals) { chem in
                        Text(chem.name).tag(chem.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: line.chemicalId) { _, newValue in
                    if let chem = chemicals.first(where: { $0.id == newValue }),
                       let firstRate = chem.rates.first {
                        line.selectedRateId = firstRate.id
                        line.basis = firstRate.basis
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if let chem = selectedChemical, !chem.rates.isEmpty {
                let haRates = chem.rates.filter { $0.basis == .perHectare }
                let per100LRates = chem.rates.filter { $0.basis == .per100Litres }

                Divider().padding(.leading, 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate").font(.caption).foregroundStyle(.secondary)
                    Picker("Rate", selection: $line.selectedRateId) {
                        if !haRates.isEmpty {
                            Section("Per Hectare") {
                                ForEach(haRates) { rate in
                                    Text("\(rate.label): \(String(format: "%.0f", chem.unit.fromBase(rate.value))) \(chem.unit.rawValue)/ha")
                                        .tag(rate.id)
                                }
                            }
                        }
                        if !per100LRates.isEmpty {
                            Section("Per 100L Water") {
                                ForEach(per100LRates) { rate in
                                    Text("\(rate.label): \(String(format: "%.0f", chem.unit.fromBase(rate.value))) \(chem.unit.rawValue)/100L")
                                        .tag(rate.id)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: line.selectedRateId) { _, newRateId in
                        if let rate = chem.rates.first(where: { $0.id == newRateId }) {
                            line.basis = rate.basis
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
    }
}

// MARK: - Results Card

private struct ResultsCard: View {
    let result: SprayCalculationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results").font(.title2.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                CalcStatTile(title: "Total Area", value: "\(String(format: "%.2f", result.totalAreaHectares)) ha", icon: "square.dashed", color: VineyardTheme.olive)
                CalcStatTile(title: "Total Water", value: "\(String(format: "%.0f", result.totalWaterLitres)) L", icon: "drop.fill", color: .blue)
                CalcStatTile(title: "Full Tanks", value: "\(result.fullTankCount)", icon: "fuelpump.fill", color: VineyardTheme.earthBrown)
                CalcStatTile(title: "Last Tank", value: "\(String(format: "%.0f", result.lastTankLitres)) L", icon: "drop.halffull", color: .orange)
            }

            if result.concentrationFactor != 1.0 {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Concentration Factor")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(String(format: "%.2f", result.concentrationFactor))×")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(result.concentrationFactor > 1.0 ? "Concentrate" : "Dilute")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 6))
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 10))
            }

            ForEach(result.chemicalResults) { chemResult in
                CalcChemicalResultRow(result: chemResult)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
}

private struct CalcStatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
    }
}

private struct CalcChemicalResultRow: View {
    let result: ChemicalCalculationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flask.fill")
                    .foregroundStyle(VineyardTheme.leafGreen)
                Text(result.chemicalName).font(.headline)
                Spacer()
                Text("\(result.unit.fromBase(result.totalAmountRequired), specifier: "%.1f") \(result.unit.rawValue)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VineyardTheme.olive)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Per full tank").font(.caption).foregroundStyle(.secondary)
                    Text("\(result.unit.fromBase(result.amountPerFullTank), specifier: "%.1f") \(result.unit.rawValue)")
                        .font(.subheadline.weight(.medium))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last tank").font(.caption).foregroundStyle(.secondary)
                    Text("\(result.unit.fromBase(result.amountInLastTank), specifier: "%.1f") \(result.unit.rawValue)")
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
                Text("\(String(format: "%.0f", result.unit.fromBase(result.selectedRate))) \(result.unit.rawValue)/\(result.basis == .perHectare ? "ha" : "100L")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 10))
    }
}

// MARK: - Costings Card

private struct CostingsCard: View {
    let summary: SprayCostingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title3)
                    .foregroundStyle(VineyardTheme.vineRed)
                Text("Costings").font(.title2.bold())
            }

            ForEach(summary.chemicalCosts) { cost in
                HStack {
                    Image(systemName: "flask.fill")
                        .foregroundStyle(VineyardTheme.leafGreen)
                        .font(.subheadline)
                    Text(cost.chemicalName).font(.subheadline.weight(.semibold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(String(format: "%.2f", cost.totalCost))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(VineyardTheme.vineRed)
                        Text("$\(String(format: "%.2f", cost.costPerHectare))/ha")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 8))
            }

            if let fuel = summary.fuelCost {
                HStack {
                    Image(systemName: "fuelpump.fill")
                        .foregroundStyle(.orange)
                    Text("Fuel — \(fuel.tractorName)").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("$\(String(format: "%.2f", fuel.totalFuelCost))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.orange)
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 8))
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grand Total").font(.subheadline).foregroundStyle(.secondary)
                    Text("$\(String(format: "%.2f", summary.grandTotal))")
                        .font(.title.bold())
                        .foregroundStyle(VineyardTheme.vineRed)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Per Hectare").font(.subheadline).foregroundStyle(.secondary)
                    Text("$\(String(format: "%.2f", summary.grandTotalPerHectare))/ha")
                        .font(.title3.bold())
                        .foregroundStyle(VineyardTheme.earthBrown)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
}
