import Foundation
import Vision
import AppKit

func performOCR(on imagePath: String) {
    let url = URL(fileURLWithPath: imagePath)
    guard let image = NSImage(contentsOf: url),
          let tiffData = image.tiffRepresentation,
          let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        print("Failed to load image: \(imagePath)")
        return
    }

    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNRecognizeTextRequest { (request, error) in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            return
        }
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            print(topCandidate.string)
        }
    }
    
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    
    do {
        try requestHandler.perform([request])
    } catch {
        print("Failed to perform OCR: \(error)")
    }
}

let arguments = CommandLine.arguments
if arguments.count < 2 {
    print("Usage: ocr <image_path>")
} else {
    performOCR(on: arguments[1])
}
