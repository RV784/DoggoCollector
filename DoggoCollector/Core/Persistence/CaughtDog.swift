//
//  CaughtDog.swift
//  DoggoCollector
//

import Foundation
import SwiftData

@Model
final class CaughtDog {
    var id: UUID
    var name: String
    var breedLabel: String
    var traits: [String]
    @Attribute(.externalStorage) var imageData: Data?
    var caughtAt: Date
    var locationLabel: String
    var latitude: Double
    var longitude: Double
    var serialNumber: Int
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        breedLabel: String,
        traits: [String],
        imageData: Data?,
        caughtAt: Date = .now,
        locationLabel: String,
        latitude: Double,
        longitude: Double,
        serialNumber: Int,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.breedLabel = breedLabel
        self.traits = traits
        self.imageData = imageData
        self.caughtAt = caughtAt
        self.locationLabel = locationLabel
        self.latitude = latitude
        self.longitude = longitude
        self.serialNumber = serialNumber
        self.isFavorite = isFavorite
    }
}
