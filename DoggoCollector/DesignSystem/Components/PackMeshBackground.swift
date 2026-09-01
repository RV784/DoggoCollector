//
//  PackMeshBackground.swift
//  DoggoCollector
//
//  The app's warm vertical mesh-gradient background: a soft marigold tint at
//  the top settling to a near-white cream at the bottom. Shared so every
//  screen that adopts it stays identical (and so the mesh's color/point
//  counts stay correct in one place — MeshGradient requires exactly
//  width*height colors).
//

import SwiftUI

struct PackMeshBackground: View {
    var body: some View {
        MeshGradient(
            width: 2,
            height: 3,
            points: [
                [0.0, 0.0], [1.0, 0.0],
                [0.0, 0.5], [1.0, 0.5],
                [0.0, 1.0], [1.0, 1.0]
            ],
            colors: [
                DoggoColor.marigold.opacity(0.3), DoggoColor.marigold.opacity(0.3),
                DoggoColor.cream, DoggoColor.cream,
                DoggoColor.creamFade, DoggoColor.creamFade
            ]
        )
        .ignoresSafeArea()
    }
}
