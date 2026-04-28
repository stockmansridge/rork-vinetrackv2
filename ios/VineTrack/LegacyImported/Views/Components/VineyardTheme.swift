import SwiftUI
import UIKit

enum VineyardTheme {
    // Brand palette
    static let leafGreen = Color(red: 0.36, green: 0.55, blue: 0.30)
    static let olive = Color(red: 0.45, green: 0.50, blue: 0.25)
    static let earthBrown = Color(red: 0.45, green: 0.32, blue: 0.22)
    static let vineRed = Color(red: 0.55, green: 0.18, blue: 0.22)
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.88)
    static let stone = Color(red: 0.78, green: 0.74, blue: 0.66)

    // Semantic roles
    static let primary = olive
    static let primaryAccent = leafGreen
    static let success = leafGreen
    static let warning = Color.orange
    static let destructive = Color.red
    // Info: a vineyard-aligned slate/teal — distinct from olive but never iOS system blue
    static let info = Color(red: 0.28, green: 0.46, blue: 0.50)

    // Surfaces (light/clean look, adapts to dark mode through system colors)
    static let appBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let cardBorder = Color(.separator).opacity(0.5)

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    // MARK: - Global Appearance
    /// Configures UIKit appearance proxies so navigation bars, tab bars, and toolbars
    /// match the VineTrack brand instead of falling back to default iOS system blue.
    static func applyGlobalAppearance() {
        let oliveUI = UIColor(olive)
        let leafUI = UIColor(leafGreen)
        let textUI = UIColor.label

        // Navigation bar — clean white/light with dark titles and olive tint for buttons
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.shadowColor = UIColor.separator.withAlphaComponent(0.4)
        navAppearance.titleTextAttributes = [
            .foregroundColor: textUI,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: textUI,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: oliveUI]
        navAppearance.buttonAppearance = buttonAppearance
        navAppearance.backButtonAppearance = buttonAppearance
        navAppearance.doneButtonAppearance = buttonAppearance

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = oliveUI

        // Tab bar — clean white with olive selected items
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor.systemBackground
        tabAppearance.shadowColor = UIColor.separator.withAlphaComponent(0.4)

        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: oliveUI,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        let unselectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        for item in [tabAppearance.stackedLayoutAppearance, tabAppearance.inlineLayoutAppearance, tabAppearance.compactInlineLayoutAppearance] {
            item.selected.iconColor = oliveUI
            item.selected.titleTextAttributes = selectedAttrs
            item.normal.iconColor = UIColor.secondaryLabel
            item.normal.titleTextAttributes = unselectedAttrs
        }
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = oliveUI
        UITabBar.appearance().unselectedItemTintColor = UIColor.secondaryLabel

        // Global tints for UIKit-bridged controls (UISwitch, UIRefreshControl, etc.)
        UISwitch.appearance().onTintColor = leafUI
        UIRefreshControl.appearance().tintColor = oliveUI
    }
}

struct GrapeLeafIcon: View {
    var size: CGFloat = 14
    var color: Color = VineyardTheme.olive

    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
    }
}

// MARK: - Reusable Components

struct VineyardCard<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VineyardTheme.cardBackground, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(VineyardTheme.cardBorder, lineWidth: 0.5)
            )
    }
}

struct VineyardSectionHeader: View {
    let title: String
    var icon: String? = nil
    var iconColor: Color = VineyardTheme.olive

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(VineyardTheme.textSecondary)
        }
    }
}

struct VineyardPrimaryButtonStyle: ButtonStyle {
    var tint: Color = VineyardTheme.olive
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(tint, in: .rect(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct VineyardSecondaryButtonStyle: ButtonStyle {
    var tint: Color = VineyardTheme.olive
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(tint.opacity(0.10), in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct VineyardDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(VineyardTheme.destructive, in: .rect(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == VineyardPrimaryButtonStyle {
    static var vineyardPrimary: VineyardPrimaryButtonStyle { .init() }
    static func vineyardPrimary(tint: Color) -> VineyardPrimaryButtonStyle { .init(tint: tint) }
}

extension ButtonStyle where Self == VineyardSecondaryButtonStyle {
    static var vineyardSecondary: VineyardSecondaryButtonStyle { .init() }
    static func vineyardSecondary(tint: Color) -> VineyardSecondaryButtonStyle { .init(tint: tint) }
}

extension ButtonStyle where Self == VineyardDestructiveButtonStyle {
    static var vineyardDestructive: VineyardDestructiveButtonStyle { .init() }
}

struct VineyardEmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(VineyardTheme.primaryAccent.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(VineyardTheme.primaryAccent)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(VineyardTheme.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(VineyardTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                }
                .buttonStyle(.vineyardPrimary)
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VineyardTheme.appBackground)
    }
}

enum VineyardBadgeKind {
    case success, warning, destructive, info, neutral

    var background: Color {
        switch self {
        case .success: return VineyardTheme.success.opacity(0.15)
        case .warning: return VineyardTheme.warning.opacity(0.18)
        case .destructive: return VineyardTheme.destructive.opacity(0.15)
        case .info: return VineyardTheme.info.opacity(0.15)
        case .neutral: return Color(.tertiarySystemFill)
        }
    }

    var foreground: Color {
        switch self {
        case .success: return VineyardTheme.success
        case .warning: return VineyardTheme.warning
        case .destructive: return VineyardTheme.destructive
        case .info: return VineyardTheme.info
        case .neutral: return .secondary
        }
    }
}

struct VineyardStatusBadge: View {
    let text: String
    var icon: String? = nil
    var kind: VineyardBadgeKind = .neutral

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(kind.foreground)
        .background(kind.background, in: .capsule)
    }
}

struct VineyardFilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : VineyardTheme.textPrimary)
            .background(
                isSelected ? VineyardTheme.olive : Color(.tertiarySystemFill),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
    }
}

struct VineyardInfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = VineyardTheme.olive

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
            }
            Text(label)
                .foregroundStyle(VineyardTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(VineyardTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

enum VineyardSyncState {
    case idle
    case syncing
    case success(Date?)
    case failure(String)
}

struct VineyardSyncStatusRow: View {
    let label: String
    let state: VineyardSyncState

    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .syncing:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Syncing \(label)…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .success(let date):
                if let date {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(VineyardTheme.success)
                        Text("Last synced \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .failure(let message):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(VineyardTheme.destructive)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(VineyardTheme.destructive)
                }
            }
        }
    }
}
