import Foundation
import Supabase

final class SupabaseClientProvider: Sendable {
    static let shared = SupabaseClientProvider()

    let client: SupabaseClient
    let supabaseURL: URL
    let isConfigured: Bool
    let configurationSummary: String

    private init() {
        let configuration = SupabaseBackendConfiguration.current
        isConfigured = configuration.isConfigured
        supabaseURL = configuration.url
        configurationSummary = configuration.summary
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey
        )
    }
}

nonisolated private struct SupabaseBackendConfiguration: Sendable {
    let url: URL
    let anonKey: String
    let urlSource: String
    let anonKeySource: String

    var isConfigured: Bool {
        !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var summary: String {
        "urlSource=\(urlSource), anonKeySource=\(anonKeySource), anonKeyPresent=\(isConfigured)"
    }

    static var current: SupabaseBackendConfiguration {
        let nativeURL = Config.allValues["SUPABASE_URL"]?.nonEmpty
        let fallbackURL = Config.EXPO_PUBLIC_SUPABASE_URL.nonEmpty
        let nativeAnonKey = Config.allValues["SUPABASE_ANON_KEY"]?.nonEmpty
        let fallbackAnonKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY.nonEmpty
        let urlString = nativeURL ?? fallbackURL ?? "https://tbafuqwruefgkbyxrxyb.supabase.co"
        let urlSource = nativeURL == nil ? (fallbackURL == nil ? "hardcoded project URL" : "Config.EXPO_PUBLIC_SUPABASE_URL") : "Config.SUPABASE_URL"
        let anonKey = nativeAnonKey ?? fallbackAnonKey ?? ""
        let anonKeySource = nativeAnonKey == nil ? (fallbackAnonKey == nil ? "missing" : "Config.EXPO_PUBLIC_SUPABASE_ANON_KEY") : "Config.SUPABASE_ANON_KEY"
        let url = URL(string: urlString) ?? URL(string: "https://tbafuqwruefgkbyxrxyb.supabase.co")!
        return SupabaseBackendConfiguration(url: url, anonKey: anonKey, urlSource: urlSource, anonKeySource: anonKeySource)
    }
}

nonisolated private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
