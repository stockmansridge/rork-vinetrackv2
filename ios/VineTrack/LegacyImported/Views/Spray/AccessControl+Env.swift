import SwiftUI

/// Lightweight, backend-neutral access control surface used by imported legacy
/// spray screens. In Phase 6E we default everything to `true` since there is
/// no role/permission system wired yet. A future phase can replace the env
/// value with a real implementation backed by Supabase team roles.
struct LegacyAccessControl {
    var canDelete: Bool = true
    var canExport: Bool = false
    var canExportFinancialPDF: Bool = false
    var canViewFinancials: Bool = true
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
