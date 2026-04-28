import SwiftUI
import MapKit

/// Phase 6A placeholder boundary editor.
///
/// The full map-tap-to-draw editor from the legacy app depends on
/// `LocationService` and several map helper views that haven't been imported yet.
/// This stub lets `EditPaddockSheet` compile and presents a clear placeholder
/// until the real editor is brought across in a later phase.
struct BoundaryMapEditor: View {
    @Binding var polygonPoints: [CoordinatePoint]
    let existingPaddocks: [Paddock]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "map")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Boundary Editor")
                    .font(.title2.weight(.semibold))
                Text("The interactive boundary editor will be re-imported in a later phase. For now, you can clear the boundary or keep existing points.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if !polygonPoints.isEmpty {
                    Text("\(polygonPoints.count) point\(polygonPoints.count == 1 ? "" : "s") set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Boundary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                if !polygonPoints.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) {
                            polygonPoints.removeAll()
                        }
                    }
                }
            }
        }
    }
}
