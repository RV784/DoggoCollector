//
//  AmbientBackgroundShapes.swift
//  DoggoCollector
//
//  A few sparse shapes that drift subtly in the background of the catch
//  celebration — persistent ambient motion, not a one-shot burst.
//

import SwiftUI

private struct AmbientShape: Identifiable {
    enum Kind { case roundedSquare, dot, diamond }

    let id = UUID()
    let kind: Kind
    let position: UnitPoint
    let color: Color
    let size: CGFloat
    let delay: Double
}

struct AmbientBackgroundShapes: View {
    @State private var drift = false

    private let shapes: [AmbientShape] = [
        AmbientShape(kind: .roundedSquare, position: UnitPoint(x: 0.16, y: 0.14), color: DoggoColor.sky, size: 22, delay: 0),
        AmbientShape(kind: .dot, position: UnitPoint(x: 0.86, y: 0.19), color: .white, size: 10, delay: 0.4),
        AmbientShape(kind: .dot, position: UnitPoint(x: 0.9, y: 0.28), color: DoggoColor.sky, size: 13, delay: 0.8),
        AmbientShape(kind: .diamond, position: UnitPoint(x: 0.13, y: 0.32), color: DoggoColor.ink.opacity(0.85), size: 15, delay: 0.2),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(shapes) { shape in
                shapeView(shape)
                    .position(x: geo.size.width * shape.position.x, y: geo.size.height * shape.position.y)
                    .offset(y: drift ? -10 : 10)
                    .animation(
                        .easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(shape.delay),
                        value: drift
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { drift = true }
    }

    @ViewBuilder
    private func shapeView(_ shape: AmbientShape) -> some View {
        switch shape.kind {
        case .roundedSquare:
            RoundedRectangle(cornerRadius: shape.size * 0.3)
                .fill(shape.color)
                .frame(width: shape.size, height: shape.size)
        case .dot:
            Circle()
                .fill(shape.color)
                .frame(width: shape.size, height: shape.size)
        case .diamond:
            RoundedRectangle(cornerRadius: shape.size * 0.2)
                .fill(shape.color)
                .frame(width: shape.size, height: shape.size)
                .rotationEffect(.degrees(45))
        }
    }
}

#Preview {
    AmbientBackgroundShapes()
        .frame(width: 300, height: 500)
        .background(DoggoColor.marigold)
}
