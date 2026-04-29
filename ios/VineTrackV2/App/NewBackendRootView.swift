import SwiftUI

struct NewBackendRootView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var didAttemptRestore: Bool = false
    @State private var onboardingCompleted: Bool = OnboardingState.isCompleted
    @State private var disclaimerAccepted: Bool = false
    @State private var didCheckDisclaimer: Bool = false
    @State private var isCheckingDisclaimer: Bool = false
    @State private var disclaimerError: String?

    private let disclaimerRepository: any DisclaimerRepositoryProtocol = SupabaseDisclaimerRepository(currentVersion: DisclaimerInfo.version)

    var body: some View {
        Group {
            if !didAttemptRestore {
                loadingView
            } else if !auth.isSignedIn {
                NewBackendLoginView()
            } else if !onboardingCompleted {
                OnboardingView {
                    OnboardingState.markCompleted()
                    onboardingCompleted = true
                }
            } else if !didCheckDisclaimer {
                disclaimerLoadingView
            } else if !disclaimerAccepted {
                DisclaimerAcceptanceView {
                    disclaimerAccepted = true
                }
            } else if store.selectedVineyard == nil {
                BackendVineyardListView()
            } else {
                NewMainTabView()
            }
        }
        .task {
            if !didAttemptRestore {
                await auth.restoreSession()
                didAttemptRestore = true
            }
        }
        .task(id: auth.isSignedIn) {
            if auth.isSignedIn {
                await checkDisclaimer()
            } else {
                disclaimerAccepted = false
                didCheckDisclaimer = false
            }
        }
        .task(id: store.selectedVineyardId) {
            if store.selectedVineyardId != nil {
                DefaultDataSeeder.seedIfNeeded(store: store)
            }
        }
        .task(id: auth.isSignedIn) {
            if auth.isSignedIn {
                await auth.loadPendingInvitations()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && auth.isSignedIn {
                Task { await auth.loadPendingInvitations() }
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [VineyardTheme.cream, VineyardTheme.stone.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(VineyardTheme.leafGreen.gradient)
                        .frame(width: 80, height: 80)
                    GrapeLeafIcon(size: 40, color: .white)
                }
                ProgressView()
                Text("Loading…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var disclaimerLoadingView: some View {
        ZStack {
            VineyardTheme.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                if isCheckingDisclaimer {
                    ProgressView()
                    Text("Checking disclaimer status…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let disclaimerError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                    Text("Couldn't verify disclaimer")
                        .font(.headline)
                    Text(disclaimerError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") {
                        Task { await checkDisclaimer() }
                    }
                    .buttonStyle(.vineyardPrimary)
                    .padding(.horizontal, 40)
                }
            }
        }
    }

    private func checkDisclaimer() async {
        isCheckingDisclaimer = true
        disclaimerError = nil
        defer { isCheckingDisclaimer = false }
        do {
            let accepted = try await disclaimerRepository.hasAcceptedCurrentDisclaimer()
            disclaimerAccepted = accepted
            didCheckDisclaimer = true
        } catch {
            disclaimerError = error.localizedDescription
            didCheckDisclaimer = false
        }
    }
}
