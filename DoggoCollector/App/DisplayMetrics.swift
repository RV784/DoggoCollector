//
//  DisplayMetrics.swift
//  DoggoCollector
//
//  The device display's own corner radius, resolved ONCE at the window root
//  via Apple's concentric resolution (GeometryProxy.concentricCornerRadii).
//  It must be read at the window level: inside a NavigationStack the concentric
//  container is the stack, not the display, so it comes back nil there — which
//  is why reading it from CollectionView directly gave sharp/wrong corners.
//
//  Consumers (e.g. the camera panel) subtract their own inset from this to get
//  a device-concentric corner that keeps a uniform gap to the screen edge —
//  applied as a plain CONSTANT radius, so there's no ConcentricRectangle
//  deferred-resolution lag. See CLAUDE.md decision #32.
//

import SwiftUI

@Observable
final class DisplayMetrics {
    /// nil until resolved, or on a display with no rounded corner to read.
    var displayCornerRadius: CGFloat?
}
