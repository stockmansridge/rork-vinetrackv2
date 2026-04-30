import SwiftUI
import RevenueCat
import RevenueCatUI

/// Subscription paywall.
///
/// Uses RevenueCatUI's `PaywallView` to render the current offering
/// configured in the RevenueCat dashboard. The dashboard exposes only
/// the legacy V1 products:
///   • $9.99 / month (3-month free trial)
///   • $99   / year  (3-month free trial)
struct SubscriptionPaywallView: View {
    @Environment(SubscriptionService.self) private var subscription
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let allowDismiss: Bool

    init(allowDismiss: Bool = false) {
        self.allowDismiss = allowDismiss
    }

    var body: some View {
        ZStack {
            if let offering = subscription.currentOffering {
                PaywallView(offering: offering, displayCloseButton: allowDismiss)
                    .onPurchaseCompleted { info in
                        if info.entitlements[SubscriptionService.entitlementIdentifier]?.isActive == true {
                            if allowDismiss { dismiss() }
                        }
                    }
                    .onRestoreCompleted { info in
                        if info.entitlements[SubscriptionService.entitlementIdentifier]?.isActive == true {
                            if allowDismiss { dismiss() }
                        }
                    }
            } else {
                fallbackView
            }
        }
        .task {
            await subscription.refreshOfferings()
        }
        .toolbar {
            if !allowDismiss {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        Task {
                            await subscription.logout()
                            await auth.signOut()
                        }
                    }
                    .tint(.red)
                }
            }
        }
    }

    private var fallbackView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Loading subscription options…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let error = subscription.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("Retry") {
                Task { await subscription.refreshOfferings() }
            }
            .buttonStyle(.borderedProminent)

            Button("Restore Purchases") {
                Task { await subscription.restorePurchases() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
