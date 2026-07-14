//
//  RecordPreviewController.swift
//  DoggoCollector
//
//  Views a medical record's attachments full-screen, paging through
//  multiple photos/PDFs. Deliberately NOT QLPreviewController: that control
//  ships a built-in share button with no supported API to remove it, and
//  these documents carry clinic letterheads and the owner's real name — the
//  most personal data in the app. A plain TabView(.page) + PDFKit pager
//  gives the same multi-attachment paging with zero share surface, exactly
//  the "acceptable fallback" the medication-tracking plan pre-approved
//  rather than fighting QuickLook's private view hierarchy for a
//  hide-the-button hack that can't be verified without a device.
//

import SwiftUI
import PDFKit

struct RecordPreviewController: View {
    let record: MedicalRecord

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(record.sortedAttachments) { attachment in
                    attachmentPage(attachment)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: record.sortedAttachments.count > 1 ? .always : .never))
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(record.recordType)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentPage(_ attachment: MedicalAttachment) -> some View {
        if attachment.isPDF {
            PDFKitView(data: attachment.data)
        } else if let uiImage = DogPhoto.image(from: attachment.data, size: .card) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: UIScreen.main.bounds.width)
            }
        } else {
            Text("Couldn't load this attachment")
                .foregroundStyle(.white)
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(data: data)
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
