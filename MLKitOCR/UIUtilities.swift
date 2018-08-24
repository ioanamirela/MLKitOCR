//
//  UIUtilities.swift
//  MLKitOCR
//
//  Created by Brooks, Ioana on 8/1/18.
//  Copyright © 2018 Brooks, Ioana. All rights reserved.
//
import AVFoundation
import UIKit
import FirebaseMLVision

class UIUtilities {

    public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
        let rectangleView = UIView(frame: rectangle)
        //rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
        //rectangleView.alpha = Constants.rectangleViewAlpha
        rectangleView.backgroundColor = color
        //rectangleView.layer.borderWidth = 1
        //rectangleView.layer.borderColor = UIColor.red.cgColor
        view.addSubview(rectangleView)
    }
    
    public static func addShape(withPoints points: [NSValue], to view: UIView, color: UIColor) {
        let path = UIBezierPath()
        for (index, value) in points.enumerated() {
            let point = value.cgPointValue
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
            if index == points.count - 1 {
                path.close()
            }
        }
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = color.cgColor
        let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        let shapeView = UIView(frame: rect)
        //shapeView.alpha = Constants.shapeViewAlpha
        shapeView.layer.addSublayer(shapeLayer)
        view.addSubview(shapeView)
    }
    
    public static func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
        ) -> UIImageOrientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp ||
            deviceOrientation == .unknown {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        }
    }
    
    public static func visionImageOrientation(
        from imageOrientation: UIImageOrientation
        ) -> VisionDetectorImageOrientation {
        switch imageOrientation {
        case .up:
            return .topLeft
        case .down:
            return .bottomRight
        case .left:
            return .leftBottom
        case .right:
            return .rightTop
        case .upMirrored:
            return .topRight
        case .downMirrored:
            return .bottomLeft
        case .leftMirrored:
            return .leftTop
        case .rightMirrored:
            return .rightBottom
        }
    }
    
    // MARK: - Private
    private static func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
    
    // MARK: - Constants
    private enum Constants {
        static let circleViewAlpha: CGFloat = 0.7
        static let rectangleViewAlpha: CGFloat = 0.7
        static let shapeViewAlpha: CGFloat = 0.3
        static let rectangleViewCornerRadius: CGFloat = 10.0
    }
}
