//
//  VineTrackV2App.swift
//  VineTrackV2
//
//  Created by Rork on April 27, 2026.
//

import SwiftUI
import SwiftData

@main
struct VineTrackV2App: App {
    @State private var auth = NewBackendAuthService()
    @State private var migratedStore = MigratedDataStore()
    @State private var locationService = LocationService()
    @State private var degreeDayService = DegreeDayService()
    @State private var backendAccessControl = BackendAccessControl()
    @State private var tripTrackingService = TripTrackingService()
    @State private var pinSyncService = PinSyncService()
    @State private var paddockSyncService = PaddockSyncService()
    @State private var tripSyncService = TripSyncService()
    @State private var sprayRecordSyncService = SprayRecordSyncService()
    @State private var buttonConfigSyncService = ButtonConfigSyncService()

    init() {
        VineyardTheme.applyGlobalAppearance()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Item.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if AppFeatureFlags.useNewBackendShell {
                    NewBackendRootView()
                        .environment(auth)
                        .environment(migratedStore)
                        .environment(locationService)
                        .environment(degreeDayService)
                        .environment(backendAccessControl)
                        .environment(tripTrackingService)
                        .environment(pinSyncService)
                        .environment(paddockSyncService)
                        .environment(tripSyncService)
                        .environment(sprayRecordSyncService)
                        .environment(buttonConfigSyncService)
                } else {
                    ContentView()
                }
            }
            .tint(VineyardTheme.olive)
            .onOpenURL { url in
                Task { await auth.handleIncomingURL(url) }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
