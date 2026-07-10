//
//  SegmentedTabs.swift
//  DoggoCollector
//
//  A custom two-(or more-)way segmented control, replacing the native
//  `Picker` + `.pickerStyle(.segmented)` everywhere in the app. The native
//  control renders as a translucent "Liquid Glass" material on this iOS 27
//  toolchain with white-on-white text — unreadable against the app's cream
//  background. Matches the existing StatChip's marigold-selected/white-
//  unselected visual language instead, guaranteeing contrast regardless of
//  OS material rendering.
//

import SwiftUI

struct SegmentedTabs<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(DoggoTextStyle.bodySemibold)
                        .foregroundStyle(selection == option.value ? .white : DoggoColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DoggoSpacing.sm + 2)
                        .background(
                            selection == option.value ? DoggoColor.marigold : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
    }
}
