//
//  CameraView.swift
//  MLKitOCR
//
//  Created by Brooks, Ioana on 8/1/18.
//  Copyright © 2018 Brooks, Ioana. All rights reserved.
//

import UIKit
import AVFoundation

class CameraView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    var captureSession: AVCaptureSession? {
        get {
            return previewLayer.session
        }
        set {
            previewLayer.session = newValue
        }
    }
    // MARK: UIView
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

}
