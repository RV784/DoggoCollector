//
//  MosaicLayout.swift
//  DoggoCollector
//
//  The gallery's varied-tile grid, matching the Photos "People & Pets"
//  reference: mostly small square tiles with an occasional 2x2 hero tile, so
//  the grid reads as composed rather than as a uniform contact sheet.
//
//  A real `Layout` rather than a LazyVGrid because LazyVGrid can't express
//  a tile spanning multiple columns AND rows. The span pattern is a fixed
//  repeating cycle keyed off item index — deterministic on purpose: a random
//  or content-derived pattern would reshuffle as photos are added, and tiles
//  would visibly jump between renders.
//

import SwiftUI

struct MosaicLayout: Layout {
    var columns: Int = 3
    var spacing: CGFloat = 3

    /// Which slots in the repeating cycle get the 2x2 treatment. Cycle length
    /// 7 against 3 columns means the big tile lands on a different column
    /// each time around, which is what stops the grid looking striped.
    private static let bigSlots: Set<Int> = [0, 11]
    private static let cycle = 14

    private func isBig(_ index: Int) -> Bool {
        Self.bigSlots.contains(index % Self.cycle)
    }

    /// Packs indices into a column grid, tracking per-column fill height in
    /// *cells* so a 2x2 tile correctly blocks the two columns it straddles.
    private func frames(count: Int, width: CGFloat) -> (rects: [CGRect], height: CGFloat) {
        let totalSpacing = spacing * CGFloat(columns - 1)
        let cell = (width - totalSpacing) / CGFloat(columns)
        // occupancy[row][col]
        var occupied: [[Bool]] = []
        var rects: [CGRect] = []

        func ensureRows(_ upTo: Int) {
            while occupied.count <= upTo {
                occupied.append(Array(repeating: false, count: columns))
            }
        }

        func fits(row: Int, col: Int, span: Int) -> Bool {
            guard col + span <= columns else { return false }
            ensureRows(row + span - 1)
            for r in row..<(row + span) {
                for c in col..<(col + span) where occupied[r][c] { return false }
            }
            return true
        }

        for index in 0..<count {
            let span = isBig(index) ? 2 : 1
            var placed = false
            var row = 0
            while !placed {
                ensureRows(row)
                for col in 0..<columns where fits(row: row, col: col, span: span) {
                    for r in row..<(row + span) {
                        for c in col..<(col + span) { occupied[r][c] = true }
                    }
                    let side = cell * CGFloat(span) + spacing * CGFloat(span - 1)
                    rects.append(CGRect(
                        x: CGFloat(col) * (cell + spacing),
                        y: CGFloat(row) * (cell + spacing),
                        width: side,
                        height: side
                    ))
                    placed = true
                    break
                }
                if !placed { row += 1 }
            }
        }

        // Trailing empty rows shouldn't add height.
        let usedRows = occupied.lastIndex { $0.contains(true) }.map { $0 + 1 } ?? 0
        let height = usedRows == 0 ? 0 : CGFloat(usedRows) * cell + CGFloat(usedRows - 1) * spacing
        return (rects, height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0, !subviews.isEmpty else { return .zero }
        return CGSize(width: width, height: frames(count: subviews.count, width: width).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard bounds.width > 0 else { return }
        let layout = frames(count: subviews.count, width: bounds.width)
        for (index, subview) in subviews.enumerated() {
            guard index < layout.rects.count else { break }
            let rect = layout.rects[index]
            subview.place(
                at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
    }
}
