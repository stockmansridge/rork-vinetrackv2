import SwiftUI

struct NewBackendRootView: View {
    @Environment(NewBackendAuthService.self) private var auth
    @Environment(MigratedDataStore.self) private var store
    @State private var didAttemptRestore: Bool = false

    var body: some View {
        Group {
            if !didAttemptRestore || auth.isLoading && !auth.isSignedIn {
                loadingView
            } else if !auth.isSignedIn {
                NewBackendLoginView()
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
}
