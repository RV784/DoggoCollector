//
//  WardsScreen.swift
//  DoggoCollector
//
//  The full "Guardian Wards" list, reached from the Home screen's
//  "Guardian Wards ›" section header (the Apple-Music-style see-all). Wraps
//  the existing WardsListView — active ward rows, the Today's Care link, and
//  the Past Wards link — in a real navigation-bar screen. This is where the
//  old segmented "Guardian Wards" tab's content lives now (decision: Home was
//  restructured into a wards carousel + All Catches grid).
//

import SwiftUI
import SwiftData

struct WardsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CaughtDog.caughtAt, order: .reverse) private var catches: [CaughtDog]

    var body: some View {
        ScrollView {
            WardsListView(catches: catches)
                .padding(DoggoSpacing.lg)
        }
        .background(DoggoColor.cream)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Guardian Wards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(DoggoColor.ink)
                }
            }
        }
    }
}
