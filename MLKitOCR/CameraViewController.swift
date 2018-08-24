//
//  CameraViewController.swift
//  MLKitOCR
//
//  Created by Brooks, Ioana on 8/1/18.
//  Copyright © 2018 Brooks, Ioana. All rights reserved.
//

import AVFoundation
import CoreVideo
import UIKit

import FirebaseMLVision

class CameraViewController: UIViewController {
    
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constants.sessionQueueLabel)
    private lazy var vision = Vision.vision()
    private lazy var onDeviceTextDetector = vision.textDetector()
    private var extractor = InfoExtractor()
    private var matched = false
    private var matchedGroupNumber = ""
    private var matchedMemberID = ""
    private var matchedCreditCard = ""
    private var message = ""
    private var lastTime = Date()
    private var cameraView: CameraView {
        return view as! CameraView
    }
    
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    
    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
       
        cameraView.captureSession = captureSession
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        cameraView.previewLayer.frame = cameraView.frame
    }
    
    private func retry(){
        matched = false
        matchedMemberID = ""
        matchedGroupNumber = ""
        matchedCreditCard = ""
        message = ""
    }
    
    private func showResults(message: String){
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        
        let OKAction = UIAlertAction(title: "Retry", style: .default, handler: { _ in self.retry() } )
        alertController.addAction(OKAction)
        present(alertController, animated: true, completion: nil)
        
    }
    
    private func detectTextOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        onDeviceTextDetector.detect(in: image) { features, error in
            guard error == nil, let features = features, !features.isEmpty else {
                self.removeDetectionAnnotations()
                print("On-Device text detector returned no results.")
                return
            }
            self.removeDetectionAnnotations()
            var allText = ""
            for feature in features {
                guard feature is VisionTextBlock, let block = feature as? VisionTextBlock else { continue }
                /*let points = self.convertedPoints(from: block.cornerPoints, width: width, height: height)
                UIUtilities.addShape(
                    withPoints: points,
                    to: self.annotationOverlayView,
                    color: UIColor.purple
                )*/
                allText += feature.text + "\n"
                for line in block.lines {
                    let points = self.convertedPoints(from: line.cornerPoints, width: width, height: height)
                    UIUtilities.addShape(
                        withPoints: points,
                        to: self.annotationOverlayView,
                        color: UIColor.white
                    )
                    let creditCardMatches = self.extractor.matches(for: self.extractor.creditCardRegex, in: line.text.replacingOccurrences(of: " ", with: "") as String)
                    
                    if !creditCardMatches.isEmpty{
                        self.matchedCreditCard = creditCardMatches.first!
                        self.matched = true
                        self.message += "Credit Card Number: " + self.matchedCreditCard
                        self.showResults(message: self.message)
                    }
                    
                    for element in line.elements {
                        
                        let normalizedRect = CGRect(
                            x: element.frame.origin.x / width,
                            y: element.frame.origin.y / height,
                            width: element.frame.size.width / width,
                            height: element.frame.size.height / height
                        )
                        let convertedRect = self.cameraView.previewLayer.layerRectConverted(
                            fromMetadataOutputRect: normalizedRect
                        )
                        /*UIUtilities.addRectangle(
                            convertedRect,
                            to: self.annotationOverlayView,
                            color: UIColor.white
                        )*/
                        let label = UILabel(frame: convertedRect)
                        label.text = element.text
                        label.adjustsFontSizeToFitWidth = true
                        self.annotationOverlayView.addSubview(label)
                        
                        let groupNumberMatches = self.extractor.matches(for: self.extractor.groupNumberRegex, in: element.text as String)
                        let memberIDMatches = self.extractor.matches(for: self.extractor.memberIdRegex, in: element.text as String)
                        
                        
                        
                        if !groupNumberMatches.isEmpty {
                            self.matchedGroupNumber = groupNumberMatches.first!
                        }
                        
                        if !memberIDMatches.isEmpty {
                            self.matchedMemberID = memberIDMatches.first!
                        }
                        
                        if !self.matchedGroupNumber.isEmpty && !self.matchedMemberID.isEmpty {
                            self.matched = true
                            self.message += "Member ID: " + self.matchedMemberID
                            self.message += "\nGroup number: " + self.matchedGroupNumber
                            print(allText)
                            self.showResults(message: self.message)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private
    private func setUpCaptureSessionOutput() {
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = AVCaptureSession.Preset.medium
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings =
                [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
            let outputQueue = DispatchQueue(label: Constants.videoDataOutputQueueLabel)
            output.setSampleBufferDelegate(self, queue: outputQueue)
            guard self.captureSession.canAddOutput(output) else {
                print("Failed to add capture session output.")
                return
            }
            self.captureSession.addOutput(output)
            self.cameraView.previewLayer.videoGravity = .resize
           
            self.captureSession.commitConfiguration()
            
        }
    }
    
    private func setUpCaptureSessionInput() {
        sessionQueue.async {
            let cameraPosition: AVCaptureDevice.Position = .back
            guard let device = self.captureDevice(forPosition: cameraPosition) else {
                print("Failed to get capture device for camera position: \(cameraPosition)")
                return
            }
            do {
                let currentInputs = self.captureSession.inputs
                for input in currentInputs {
                    self.captureSession.removeInput(input)
                }
                let input = try AVCaptureDeviceInput(device: device)
                guard self.captureSession.canAddInput(input) else {
                    print("Failed to add capture session input.")
                    return
                }
                let desiredMinFps = CMTime(value: 1, timescale: CMTimeScale(0.2))
                let desiredMaxFps = CMTime(value: 1, timescale: CMTimeScale(0.2))
                
                do {
                    try input.device.lockForConfiguration()
                    input.device.activeVideoMinFrameDuration = desiredMinFps
                    input.device.activeVideoMaxFrameDuration = desiredMaxFps
                } catch {
                    print("Error setting framerate")
                }
                self.captureSession.addInput(input)
            } catch {
                print("Failed to create capture device input: \(error.localizedDescription)")
            }
        }
    }
    
    private func startSession() {
        sessionQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    private func stopSession() {
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
    }
    
    private func setUpAnnotationOverlayView() {
        cameraView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
            ])
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first { $0.position == position }
    }
    
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    private func convertedPoints(
        from points: [NSValue],
        width: CGFloat,
        height: CGFloat
        ) -> [NSValue] {
        return points.map {
            let cgPointValue = $0.cgPointValue
            let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
            let cgPoint = cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
            let value = NSValue(cgPoint: cgPoint)
            return value
        }
    }
    
    private func normalizedPoint(
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
        ) -> CGPoint {
        let cgPoint = CGPoint(x: CGFloat(point.x.floatValue), y: CGFloat(point.y.floatValue))
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropping frame")
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
        ) {
        
        if Date().timeIntervalSince(lastTime) < Double(0.4) {
            // Limit fps to reduce CPU usage
            return
        }
        
        self.lastTime = Date()
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        if matched {
            return
        }
        
        let visionImage = VisionImage(buffer: sampleBuffer)
        let metadata = VisionImageMetadata()
        let orientation = UIUtilities.imageOrientation(
            fromDevicePosition: .back
        )
        let visionOrientation = UIUtilities.visionImageOrientation(from: orientation)
        metadata.orientation = visionOrientation
        visionImage.metadata = metadata
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        detectTextOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
    }
}


private enum Constants {
    static let videoDataOutputQueueLabel = "com.google.firebaseml.visiondetector.VideoDataOutputQueue"
    static let sessionQueueLabel = "com.google.firebaseml.visiondetector.SessionQueue"
}
