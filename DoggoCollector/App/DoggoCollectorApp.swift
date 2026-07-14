//
//  DoggoCollectorApp.swift
//  DoggoCollector
//

import SwiftUI
import SwiftData

@main
struct DoggoCollectorApp: App {
    // Only needed for the CKShare-accept callback (decision #18) — see
    // AppDelegate/SceneDelegate's own comments for why this can't be a
    // pure-SwiftUI hook on this SDK.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer
    @State private var authProvider: UsernameAuthProvider
    @State private var shareCoordinator = CloudKitShareCoordinator.shared

    init() {
        do {
            // CloudKit-backed private sync (decision #18). Every model
            // passed here needs a literal default (or optionality) on
            // every stored property for CloudKit-backed SwiftData — see
            // CaughtDog.swift/UserProfile.swift's matching comment.
            let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.DoggoCollector"))
            modelContainer = try ModelContainer(
                for: CaughtDog.self, UserProfile.self, CareEntry.self,
                MedicationSchedule.self, MedicalRecord.self, MedicalAttachment.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        _authProvider = State(initialValue: UsernameAuthProvider(modelContext: modelContainer.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authProvider)
                // The app has no designed dark theme anywhere — every
                // DoggoColor value is a hardcoded light-mode hex. Without
                // this, native system-styled text (TextField input/
                // placeholder color, navigationTitle) silently follows the
                // system Dark Mode setting while those backgrounds don't,
                // producing invisible white-on-white/cream text (seen in
                // AddMedicationSheet's fields and TodaysCareView's title).
                // Pinning the whole app to light closes this out for good
                // rather than patching each affected screen individually.
                .preferredColorScheme(.light)
                .sheet(isPresented: Binding(
                    get: { shareCoordinator.pendingMetadata != nil },
                    set: { if !$0 { shareCoordinator.pendingMetadata = nil } }
                )) {
                    if let metadata = shareCoordinator.pendingMetadata {
                        HandoverAcceptSheet(metadata: metadata) {
                            shareCoordinator.pendingMetadata = nil
                        }
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
