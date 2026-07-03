//
//  AppConfig.swift
//  DoggoCollector
//
//  Per-app configuration for the Collector family. Doggo is the first
//  instance; Cat/Flower will each ship their own AppConfig (different
//  subjectType/theme) while reusing everything in Core/ and DesignSystem/.
//

enum AppConfig {
    static let subjectType = "dog"
    static let tenantId = "doggo-collector"
    static let theme = "sunny-fetch"
}
