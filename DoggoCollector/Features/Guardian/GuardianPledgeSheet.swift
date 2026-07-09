//
//  GuardianPledgeSheet.swift
//  DoggoCollector
//
//  B1 — the pledge flow. Presented from Card Detail's pre-pledge banner.
//  The CTA mutates the dog directly (isWard/pledgedAt), auto-assigns the
//  nearest mocked clinic as a point-in-time snapshot, then hands control
//  back to the caller (which dismisses, toasts, and switches to Dossier).
//

import SwiftUI
import CoreLocation

struct GuardianPledgeSheet: View {
    @Bindable var dog: CaughtDog
    var onPledge: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: DoggoSpacing.xl) {
                ScoutMascot(expression: .happy, size: 120, wearsGuardianMedal: true)
                    .padding(.top, DoggoSpacing.lg)

                VStack(spacing: DoggoSpacing.sm) {
                    Text("Look out for \(dog.name)")
                        .font(DoggoTextStyle.displayMedium)
                        .foregroundStyle(DoggoColor.ink)
                        .multilineTextAlignment(.center)
                    Text("Guardians keep a little more than a card. Here's what you unlock:")
                        .font(DoggoTextStyle.bodyRegular)
                        .foregroundStyle(DoggoColor.inkMuted)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: DoggoSpacing.md) {
                    unlockRow(icon: "doc.text", tileColor: DoggoColor.chipCream, outlined: true, title: "A living dossier", sub: "vitals, clinic, care history")
                    unlockRow(icon: "plus", tileColor: DoggoColor.sage, title: "One-tap care logs", sub: "fed, vaccinated, checked")
                    unlockRow(icon: "printer.fill", tileColor: DoggoColor.sky, title: "A shelter pass", sub: "printable care record for vets")
                }

                PillButton(title: "I'll look out for them", action: pledge)

                Text(footerAttributedString)
                    .font(DoggoTextStyle.caption)
                    .multilineTextAlignment(.center)
            }
            .padding(DoggoSpacing.xl)
        }
        .background(DoggoColor.cream.ignoresSafeArea())
        .presentationDetents([.height(580)])
        .presentationDragIndicator(.visible)
    }

    /// "Want it official? {link, marigold+underlined} with the AWBI..." —
    /// only the middle phrase is the tappable link and colored differently,
    /// matching the design; the rest stays muted, per the real prototype
    /// screenshot (a single `Link`-wrapping `Text` colored it all the same).
    private var footerAttributedString: AttributedString {
        var lead = AttributedString("Want it official? ")
        lead.foregroundColor = DoggoColor.inkMuted

        var link = AttributedString("Here's how to register as a recognized caretaker")
        link.foregroundColor = DoggoColor.marigold
        link.underlineStyle = .single
        link.link = URL(string: "https://awbi.gov.in/")

        var tail = AttributedString(" with the AWBI Colony Caretaker programme.")
        tail.foregroundColor = DoggoColor.inkMuted

        return lead + link + tail
    }

    private func unlockRow(icon: String, tileColor: Color, outlined: Bool = false, title: String, sub: String) -> some View {
        HStack(alignment: .top, spacing: DoggoSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(outlined ? DoggoColor.marigold : DoggoColor.ink.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(outlined ? Color.clear : tileColor, in: RoundedRectangle(cornerRadius: DoggoRadius.control))
                .overlay {
                    if outlined {
                        RoundedRectangle(cornerRadius: DoggoRadius.control)
                            .stroke(DoggoColor.marigold.opacity(0.5), lineWidth: 1.5)
                    }
                }
            Text("**\(title)** \u{2014} \(sub)")
                .font(DoggoTextStyle.bodyRegular)
                .foregroundStyle(DoggoColor.ink)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pledge() {
        dog.isWard = true
        dog.pledgedAt = .now
        dismiss()
        onPledge()
        assignNearestClinic()
    }

    /// Fires after the pledge UX has already completed (dismiss + toast) so
    /// a slow/offline search never blocks the pledge itself. If it fails or
    /// finds nothing, clinic fields simply stay nil — GuardianDossierView
    /// already renders "None nearby yet" and hides the call row for that
    /// case, so no extra handling is needed here.
    private func assignNearestClinic() {
        let center = CLLocationCoordinate2D(latitude: dog.latitude, longitude: dog.longitude)
        guard center.latitude != 0 || center.longitude != 0 else { return }
        Task { @MainActor in
            guard let nearest = try? await LiveCareDirectory()
                .places(category: .vet, around: center, radiusKm: 10).first else { return }
            dog.assignedClinicName = nearest.name
            dog.assignedClinicPhone = nearest.phoneNumber
            dog.assignedClinicAddress = nearest.address
            dog.assignedClinicDistanceMeters = nearest.distanceMeters
            dog.assignedClinicLatitude = nearest.coordinate.latitude
            dog.assignedClinicLongitude = nearest.coordinate.longitude
        }
    }
}
