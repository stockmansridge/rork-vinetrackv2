import SwiftUI
import PhotosUI

/// Phase 6A — simplified backend-aware vineyard detail sheet.
///
/// Shows basic vineyard info and lets the user rename, change country, or
/// soft-delete the vineyard via `SupabaseVineyardRepository`. Local state is
/// kept in sync via `MigratedDataStore`.
///
/// Member management, invitations, audit logging, and access control are
/// intentionally NOT included — those will return in later phases when the
/// new auth/team services are wired in.
struct BackendVineyardDetailSheet: View {
    let initialVineyard: Vineyard
    let vineyardRepository: any VineyardRepositoryProtocol

    @Environment(MigratedDataStore.self) private var store
    @Environment(BackendAccessControl.self) private var accessControl
    @Environment(\.dismiss) private var dismiss

    @State private var showEditName: Bool = false
    @State private var editedName: String = ""
    @State private var selectedCountry: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var deleteConfirmationText: String = ""
    @State private var isWorking: Bool = false
    @State private var errorMessage: String?
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var showRemoveLogoConfirm: Bool = false

    init(
        vineyard: Vineyard,
        vineyardRepository: any VineyardRepositoryProtocol = SupabaseVineyardRepository()
    ) {
        self.initialVineyard = vineyard
        self.vineyardRepository = vineyardRepository
    }

    private var vineyard: Vineyard {
        store.vineyards.first(where: { $0.id == initialVineyard.id }) ?? initialVineyard
    }

    private static let wineCountries: [String] = [
        "Australia", "Argentina", "Austria", "Brazil", "Canada", "Chile", "China",
        "France", "Germany", "Greece", "Hungary", "India", "Israel", "Italy",
        "Japan", "Mexico", "New Zealand", "Portugal", "Romania", "South Africa",
        "Spain", "Switzerland", "United Kingdom", "United States", "Uruguay"
    ]

    var body: some View {
        NavigationStack {
            List {
                logoSection
                infoSection
                if accessControl.canChangeSettings {
                    dangerSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(vineyard.name)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                selectedCountry = vineyard.country
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isWorking)
                }
            }
            .alert("Rename Vineyard", isPresented: $showEditName) {
                TextField("Vineyard name", text: $editedName)
                Button("Save") {
                    Task { await rename() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete Vineyard?", isPresented: $showDeleteConfirm) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                Button("Delete", role: .destructive) {
                    Task { await deleteVineyard() }
                }
                .disabled(deleteConfirmationText != "DELETE")
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }
            } message: {
                Text("This will permanently delete the vineyard and all its data.")
            }
            .alert("Error", isPresented: errorBinding, presenting: errorMessage) { _ in
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

    private var logoSection: some View {
        Section {
            HStack(spacing: 16) {
                logoPreview
                VStack(alignment: .leading, spacing: 4) {
                    Text(vineyard.logoData == nil ? "No logo" : "Logo set")
                        .font(.subheadline.weight(.semibold))
                    Text("Logos appear on exported PDFs and reports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if accessControl.canChangeSettings {
                PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                    Label(vineyard.logoData == nil ? "Add Logo" : "Change Logo",
                          systemImage: vineyard.logoData == nil ? "photo.badge.plus" : "photo.badge.arrow.down")
                        .foregroundStyle(.primary)
                }
                .disabled(isWorking)

                if vineyard.logoData != nil {
                    Button(role: .destructive) {
                        showRemoveLogoConfirm = true
                    } label: {
                        Label("Remove Logo", systemImage: "trash")
                    }
                    .disabled(isWorking)
                }
            }
        } header: {
            Text("Vineyard Logo")
        } footer: {
            if !accessControl.canChangeSettings {
                Text("Only owners and managers can change the vineyard logo.")
            } else {
                Text("Stored locally on this device. Logo sync is not enabled yet.")
            }
        }
        .onChange(of: selectedLogoItem) { _, newItem in
            handleLogoSelection(newItem)
        }
        .alert("Remove Logo?", isPresented: $showRemoveLogoConfirm) {
            Button("Remove", role: .destructive) { removeLogo() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the logo from this device.")
        }
    }

    @ViewBuilder
    private var logoPreview: some View {
        if let data = vineyard.logoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 10))
                .clipShape(.rect(cornerRadius: 10))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(VineyardTheme.leafGreen.opacity(0.15))
                    .frame(width: 64, height: 64)
                GrapeLeafIcon(size: 28, color: VineyardTheme.leafGreen)
            }
        }
    }

    private func handleLogoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let maxSize: CGFloat = 512
                let scale = min(maxSize / uiImage.size.width, maxSize / uiImage.size.height, 1.0)
                let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resized = renderer.image { _ in
                    uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
                if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                    var updated = vineyard
                    updated.logoData = jpeg
                    store.upsertLocalVineyard(updated)
                }
            }
            selectedLogoItem = nil
        }
    }

    private func removeLogo() {
        var updated = vineyard
        updated.logoData = nil
        store.upsertLocalVineyard(updated)
    }

    private var infoSection: some View {
        Section {
            LabeledContent("Name", value: vineyard.name)
            LabeledContent("Created", value: vineyard.createdAt.formatted(date: .abbreviated, time: .omitted))

            Picker("Country", selection: $selectedCountry) {
                Text("Not Set").tag("")
                ForEach(Self.wineCountries, id: \.self) { c in
                    Text(c).tag(c)
                }
            }
            .disabled(!accessControl.canChangeSettings)
            .onChange(of: selectedCountry) { _, newValue in
                Task { await updateCountry(newValue) }
            }

            if accessControl.canChangeSettings {
                Button {
                    editedName = vineyard.name
                    showEditName = true
                } label: {
                    Label("Rename Vineyard", systemImage: "pencil")
                }
                .disabled(isWorking)
            }
        } header: {
            Text("Vineyard Info")
        } footer: {
            if !selectedCountry.isEmpty {
                Text("Chemical searches will prioritize products available in \(selectedCountry).")
            }
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                deleteConfirmationText = ""
                showDeleteConfirm = true
            } label: {
                Label("Delete Vineyard", systemImage: "trash")
            }
            .disabled(isWorking)
        } footer: {
            Text("Permanently deletes this vineyard from the backend. You'll need to type DELETE to confirm.")
        }
    }

    private func rename() async {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }

        let backend = BackendVineyard(
            id: vineyard.id,
            name: trimmed,
            ownerId: nil,
            country: vineyard.country.isEmpty ? nil : vineyard.country,
            logoPath: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil
        )
        do {
            try await vineyardRepository.updateVineyard(backend)
            var updated = vineyard
            updated.name = trimmed
            store.upsertLocalVineyard(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateCountry(_ newValue: String) async {
        guard newValue != vineyard.country else { return }
        isWorking = true
        defer { isWorking = false }

        let backend = BackendVineyard(
            id: vineyard.id,
            name: vineyard.name,
            ownerId: nil,
            country: newValue.isEmpty ? nil : newValue,
            logoPath: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil
        )
        do {
            try await vineyardRepository.updateVineyard(backend)
            var updated = vineyard
            updated.country = newValue
            store.upsertLocalVineyard(updated)
        } catch {
            errorMessage = error.localizedDescription
            selectedCountry = vineyard.country
        }
    }

    private func deleteVineyard() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await vineyardRepository.softDeleteVineyard(id: vineyard.id)
            let remaining = store.vineyards.filter { $0.id != vineyard.id }
            let mapped: [BackendVineyard] = remaining.map { local in
                BackendVineyard(
                    id: local.id,
                    name: local.name,
                    ownerId: nil,
                    country: local.country.isEmpty ? nil : local.country,
                    logoPath: nil,
                    createdAt: local.createdAt,
                    updatedAt: nil,
                    deletedAt: nil
                )
            }
            store.mapBackendVineyardsIntoLocal(mapped)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
