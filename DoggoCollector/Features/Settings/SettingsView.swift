//
//  SettingsView.swift
//  DoggoCollector
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UsernameAuthProvider.self) private var authProvider

    @State private var locationProvider = LocationProvider()
    @State private var notificationsEnabled = false
    @State private var showEditUsername = false
    @State private var editedUsername = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            settingsList
        }
        .toolbar(.hidden, for: .navigationBar)
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
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(DoggoColor.ink)
                    .frame(width: 44, height: 44)
                    .background(DoggoColor.cardWhite, in: Circle())
            }
            Spacer()
            Text("Settings")
                .font(DoggoTextStyle.headline)
                .foregroundStyle(DoggoColor.ink)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, DoggoSpacing.lg)
        .padding(.top, DoggoSpacing.lg)
        .padding(.bottom, DoggoSpacing.sm)
        .background(DoggoColor.cream)
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
                Toggle(isOn: $notificationsEnabled) {
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
        try? modelContext.delete(model: CaughtDog.self)
        try? modelContext.delete(model: UserProfile.self)
        authProvider.signOut()
        dismiss()
    }
}
