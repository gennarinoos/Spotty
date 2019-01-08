//
//  SpectogramClassifier.swift
//  Spotty
//
//  Created by Gennaro on 12/10/18.
//  Copyright © 2018 Gennaro. All rights reserved.
//

import Vision
import UIKit

let DefaultOrientation = CGImagePropertyOrientation.up

class SpectogramClassifier {
    
    let visionQueue: DispatchQueue
    
    init() {
        self.visionQueue = DispatchQueue.global(qos: .userInitiated)
    }
    
    /*
    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let model = try VNCoreMLModel(for: MLModel())//MobileNet().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            //request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
//                self.classificationLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            
            if classifications.isEmpty {
//                self.classificationLabel.text = "Nothing recognized."
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification in
                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
                    return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
                }
//                self.classificationLabel.text = "Classification:\n" + descriptions.joined(separator: "\n")
            }
        }
    }
    
    func classify(pixelBuffer: CVPixelBuffer) {
        visionQueue.async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                orientation: DefaultOrientation)
            
            do {
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.currentBuffer = nil }
                try handler.perform([self.classificationRequest])
            } catch {
                print("Failed to perform video classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    func classify(image: CIImage) {
        visionQueue.async {
            let handler = VNImageRequestHandler(ciImage: image,
                                                orientation: DefaultOrientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform image classification.\n\(error.localizedDescription)")
            }
        }
    }
     */
}
