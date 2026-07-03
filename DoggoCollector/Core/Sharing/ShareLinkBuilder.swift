//
//  ShareLinkBuilder.swift
//  DoggoCollector
//
//  The full viral loop ("open this link and collect the dog into your own
//  account without having found it yourself") needs a backend that doesn't
//  exist in phase 1 — auth is local-only and there's no server-side account
//  system yet. This type only builds the outgoing share payload (caption +
//  deep link); wiring the deep link to a real hosted page is a phase 2
//  addition alongside Firebase, not a rewrite of this call site.
//

import Foundation

enum ShareLinkBuilder {
    static func caption(for dog: CaughtDog) -> String {
        "I caught \(dog.name) with DoggoCollector! \u{1F43E}"
    }

    static func deepLinkURL(for dog: CaughtDog) -> URL {
        URL(string: "doggocollector://catch/\(dog.id.uuidString)")!
    }
}
