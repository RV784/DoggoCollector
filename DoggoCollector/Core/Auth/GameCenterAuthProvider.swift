//
//  GameCenterAuthProvider.swift
//  DoggoCollector
//
//  Game Center identity in front of the local username flow — the "ditch
//  login" layer (see ~/Documents/game_center_integration.md). When the
//  device's Game Center account is signed in, authentication is silent and
//  automatic at launch: `currentUsername` becomes the player's own Game
//  Center alias and RootView skips onboarding entirely. When Game Center is
//  unavailable or declined, everything falls back to the wrapped
//  UsernameAuthProvider and the app behaves exactly as before — the typed
//  username flow survives as the fallback, not the front door.
//
//  Deliberately does NOT present Game Center's sign-in view controller
//  (the authenticateHandler's viewController parameter is ignored): forcing
//  a GC login modal over the Launch screen would be hostile, and SwiftUI
//  has no clean presentation seam at that moment. A player who wants Game
//  Center signs in once in system Settings → Game Center, and every
//  subsequent launch authenticates silently.
//
//  `alias` is used rather than `displayName` — GKLocalPlayer.displayName
//  can render as "Me" for the local player; alias is the actual nickname.
//

import Foundation
import GameKit

@MainActor
@Observable
final class GameCenterAuthProvider: AuthProviding {
    private let local: UsernameAuthProvider

    /// Non-nil once Game Center has authenticated this launch.
    private(set) var gameCenterAlias: String?
    /// Stable across the player's devices within this developer team —
    /// used by NeighborhoodPublisher as the cross-device publish identity
    /// so two synced devices update the same public records instead of
    /// double-counting.
    private(set) var teamPlayerID: String?

    var isGameCenterAuthenticated: Bool { gameCenterAlias != nil }

    var currentUsername: String? { gameCenterAlias ?? local.currentUsername }

    init(local: UsernameAuthProvider) {
        self.local = local
        // Set as close to launch as possible, per GameKit guidance. The
        // handler can fire multiple times (sign-in state changes while the
        // app is running) and on an arbitrary thread.
        GKLocalPlayer.local.authenticateHandler = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let player = GKLocalPlayer.local
                if player.isAuthenticated {
                    self.gameCenterAlias = player.alias
                    self.teamPlayerID = player.teamPlayerID
                } else {
                    self.gameCenterAlias = nil
                    self.teamPlayerID = nil
                }
            }
        }
    }

    // The local username flow is unchanged underneath — it both serves
    // non-GC users and keeps a fallback display name on record for GC
    // users (e.g. if they later sign out of Game Center).
    func signUp(username: String) throws { try local.signUp(username: username) }
    func updateUsername(_ username: String) throws { try local.updateUsername(username) }
    func signOut() { local.signOut() }
}
