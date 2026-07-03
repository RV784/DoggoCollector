//
//  AuthProviding.swift
//  DoggoCollector
//
//  Phase 1 ships username-only local identity (`UsernameAuthProvider`), no
//  backend, no email/password. Phase 2 will add Sign in with Apple / Google
//  backed by Firebase. This protocol is the seam that makes phase 2 a new
//  conformance instead of a rewrite of every call site that reads
//  `currentUsername` — so nothing above this layer should assume a username
//  is the only identifier a user will ever have.
//

import Foundation

protocol AuthProviding {
    var currentUsername: String? { get }

    /// Establishes identity for a first-time user. Phase 1 just needs a
    /// display name; phase 2 conformances may perform real authentication
    /// here instead.
    func signUp(username: String) throws

    /// Renames the existing profile, as opposed to `signUp`, which creates one.
    func updateUsername(_ username: String) throws

    func signOut()
}
