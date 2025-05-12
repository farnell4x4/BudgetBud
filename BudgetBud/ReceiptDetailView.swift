//ReceiptDetailView.swift
//BudgetBud
//Update on 2025-04-05, 23:55
import SwiftUI
import CoreData

struct ReceiptDetailView: View {
    var receipt: Receipt
    @State private var searchText: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let data = receipt.imageData, let image = imageFromData(data) {
                    #if os(iOS)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    #elseif os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                    #endif
                }
                if let ocr = receipt.ocrText {
                    VStack(alignment: .leading) {
                        Text("OCR Text:")
                            .font(.headline)
                        highlightedText(fullText: ocr, searchText: searchText)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Receipt Detail")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                #if os(iOS)
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                #endif
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }
    
    func imageFromData(_ data: Data) -> MyPlatformImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #else
        return nil
        #endif
    }
    
    @ViewBuilder
    func highlightedText(fullText: String, searchText: String) -> some View {
        if searchText.isEmpty {
            Text(fullText)
        } else {
            // Basic implementation: simply show the full text.
            Text(fullText)
        }
    }
}



struct ReceiptDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy receipt for preview.
        let sampleData = UIImage(systemName: "doc.text")?.jpegData(compressionQuality: 1.0) ?? Data()
        let context = PersistenceController.preview.container.viewContext
        let receipt = Receipt(context: context)
        receipt.imageData = sampleData
        receipt.setValue("Sample OCR extracted text from a receipt.", forKey: "ocrText")
        return NavigationStack {
            ReceiptDetailView(receipt: receipt)
        }
    }
}
