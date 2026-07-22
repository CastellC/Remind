import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Transferable wrapper for PhotosPicker image data.
struct PickedImageData: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            PickedImageData(data: data)
        }
    }
}
