import SwiftUI

/// Lightweight, backend-neutral access control surface used by imported legacy
/// spray screens. As of Phase 8A this defaults to a safely locked-down state
/// (all `false`); the real values are bridged in from `BackendAccessControl`
/// via `legacyAccessControl` based on the user's `BackendRole`.
struct LegacyAccessControl {
    var canDelete: Bool = false
    var canExport: Bool = false
    var canExportFinancialPDF: Bool = false
    var canViewFinancials: Bool = false
    var canFinalizeRecords: Bool = false
    var canReopenRecords: Bool = false
}

private struct LegacyAccessControlKey: EnvironmentKey {
    static let defaultValue: LegacyAccessControl? = LegacyAccessControl()
}

extension EnvironmentValues {
    var accessControl: LegacyAccessControl? {
        get { self[LegacyAccessControlKey.self] }
        set { self[LegacyAccessControlKey.self] = newValue }
    }
}
