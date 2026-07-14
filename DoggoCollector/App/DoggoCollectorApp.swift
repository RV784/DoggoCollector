//
//  DoggoCollectorApp.swift
//  DoggoCollector
//

import SwiftUI
import SwiftData

@main
struct DoggoCollectorApp: App {
    private let modelContainer: ModelContainer
    @State private var authProvider: UsernameAuthProvider

    init() {
        do {
            modelContainer = try ModelContainer(
                for: CaughtDog.self, UserProfile.self, CareEntry.self,
                MedicationSchedule.self, MedicalRecord.self, MedicalAttachment.self
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
        }
        .modelContainer(modelContainer)
    }
}
