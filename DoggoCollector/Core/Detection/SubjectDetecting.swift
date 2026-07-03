//
//  SubjectDetecting.swift
//  DoggoCollector
//
//  What the camera is looking for is the one thing that changes per app in
//  the Collector family (Doggo → Cat → Flower). This protocol is the seam:
//  everything upstream (camera plumbing, catch flow, card generation) stays
//  identical across apps, and only the concrete detector swaps.
//

import CoreGraphics

protocol SubjectDetecting {
    /// Returns whether the app's collectible subject is present in the image.
    func detectSubject(in image: CGImage) async -> Bool
}
