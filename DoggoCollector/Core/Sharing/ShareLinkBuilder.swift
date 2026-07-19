//
//  ShareLinkBuilder.swift
//  DoggoCollector
//
//  The full viral loop ("open this link and collect the dog into your own
//  account without having found it yourself") needs a backend that doesn't
//  exist in phase 1 — auth is local-only and there's no server-side account
//  system yet. This type builds the outgoing share caption only. The old
//  deepLinkURL ("doggocollector://catch/<uuid>") was deleted 2026-07-17:
//  the scheme was never registered or handled anywhere, so recipients got
//  a dead string. When the Phase 2 backend lands, reintroduce a real
//  (universal) link here — this type is still the one place to build it.
//

import Foundation

enum ShareLinkBuilder {
    static func caption(for dog: CaughtDog) -> String {
        "I caught \(dog.name) with DoggoCollector! \u{1F43E}"
    }
}
