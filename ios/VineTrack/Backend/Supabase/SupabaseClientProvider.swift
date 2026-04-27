import Foundation
import Supabase

final class SupabaseClientProvider: Sendable {
    static let shared = SupabaseClientProvider()

    let client: SupabaseClient
    let supabaseURL: URL
    let isConfigured: Bool

    private init() {
        let configuration = SupabaseBackendConfiguration.current
        isConfigured = configuration.isConfigured
        supabaseURL = configuration.url
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey
        )
    }
}

nonisolated private struct SupabaseBackendConfiguration: Sendable {
    let url: URL
    let anonKey: String

    var isConfigured: Bool {
        !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var current: SupabaseBackendConfiguration {
        let bundle = Bundle.main
        let nativeURL = bundle.stringValue(for: "SUPABASE_URL")
        let fallbackURL = bundle.stringValue(for: "EXPO_PUBLIC_SUPABASE_URL")
        let nativeAnonKey = bundle.stringValue(for: "SUPABASE_ANON_KEY")
        let fallbackAnonKey = bundle.stringValue(for: "EXPO_PUBLIC_SUPABASE_ANON_KEY")
        let urlString = nativeURL.nonEmpty ?? fallbackURL.nonEmpty ?? "https://tbafuqwruefgkbyxrxyb.supabase.co"
        let anonKey = nativeAnonKey.nonEmpty ?? fallbackAnonKey.nonEmpty ?? ""
        let url = URL(string: urlString) ?? URL(string: "https://tbafuqwruefgkbyxrxyb.supabase.co")!
        return SupabaseBackendConfiguration(url: url, anonKey: anonKey)
    }
}

nonisolated private extension Bundle {
    func stringValue(for key: String) -> String {
        object(forInfoDictionaryKey: key) as? String ?? ""
    }
}

nonisolated private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
