//
//  SettingsView.swift
//  DoggoCollector
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UsernameAuthProvider.self) private var authProvider

    @Environment(\.scenePhase) private var scenePhase
    @State private var locationProvider = LocationProvider()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showEditUsername = false
    @State private var editedUsername = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        settingsList
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                // No .glassCircleChrome() — the native bar already supplies
                // its own glass circle per toolbar item.
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(DoggoColor.ink)
                    }
                }
            }
            .alert("Edit username", isPresented: $showEditUsername) {
                TextField("Username", text: $editedUsername)
                Button("Save") { try? authProvider.updateUsername(editedUsername) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete account?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive, action: deleteAccount)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your pack and profile from this device. This can't be undone.")
            }
            .task {
                notificationStatus = await MedicationReminder.authorizationStatus()
            }
            // The toggle-off/denied path deep-links to system Settings —
            // without this, granting permission there and returning would
            // leave the toggle stuck showing "off" until this screen is
            // dismissed and reopened (unlike CareView's location status,
            // which is genuinely live via LocationProvider's delegate).
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { notificationStatus = await MedicationReminder.authorizationStatus() }
            }
    }

    private var settingsList: some View {
        List {
            Section("Profile") {
                Button {
                    editedUsername = authProvider.currentUsername ?? ""
                    showEditUsername = true
                } label: {
                    row(icon: "person.fill", title: "Username", value: authProvider.currentUsername ?? "")
                }
            }

            Section("Preferences") {
                Toggle(isOn: Binding(get: { notificationsEnabled }, set: handleNotificationToggle)) {
                    Label("Notifications", systemImage: "bell.fill")
                }
                HStack {
                    Label("Location", systemImage: "location.fill")
                    Spacer()
                    Text(locationStatusText)
                        .foregroundStyle(DoggoColor.inkMuted)
                }
            }

            Section("Support") {
                Link(destination: URL(string: "mailto:hello@doggocollector.app")!) {
                    Label("Help & contact", systemImage: "questionmark.circle.fill")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete account", systemImage: "trash.fill")
                }
            }
        }
    }

    private var notificationsEnabled: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional || notificationStatus == .ephemeral
    }

    /// Toggling on from `.notDetermined` requests permission directly;
    /// otherwise (already denied, or turning "off") apps can't change their
    /// own notification permission, so this deep-links to system Settings
    /// instead of faking a local off-state — same pattern as CareView's
    /// location row.
    private func handleNotificationToggle(_ newValue: Bool) {
        if newValue && notificationStatus == .notDetermined {
            Task {
                _ = await MedicationReminder.requestAuthorization()
                notificationStatus = await MedicationReminder.authorizationStatus()
            }
        } else {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private var locationStatusText: String {
        switch locationProvider.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: "Allowed"
        case .denied, .restricted: "Denied"
        default: "Not set"
        }
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value).foregroundStyle(DoggoColor.inkMuted)
        }
    }

    private func deleteAccount() {
        // Cancel every dog's reminders before the cascade-delete — without
        // this, stray "Time for {name}'s {drug}" notifications could still
        // fire for dogs that no longer exist until the next CollectionView
        // sweep happens to run.
        let allCatches = (try? modelContext.fetch(FetchDescriptor<CaughtDog>())) ?? []
        for dog in allCatches {
            MedicationReminder.cancelAll(for: dog)
        }
        try? modelContext.delete(model: CaughtDog.self)
        try? modelContext.delete(model: UserProfile.self)
        authProvider.signOut()
        dismiss()
    }
}
